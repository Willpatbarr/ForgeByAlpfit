import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../app/app_header.dart';
import '../../../../services/events_service.dart';
import '../../../../core/firebase/firestore_refs.dart';

enum EventType { basic, workout }

enum RecurrenceFrequency { none, weekly, monthly, everyOtherDay, customWeekly }
enum RecurrenceEndType { never, untilDate }

class EventCreatorPage extends StatefulWidget {
  const EventCreatorPage({super.key, this.eventId, this.embedded = false});

  /// When set, opens the form in edit mode with this event pre-loaded.
  final String? eventId;

  /// When true with eventId, renders only the form (for use in modal from calendar).
  final bool embedded;

  static const Color background = Color(0xFFF5F5F7);
  static const Color forgeBlue = Color(0xFF4D7CFF);

  @override
  State<EventCreatorPage> createState() => _EventCreatorPageState();
}

class _EventCreatorPageState extends State<EventCreatorPage> {
  // Form controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _exerciseNameController = TextEditingController();
  final TextEditingController _setsController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  // Form state
  EventType? _selectedEventType;
  bool _isPublic = true;
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  List<String> _selectedFriends = []; // display names
  List<String> _selectedFriendIds = [];
  List<Map<String, dynamic>> _exercises = [];
  bool _isCreating = false;

  // Recurrence
  RecurrenceFrequency _recurrenceFrequency = RecurrenceFrequency.none;
  RecurrenceEndType _recurrenceEndType = RecurrenceEndType.never;
  DateTime? _recurrenceEndDate;
  Set<int> _customWeekdays = {};

  // Location (gym) selection
  List<Map<String, String>> _joinedGyms = [];
  String? _selectedGymId;
  String? _selectedGymName;

  // Friends selection
  List<Map<String, String>> _friends = [];

  bool _isLoadingEventForEdit = false;
  bool _loadEventError = false;

  final List<Map<String, dynamic>> _premadeWorkouts = [
    {
      'name': 'Push Day',
      'exercises': ['Bench Press', 'Shoulder Press', 'Tricep Dips'],
    },
    {
      'name': 'Pull Day',
      'exercises': ['Deadlift', 'Rows', 'Bicep Curls'],
    },
    {
      'name': 'Leg Day',
      'exercises': ['Squats', 'Leg Press', 'Calf Raises'],
    },
    {
      'name': 'Full Body',
      'exercises': ['Squats', 'Bench Press', 'Rows'],
    },
  ];

  final List<Map<String, dynamic>> _userEvents = [
    {
      'title': 'Push Day pt 1',
      'date': 'Nov 11',
      'time': '9:00 AM - 10:30 AM',
      'type': 'workout',
    },
    {
      'title': 'Lunch',
      'date': 'Nov 11',
      'time': '11:00 AM - 12:00 PM',
      'type': 'basic',
    },
    {
      'title': 'Push Day',
      'date': 'Nov 11',
      'time': '12:00 PM - 1:30 PM',
      'type': 'workout',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadJoinedGyms();
    _loadFriends();
    if (widget.eventId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadEventForEdit());
    }
  }

  Future<void> _loadEventForEdit() async {
    final eventId = widget.eventId;
    if (eventId == null || !mounted) return;

    if (widget.embedded) setState(() => _isLoadingEventForEdit = true);

    final event = await getEvent(eventId);
    if (!mounted) return;
    if (event == null) {
      if (widget.embedded) {
        setState(() {
          _isLoadingEventForEdit = false;
          _loadEventError = true;
        });
      }
      return;
    }

    setState(() {
      _titleController.text = event['title'] as String? ?? '';
      _notesController.text = event['notes'] as String? ?? '';
      _selectedEventType =
          (event['eventType'] as String? ?? 'basic') == 'workout'
              ? EventType.workout
              : EventType.basic;
      _isPublic = event['isPublic'] as bool? ?? true;
      _selectedFriendIds = List<String>.from(event['inviteeIds'] as List? ?? []);
      _selectedFriends = List<String>.from(event['inviteeNames'] as List? ?? []);
      _selectedGymId = event['locationGymId'] as String?;
      _selectedGymName = event['locationGymName'] as String?;
      _exercises = (event['exercises'] as List? ?? [])
          .map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            final setDetails = m['setDetails'];
            if (setDetails is List) {
              m['setDetails'] = setDetails
                  .map((s) => Map<String, dynamic>.from(s as Map))
                  .toList();
            }
            return m;
          })
          .toList();

      final startAt = event['startAt'] as DateTime?;
      final endAt = event['endAt'] as DateTime?;
      if (startAt != null) {
        _startDate = startAt;
        _startTime = TimeOfDay(hour: startAt.hour, minute: startAt.minute);
      }
      if (endAt != null) {
        _endDate = endAt;
        _endTime = TimeOfDay(hour: endAt.hour, minute: endAt.minute);
      }
      final recurrence = event['recurrence'] as Map<String, dynamic>?;
      if (recurrence != null) {
        final freq = recurrence['frequency'] as String? ?? 'none';
        switch (freq) {
          case 'weekly':
            _recurrenceFrequency = RecurrenceFrequency.weekly;
            break;
          case 'monthly':
            _recurrenceFrequency = RecurrenceFrequency.monthly;
            break;
          case 'every_other_day':
            _recurrenceFrequency = RecurrenceFrequency.everyOtherDay;
            break;
          case 'custom_weekly':
            _recurrenceFrequency = RecurrenceFrequency.customWeekly;
            break;
          default:
            _recurrenceFrequency = RecurrenceFrequency.none;
        }
        final endType = recurrence['endType'] as String? ?? 'never';
        _recurrenceEndType = endType == 'until_date'
            ? RecurrenceEndType.untilDate
            : RecurrenceEndType.never;
        _recurrenceEndDate = recurrence['untilDate'] as DateTime?;
        final days = recurrence['daysOfWeek'] as List<dynamic>?;
        if (days != null) {
          _customWeekdays =
              days.map((e) => e as int).toSet();
        }
      } else {
        _recurrenceFrequency = RecurrenceFrequency.none;
        _recurrenceEndType = RecurrenceEndType.never;
        _recurrenceEndDate = null;
        _customWeekdays = {};
      }
      if (widget.embedded) _isLoadingEventForEdit = false;
    });
    if (mounted && !widget.embedded) _showEventForm();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _exerciseNameController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Widget _buildEmbeddedEditForm() {
    if (_loadEventError) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Container(
          decoration: const BoxDecoration(
            color: EventCreatorPage.background,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Could not load event'),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoadingEventForEdit || _startDate == null) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Container(
          decoration: const BoxDecoration(
            color: EventCreatorPage.background,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    return SizedBox(
      height: maxHeight,
      child: Container(
        decoration: const BoxDecoration(
          color: EventCreatorPage.background,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedEventType == EventType.workout
                        ? 'Edit Workout Event'
                        : 'Edit Basic Event',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTextField(
                          controller: _titleController,
                          label: 'Event Title',
                          icon: Icons.title,
                        ),
                        const SizedBox(height: 16),
                        _buildLocationField(setModalState),
                        const SizedBox(height: 16),
                        _buildInviteFriendsField(setModalState),
                        const SizedBox(height: 16),
                        _buildPrivacyToggle(),
                        const SizedBox(height: 16),
                        _buildDateTimeField(
                          label: 'Start Date & Time',
                          date: _startDate,
                          time: _startTime,
                          onDateTap: () => _selectDate(true, onUpdated: () => setModalState(() {})),
                          onTimeTap: () => _selectTime(true, onUpdated: () => setModalState(() {})),
                        ),
                        const SizedBox(height: 16),
                        _buildDateTimeField(
                          label: 'End Date & Time',
                          date: _endDate,
                          time: _endTime,
                          onDateTap: () => _selectDate(false, onUpdated: () => setModalState(() {})),
                          onTimeTap: () => _selectTime(false, onUpdated: () => setModalState(() {})),
                        ),
                        const SizedBox(height: 16),
                        _buildRecurrenceSection(onUpdated: () => setModalState(() {})),
                        const SizedBox(height: 16),
                        if (_selectedEventType == EventType.workout) ...[
                          _buildExercisesSection(onUpdated: () => setModalState(() {})),
                          const SizedBox(height: 16),
                        ],
                        _buildTextField(
                          controller: _notesController,
                          label: 'Notes',
                          icon: Icons.note,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _createEvent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EventCreatorPage.forgeBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Update Event',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded && widget.eventId != null) {
      return _buildEmbeddedEditForm();
    }

    return Scaffold(
      backgroundColor: EventCreatorPage.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            const AppHeader(),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    // Premade workouts section
                    _buildPremadeWorkoutsSection(),
                    const SizedBox(height: 24),
                    // User events section
                    _buildUserEventsSection(),
                    const SizedBox(height: 100), // Space for floating button
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Floating create button
      floatingActionButton: FloatingActionButton(
        onPressed: _showEventTypeDialog,
        backgroundColor: EventCreatorPage.forgeBlue,
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildPremadeWorkoutsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Text(
            'Premade Workouts',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _premadeWorkouts.length,
            itemBuilder: (context, index) {
              final workout = _premadeWorkouts[index];
              return _buildPremadeWorkoutCard(workout);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPremadeWorkoutCard(Map<String, dynamic> workout) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: EventCreatorPage.forgeBlue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Text(
              workout['name'] as String,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...(workout['exercises'] as List<String>).map((exercise) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: EventCreatorPage.forgeBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              exercise,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Text(
            'Your Events',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _userEvents.length,
            itemBuilder: (context, index) {
              final event = _userEvents[index];
              return _buildUserEventCard(event);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserEventCard(Map<String, dynamic> event) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (event['type'] as String) == 'workout'
                  ? Colors.orange
                  : EventCreatorPage.forgeBlue,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Text(
              event['title'] as String,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        event['date'] as String,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event['time'] as String,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _showEventTypeDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Create Event',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEventTypeOption(
              dialogContext,
              'Basic Event',
              'Create a simple event with friends',
              Icons.event,
              EventType.basic,
            ),
            const SizedBox(height: 16),
            _buildEventTypeOption(
              dialogContext,
              'Workout Event',
              'Create a workout with exercises',
              Icons.fitness_center,
              EventType.workout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTypeOption(
    BuildContext dialogContext,
    String title,
    String subtitle,
    IconData icon,
    EventType type,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(dialogContext).pop();
        _selectedEventType = type;
        // Delay until dialog is fully closed to avoid overlay stack issues
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showEventForm();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: EventCreatorPage.forgeBlue.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EventCreatorPage.forgeBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: EventCreatorPage.forgeBlue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventForm() {
    // Set sensible default times when opening the form
    final now = DateTime.now();
    final endDefault = now.add(const Duration(hours: 1));
    setState(() {
      _startDate ??= now;
      _startTime ??= TimeOfDay.fromDateTime(now);
      _endDate ??= endDefault;
      _endTime ??= TimeOfDay.fromDateTime(endDefault);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
        final maxHeight = MediaQuery.of(context).size.height * 0.9;
        return SizedBox(
          height: maxHeight,
          child: Container(
            decoration: const BoxDecoration(
              color: EventCreatorPage.background,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.eventId != null
                          ? (_selectedEventType == EventType.workout
                              ? 'Edit Workout Event'
                              : 'Edit Basic Event')
                          : (_selectedEventType == EventType.workout
                              ? 'Create Workout Event'
                              : 'Create Basic Event'),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              // Form content (StatefulBuilder so date/time changes rebuild the sheet)
              Expanded(
                child: StatefulBuilder(
                  builder: (context, setModalState) {
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Title field
                          _buildTextField(
                            controller: _titleController,
                            label: 'Event Title',
                            icon: Icons.title,
                          ),
                          const SizedBox(height: 16),

                          // Location field
                          _buildLocationField(setModalState),
                          const SizedBox(height: 16),

                          // Invite friends
                          _buildInviteFriendsField(setModalState),
                          const SizedBox(height: 16),

                          // Public/Private toggle
                          _buildPrivacyToggle(),
                          const SizedBox(height: 16),

                          // Start date/time
                          _buildDateTimeField(
                            label: 'Start Date & Time',
                            date: _startDate,
                            time: _startTime,
                            onDateTap: () => _selectDate(true, onUpdated: () => setModalState(() {})),
                            onTimeTap: () => _selectTime(true, onUpdated: () => setModalState(() {})),
                          ),
                          const SizedBox(height: 16),

                          // End date/time
                          _buildDateTimeField(
                            label: 'End Date & Time',
                            date: _endDate,
                            time: _endTime,
                            onDateTap: () => _selectDate(false, onUpdated: () => setModalState(() {})),
                            onTimeTap: () => _selectTime(false, onUpdated: () => setModalState(() {})),
                          ),
                      const SizedBox(height: 16),

                      _buildRecurrenceSection(onUpdated: () => setModalState(() {})),

                      const SizedBox(height: 16),

                      // Exercises section (only for workout events)
                      if (_selectedEventType == EventType.workout) ...[
                        _buildExercisesSection(onUpdated: () => setModalState(() {})),
                        const SizedBox(height: 16),
                      ],

                      // Notes field
                      _buildTextField(
                        controller: _notesController,
                        label: 'Notes',
                        icon: Icons.note,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 24),

                          // Create / Update button
                          ElevatedButton(
                            onPressed: _createEvent,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EventCreatorPage.forgeBlue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              widget.eventId != null ? 'Update Event' : 'Create Event',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.black54),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: EventCreatorPage.forgeBlue,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildRecurrenceSection({VoidCallback? onUpdated}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.repeat, size: 20, color: Colors.black54),
            SizedBox(width: 8),
            Text(
              'Repeat',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<RecurrenceFrequency>(
          value: _recurrenceFrequency,
          items: const [
            DropdownMenuItem(
              value: RecurrenceFrequency.none,
              child: Text('Does not repeat'),
            ),
            DropdownMenuItem(
              value: RecurrenceFrequency.weekly,
              child: Text('Weekly'),
            ),
            DropdownMenuItem(
              value: RecurrenceFrequency.monthly,
              child: Text('Monthly'),
            ),
            DropdownMenuItem(
              value: RecurrenceFrequency.everyOtherDay,
              child: Text('Every other day'),
            ),
            DropdownMenuItem(
              value: RecurrenceFrequency.customWeekly,
              child: Text('Custom (days of week)'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _recurrenceFrequency = value;
              if (value == RecurrenceFrequency.none) {
                _recurrenceEndType = RecurrenceEndType.never;
                _recurrenceEndDate = null;
                _customWeekdays = {};
              } else if (value != RecurrenceFrequency.customWeekly) {
                _customWeekdays = {};
              } else {
                if (_customWeekdays.isEmpty && _startDate != null) {
                  _customWeekdays = {_startDate!.weekday};
                }
              }
            });
            onUpdated?.call();
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: EventCreatorPage.forgeBlue.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: EventCreatorPage.forgeBlue.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(
                color: EventCreatorPage.forgeBlue,
                width: 2,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        if (_recurrenceFrequency != RecurrenceFrequency.none) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: RadioListTile<RecurrenceEndType>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: RecurrenceEndType.never,
                  groupValue: _recurrenceEndType,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _recurrenceEndType = value;
                      _recurrenceEndDate = null;
                    });
                    onUpdated?.call();
                  },
                  title: const Text(
                    'Repeat forever',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: RadioListTile<RecurrenceEndType>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: RecurrenceEndType.untilDate,
                  groupValue: _recurrenceEndType,
                  onChanged: (value) async {
                    if (value == null) return;
                    DateTime? picked = _recurrenceEndDate;
                    if (picked == null) {
                      picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? _startDate ?? DateTime.now(),
                        firstDate: _startDate ?? DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                    }
                    if (!mounted) return;
                    setState(() {
                      _recurrenceEndType = RecurrenceEndType.untilDate;
                      _recurrenceEndDate = picked;
                    });
                    onUpdated?.call();
                  },
                  title: Text(
                    _recurrenceEndDate != null
                        ? 'Until ${_recurrenceEndDate!.month}/${_recurrenceEndDate!.day}/${_recurrenceEndDate!.year}'
                        : 'Until date',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_recurrenceFrequency == RecurrenceFrequency.customWeekly) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(7, (index) {
                final weekday = index + 1; // 1 = Monday
                const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                final selected = _customWeekdays.contains(weekday);
                return ChoiceChip(
                  label: Text(
                    labels[index],
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                    ),
                  ),
                  selected: selected,
                  onSelected: (isSelected) {
                    setState(() {
                      if (isSelected) {
                        _customWeekdays.add(weekday);
                      } else {
                        _customWeekdays.remove(weekday);
                      }
                    });
                    onUpdated?.call();
                  },
                  selectedColor: EventCreatorPage.forgeBlue,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                  ),
                );
              }),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildInviteFriendsField(void Function(void Function()) setModalState) {
    final hasFriends = _friends.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.group, size: 20, color: Colors.black54),
            SizedBox(width: 8),
            Text(
              'Invite Friends',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: null,
          items: _friends
              .map(
                (friend) => DropdownMenuItem<String>(
                  value: friend['uid'],
                  child: Text(
                    friend['name'] ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: hasFriends
              ? (value) {
                  if (value == null) return;
                  final idx = _selectedFriendIds.indexOf(value);
                  setState(() {
                    if (idx >= 0) {
                      _selectedFriendIds.removeAt(idx);
                      _selectedFriends.removeAt(idx);
                    } else {
                      final friend = _friends.firstWhere(
                        (f) => f['uid'] == value,
                        orElse: () => {'uid': value, 'name': 'Unknown'},
                      );
                      _selectedFriendIds.add(friend['uid'] ?? value);
                      _selectedFriends.add(friend['name'] ?? 'Unknown');
                    }
                  });
                  setModalState(() {});
                }
              : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: hasFriends
                ? 'Select friends to invite'
                : 'No friends to invite yet',
            hintStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              color: Colors.black54,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: EventCreatorPage.forgeBlue.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: EventCreatorPage.forgeBlue.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(
                color: EventCreatorPage.forgeBlue,
                width: 2,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 8),
        if (_selectedFriends.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _selectedFriends
                .asMap()
                .entries
                .map(
                  (entry) => Chip(
                    label: Text(
                      entry.value,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                      ),
                    ),
                    onDeleted: () {
                      setState(() {
                        _selectedFriends.removeAt(entry.key);
                        _selectedFriendIds.removeAt(entry.key);
                      });
                      setModalState(() {});
                    },
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildPrivacyToggle() {
    return Row(
      children: [
        const Icon(Icons.lock_outline, size: 20, color: Colors.black54),
        const SizedBox(width: 8),
        const Text(
          'Privacy',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const Spacer(),
        Switch(
          value: _isPublic,
          onChanged: (value) {
            setState(() {
              _isPublic = value;
            });
          },
          activeColor: EventCreatorPage.forgeBlue,
        ),
        Text(
          _isPublic ? 'Public' : 'Private',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeField({
    required String label,
    required DateTime? date,
    required TimeOfDay? time,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 20, color: Colors.black54),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onDateTap,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: EventCreatorPage.forgeBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    date != null
                        ? '${date.month}/${date.day}/${date.year}'
                        : 'Select date',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      color: date != null ? Colors.black87 : Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: onTimeTap,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: EventCreatorPage.forgeBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    time != null
                        ? '${time.hourOfPeriod}:${time.minute.toString().padLeft(2, '0')} ${time.period.name.toUpperCase()}'
                        : 'Select time',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      color: time != null ? Colors.black87 : Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExercisesSection({VoidCallback? onUpdated}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.fitness_center, size: 20, color: Colors.black54),
            const SizedBox(width: 8),
            const Text(
              'Exercises',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Exercise list
        ..._exercises.asMap().entries.map((entry) {
          final index = entry.key;
          final exercise = entry.value;
          return _buildExerciseCard(exercise, index, onUpdated: onUpdated);
        }),
        const SizedBox(height: 8),
        // Add exercise button
        ElevatedButton.icon(
          onPressed: () => _showAddExerciseDialog(onUpdated: onUpdated),
          icon: const Icon(Icons.add),
          label: const Text('Add Exercise'),
          style: ElevatedButton.styleFrom(
            backgroundColor: EventCreatorPage.forgeBlue.withValues(alpha: 0.1),
            foregroundColor: EventCreatorPage.forgeBlue,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> exercise, int index, {VoidCallback? onUpdated}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: EventCreatorPage.forgeBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                exercise['name'] as String,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _exercises.removeAt(index);
                  });
                  onUpdated?.call();
                },
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${exercise['sets']} sets',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          ...(exercise['setDetails'] as List<Map<String, dynamic>>)
              .asMap()
              .entries
              .map((setEntry) {
            final setIndex = setEntry.key;
            final set = setEntry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Set ${setIndex + 1}: ${set['reps']} reps × ${set['weight']}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _showAddExerciseDialog({VoidCallback? onUpdated}) {
    FocusScope.of(context).unfocus();
    _exerciseNameController.clear();
    _setsController.clear();
    _repsController.clear();
    _weightController.clear();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Add Exercise',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _exerciseNameController,
                decoration: const InputDecoration(
                  labelText: 'Exercise Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _setsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of Sets',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Set Details',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              // For now, we'll create sets with the same reps/weight
              // In a full implementation, you'd want individual set inputs
              TextField(
                controller: _repsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Reps (for all sets)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Weight (for all sets)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _exerciseNameController.text.trim();
              if (name.isEmpty) return;
              final sets = int.tryParse(_setsController.text) ?? 0;
              final reps = _repsController.text;
              final weight = _weightController.text;
              final setDetails = List.generate(sets, (_) => {
                'reps': reps,
                'weight': weight,
              });
              setState(() {
                _exercises.add({
                  'name': name,
                  'sets': sets,
                  'setDetails': setDetails,
                });
              });
              Navigator.of(dialogContext).pop();
              onUpdated?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EventCreatorPage.forgeBlue,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField(void Function(void Function()) setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.location_on, size: 20, color: Colors.black54),
            SizedBox(width: 8),
            Text(
              'Location',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedGymId,
          items: _joinedGyms
              .map(
                (gym) => DropdownMenuItem<String>(
                  value: gym['uid'],
                  child: Text(
                    gym['name'] ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: _joinedGyms.isEmpty
              ? null
              : (value) {
                  if (value == null) return;
                  final gym = _joinedGyms.firstWhere(
                    (g) => g['uid'] == value,
                    orElse: () => {'uid': value, 'name': 'Unknown Gym'},
                  );
                  setState(() {
                    _selectedGymId = value;
                    _selectedGymName = gym['name'];
                  });
                  setModalState(() {});
                },
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: _joinedGyms.isEmpty
                ? 'No gyms joined yet'
                : 'Select gym (optional)',
            hintStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              color: Colors.black54,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: EventCreatorPage.forgeBlue.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: EventCreatorPage.forgeBlue.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(
                color: EventCreatorPage.forgeBlue,
                width: 2,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Future<void> _loadJoinedGyms() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirestoreRefs.userDoc(uid).get();
      final joinedGymIds = doc.data()?['joinedGymIds'] as List<dynamic>?;
      if (joinedGymIds == null || joinedGymIds.isEmpty) {
        setState(() {
          _joinedGyms = [];
        });
        return;
      }

      final gyms = <Map<String, String>>[];
      for (final id in joinedGymIds) {
        final gymUid = id is String ? id : id.toString();
        if (gymUid.isEmpty) continue;
        try {
          final gymDoc = await FirestoreRefs.userDoc(gymUid).get();
          final data = gymDoc.data();
          if (gymDoc.exists && data != null) {
            gyms.add({
              'uid': gymUid,
              'name': (data['displayName'] as String?) ?? 'Unknown Gym',
            });
          }
        } catch (_) {
          // Ignore individual gym load failures
        }
      }

      setState(() {
        _joinedGyms = gyms;
      });
    } catch (_) {
      // Ignore load failures; leave list empty
    }
  }

  Future<void> _loadFriends() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirestoreRefs.userDoc(uid).get();
      final friendIds = doc.data()?['friendIds'] as List<dynamic>?;
      if (friendIds == null || friendIds.isEmpty) {
        setState(() {
          _friends = [];
        });
        return;
      }

      final list = <Map<String, String>>[];
      for (final id in friendIds) {
        final friendUid = id is String ? id : id.toString();
        if (friendUid.isEmpty) continue;
        try {
          final friendDoc = await FirestoreRefs.userDoc(friendUid).get();
          final data = friendDoc.data();
          if (friendDoc.exists && data != null) {
            list.add({
              'uid': friendUid,
              'name': (data['displayName'] as String?) ?? 'Unknown',
            });
          }
        } catch (_) {
          // Ignore individual failures
        }
      }

      setState(() {
        _friends = list;
      });
    } catch (_) {
      // Ignore load failures
    }
  }

  Future<void> _selectDate(bool isStart, {VoidCallback? onUpdated}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      onUpdated?.call();
    }
  }

  Future<void> _selectTime(bool isStart, {VoidCallback? onUpdated}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ?? _startTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
      onUpdated?.call();
    }
  }

  DateTime? _combineDateAndTime(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _createEvent() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Event title is required')),
      );
      setState(() => _isCreating = false);
      return;
    }

    final eventType = _selectedEventType == EventType.workout ? 'workout' : 'basic';
    final startAt = _combineDateAndTime(_startDate, _startTime);
    final endAt = _combineDateAndTime(_endDate, _endTime);

    Map<String, dynamic>? recurrence;
    if (_recurrenceFrequency != RecurrenceFrequency.none) {
      String frequency;
      switch (_recurrenceFrequency) {
        case RecurrenceFrequency.weekly:
          frequency = 'weekly';
          break;
        case RecurrenceFrequency.monthly:
          frequency = 'monthly';
          break;
        case RecurrenceFrequency.everyOtherDay:
          frequency = 'every_other_day';
          break;
        case RecurrenceFrequency.customWeekly:
          frequency = 'custom_weekly';
          break;
        case RecurrenceFrequency.none:
          frequency = 'none';
      }
      final daysOfWeek =
          _recurrenceFrequency == RecurrenceFrequency.customWeekly
              ? (List<int>.from(_customWeekdays)..sort())
              : null;
      recurrence = {
        'frequency': frequency,
        'endType':
            _recurrenceEndType == RecurrenceEndType.untilDate ? 'until_date' : 'never',
        'untilDate':
            _recurrenceEndType == RecurrenceEndType.untilDate ? _recurrenceEndDate : null,
        'daysOfWeek': daysOfWeek,
      };
    }

    try {
      final eventId = widget.eventId;
      if (eventId != null) {
        await updateEvent(
          eventId: eventId,
          title: title,
          notes: _notesController.text,
          eventType: eventType,
          isPublic: _isPublic,
          inviteeIds: List.from(_selectedFriendIds),
          inviteeNames: List.from(_selectedFriends),
          startAt: startAt,
          endAt: endAt,
          exercises: List.from(_exercises),
          locationGymId: _selectedGymId,
          locationGymName: _selectedGymName,
          recurrence: recurrence,
        );
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Event updated successfully!')),
        );
        navigator.pop(context);
        return;
      } else {
        await createEvent(
          title: title,
          notes: _notesController.text,
          eventType: eventType,
          isPublic: _isPublic,
          inviteeIds: List.from(_selectedFriendIds),
          inviteeNames: List.from(_selectedFriends),
          startAt: startAt,
          endAt: endAt,
          exercises: List.from(_exercises),
          locationGymId: _selectedGymId,
          locationGymName: _selectedGymName,
          recurrence: recurrence,
        );
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Event created successfully!')),
        );
      }
      navigator.pop(context);
      // Reset form
      _titleController.clear();
      _notesController.clear();
      _selectedFriends.clear();
      _selectedFriendIds.clear();
      _exercises.clear();
      _startDate = null;
      _startTime = null;
      _endDate = null;
      _endTime = null;
      _isPublic = true;
      _recurrenceFrequency = RecurrenceFrequency.none;
      _recurrenceEndType = RecurrenceEndType.never;
      _recurrenceEndDate = null;
      _customWeekdays = {};
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to create event: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }
}
