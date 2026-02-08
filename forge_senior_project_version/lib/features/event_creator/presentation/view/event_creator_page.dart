import 'package:flutter/material.dart';

enum EventType { basic, workout }

class EventCreatorPage extends StatefulWidget {
  const EventCreatorPage({super.key});

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
  List<String> _selectedFriends = [];
  List<Map<String, dynamic>> _exercises = [];

  // Dummy data
  final List<String> _availableFriends = [
    'Alex Smith',
    'Jordan Taylor',
    'Sam Johnson',
    'Riley Brown',
    'Taylor Davis',
  ];

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
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _exerciseNameController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EventCreatorPage.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

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

  Widget _buildHeader() {
    return Container(
      color: EventCreatorPage.forgeBlue,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Forge flame icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'FORGE',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 4,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: Colors.grey,
            ),
          ),
        ],
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
      builder: (context) => AlertDialog(
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
              'Basic Event',
              'Create a simple event with friends',
              Icons.event,
              EventType.basic,
            ),
            const SizedBox(height: 16),
            _buildEventTypeOption(
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
    String title,
    String subtitle,
    IconData icon,
    EventType type,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _selectedEventType = type;
        _showEventForm();
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
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
                      _selectedEventType == EventType.workout
                          ? 'Create Workout Event'
                          : 'Create Basic Event',
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
              // Form content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
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

                      // Invite friends button
                      _buildInviteFriendsButton(),
                      const SizedBox(height: 16),

                      // Public/Private toggle
                      _buildPrivacyToggle(),
                      const SizedBox(height: 16),

                      // Start date/time
                      _buildDateTimeField(
                        label: 'Start Date & Time',
                        date: _startDate,
                        time: _startTime,
                        onDateTap: () => _selectDate(true),
                        onTimeTap: () => _selectTime(true),
                      ),
                      const SizedBox(height: 16),

                      // End date/time
                      _buildDateTimeField(
                        label: 'End Date & Time',
                        date: _endDate,
                        time: _endTime,
                        onDateTap: () => _selectDate(false),
                        onTimeTap: () => _selectTime(false),
                      ),
                      const SizedBox(height: 16),

                      // Exercises section (only for workout events)
                      if (_selectedEventType == EventType.workout) ...[
                        _buildExercisesSection(),
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

                      // Create button
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
                          'Create Event',
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
                ),
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildInviteFriendsButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.group, size: 20, color: Colors.black54),
            const SizedBox(width: 8),
            const Text(
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
        GestureDetector(
          onTap: _showFriendsSelectionDialog,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: EventCreatorPage.forgeBlue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedFriends.isEmpty
                      ? 'Select friends to invite'
                      : '${_selectedFriends.length} friend${_selectedFriends.length == 1 ? '' : 's'} selected',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: _selectedFriends.isEmpty
                        ? Colors.black54
                        : Colors.black87,
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black54),
              ],
            ),
          ),
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

  Widget _buildExercisesSection() {
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
          return _buildExerciseCard(exercise, index);
        }).toList(),
        const SizedBox(height: 8),
        // Add exercise button
        ElevatedButton.icon(
          onPressed: _showAddExerciseDialog,
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

  Widget _buildExerciseCard(Map<String, dynamic> exercise, int index) {
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

  void _showFriendsSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Select Friends',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return ListView.builder(
                shrinkWrap: true,
                itemCount: _availableFriends.length,
                itemBuilder: (context, index) {
                  final friend = _availableFriends[index];
                  final isSelected = _selectedFriends.contains(friend);
                  return CheckboxListTile(
                    title: Text(
                      friend,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                      ),
                    ),
                    value: isSelected,
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          _selectedFriends.add(friend);
                        } else {
                          _selectedFriends.remove(friend);
                        }
                      });
                    },
                    activeColor: EventCreatorPage.forgeBlue,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Done',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: EventCreatorPage.forgeBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddExerciseDialog() {
    _exerciseNameController.clear();
    _setsController.clear();
    _repsController.clear();
    _weightController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final sets = int.tryParse(_setsController.text) ?? 0;
              final reps = _repsController.text;
              final weight = _weightController.text;
              final setDetails = List.generate(sets, (index) {
                return {
                  'reps': reps,
                  'weight': weight,
                };
              });
              setState(() {
                _exercises.add({
                  'name': _exerciseNameController.text,
                  'sets': sets,
                  'setDetails': setDetails,
                });
              });
              Navigator.pop(context);
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

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _createEvent() {
    // TODO: Implement event creation logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Event created successfully!'),
      ),
    );
    Navigator.pop(context);
    // Reset form
    _titleController.clear();
    _notesController.clear();
    _selectedFriends.clear();
    _exercises.clear();
    _startDate = null;
    _startTime = null;
    _endDate = null;
    _endTime = null;
    _isPublic = true;
  }
}
