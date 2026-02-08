import 'package:flutter/material.dart';

enum CalendarView { day, multi, month }

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  static const Color background = Color(0xFFF5F5F7);
  static const Color forgeBlue = Color(0xFF4D7CFF);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarView _currentView = CalendarView.day;
  bool _showFilterPopup = false;
  Map<String, dynamic>? _selectedEvent;
  DateTime _currentDate = DateTime(2025, 11, 11); // Tuesday, Nov 11th, 2025
  DateTime _monthViewDate = DateTime(2025, 11, 1); // November 2025

  // Filter states
  final Map<String, bool> _filterStates = {
    'You': true,
    'Friend 1': true,
    'Ethan': true,
    'Gym 1': true,
  };

  final Map<String, Color> _filterColors = {
    'You': Colors.orange,
    'Friend 1': Colors.yellow,
    'Ethan': Colors.blue,
    'Gym 1': Colors.green,
  };

  // Dummy events data
  static final List<Map<String, dynamic>> _dummyEvents = [
    {
      'id': '1',
      'title': 'Push Day pt 1',
      'start': DateTime(2025, 11, 11, 9, 0),
      'end': DateTime(2025, 11, 11, 10, 30),
      'color': Colors.orange,
      'owner': 'You',
      'hasInvite': true,
      'location': 'BYU-I Fitness Center',
      'attendees': ['John Whatsit', 'Derek Whatsit'],
      'exercises': [
        {'name': 'Flat Barbell Bench Press', 'sets': '4 X 8', 'weight': '75 lbs'}
      ],
      'notes': '',
      'privacy': 'Friends Only',
    },
    {
      'id': '2',
      'title': 'Lunch',
      'start': DateTime(2025, 11, 11, 11, 0),
      'end': DateTime(2025, 11, 11, 12, 0),
      'color': Colors.yellow,
      'owner': 'You',
      'hasInvite': false,
    },
    {
      'id': '3',
      'title': 'Push Day',
      'start': DateTime(2025, 11, 11, 12, 0),
      'end': DateTime(2025, 11, 11, 13, 30),
      'color': Colors.blue,
      'owner': 'Ethan Whatsit',
      'hasAttend': true,
      'location': 'BYU-I Fitness Center',
      'attendees': ['John Whatsit', 'Derek Whatsit'],
      'exercises': [
        {'name': 'Flat Barbell Bench Press', 'sets': '4 X 8', 'weight': '75 lbs'}
      ],
      'notes': '',
      'privacy': 'Friends Only',
    },
    {
      'id': '4',
      'title': 'Push Day pt 2',
      'start': DateTime(2025, 11, 11, 14, 0),
      'end': DateTime(2025, 11, 11, 15, 30),
      'color': Colors.orange,
      'owner': 'You',
      'hasInvite': true,
    },
  ];

  // Recurring events for multi-day view
  List<Map<String, dynamic>> _getRecurringEvents() {
    return [
      {
        'title': 'Push Day pt 1',
        'time': '9:00 AM - 10:30 AM',
        'color': Colors.orange,
        'owner': 'You',
      },
      {
        'title': 'Push Day',
        'time': '12:00 PM - 1:30 PM',
        'color': Colors.blue,
        'owner': 'Ethan',
      },
      {
        'title': 'Push Day pt 2',
        'time': '2:00 PM - 3:30 PM',
        'color': Colors.orange,
        'owner': 'You',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalendarPage.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                _buildHeader(),

                // Main content
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
            ),

            // Filter popup overlay
            if (_showFilterPopup) _buildFilterPopup(),

            // Event detail overlay
            if (_selectedEvent != null) _buildEventDetailOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: CalendarPage.forgeBlue,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              // Three dots menu
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showFilterPopup = !_showFilterPopup;
                  });
                },
                child: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 12),
          // View tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildViewTab('Day', CalendarView.day),
              const SizedBox(width: 16),
              _buildViewTab('Multi', CalendarView.multi),
              const SizedBox(width: 16),
              _buildViewTab('Month', CalendarView.month),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewTab(String label, CalendarView view) {
    final isSelected = _currentView == view;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentView = view;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected ? CalendarPage.forgeBlue : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_currentView) {
      case CalendarView.day:
        return _buildDayView();
      case CalendarView.multi:
        return _buildMultiView();
      case CalendarView.month:
        return _buildMonthView();
    }
  }

  Widget _buildDayView() {
    final dateStr = _formatDate(_currentDate);
    final eventsForDay = _getEventsForDate(_currentDate);

    return Column(
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            dateStr,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),

        // Timeline
        Expanded(
          child: _buildDayTimeline(eventsForDay),
        ),

        // Reminders section
        _buildRemindersSection(),
      ],
    );
  }

  Widget _buildDayTimeline(List<Map<String, dynamic>> events) {
    final hours = _generateHours();
    final hourHeight = 80.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Stack(
          children: [
            // Time markers
            Column(
              children: hours.map((hour) {
                return Container(
                  height: hourHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          hour,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            // Events
            ...events.map((event) {
              final start = event['start'] as DateTime;
              final end = event['end'] as DateTime;
              final startHour = start.hour + start.minute / 60.0;
              final endHour = end.hour + end.minute / 60.0;
              final top = (startHour - 4) * hourHeight;
              final height = (endHour - startHour) * hourHeight;

              return Positioned(
                left: 100,
                right: 16,
                top: top,
                height: height,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedEvent = event;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: event['color'] as Color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          event['title'] as String,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (event['hasInvite'] == true || event['hasAttend'] == true)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                event['hasInvite'] == true ? '+ Invite' : '+ Attend',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiView() {
    final days = _getMultiViewDays();
    final recurringEvents = _getRecurringEvents();

    return Column(
      children: [
        // Date range header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Nov 1st - 4th',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),

        // Multi-day grid
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF333333),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: days.map((day) {
                  return Container(
                    width: 120,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day['label'] as String,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...recurringEvents.map((event) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: event['color'] as Color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event['title'] as String,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    event['time'] as String,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 10,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        // Reminders section
        _buildRemindersSection(),
      ],
    );
  }

  Widget _buildMonthView() {
    return Column(
      children: [
        // Month header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'November',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),

        // Calendar grid
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
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
            child: _buildCalendarGrid(),
          ),
        ),

        // Reminders section
        _buildRemindersSection(),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_monthViewDate.year, _monthViewDate.month, 1);
    final lastDay = DateTime(_monthViewDate.year, _monthViewDate.month + 1, 0);
    final firstWeekday = firstDay.weekday % 7; // 0 = Sunday, 6 = Saturday

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Day labels
          Row(
            children: ['S', 'M', 'T', 'W', 'Th', 'F', 'S']
                .map((label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Calendar days
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: 35, // 5 weeks
              itemBuilder: (context, index) {
                final day = index - firstWeekday + 1;
                if (day < 1 || day > lastDay.day) {
                  return const SizedBox.shrink();
                }

                final date = DateTime(_monthViewDate.year, _monthViewDate.month, day);
                final eventsForDay = _getEventsForDate(date);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentDate = date;
                      _currentView = CalendarView.day;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: day == _currentDate.day &&
                                      _monthViewDate.month == _currentDate.month
                                  ? CalendarPage.forgeBlue
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Event indicators
                        ...eventsForDay.take(2).map((event) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            height: 3,
                            decoration: BoxDecoration(
                              color: event['color'] as Color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Text(
        'Reminders',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFilterPopup() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showFilterPopup = false;
        });
      },
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping inside
            child: Container(
              width: 200,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Events',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showFilterPopup = false;
                          });
                        },
                        child: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._filterStates.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _filterColors[entry.key],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Checkbox(
                            value: entry.value,
                            onChanged: (value) {
                              setState(() {
                                _filterStates[entry.key] = value ?? false;
                              });
                            },
                            activeColor: CalendarPage.forgeBlue,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventDetailOverlay() {
    final event = _selectedEvent!;
    final start = event['start'] as DateTime;
    final end = event['end'] as DateTime;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedEvent = null;
        });
      },
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping inside
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event['title'] as String,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (event['privacy'] != null)
                                  Text(
                                    event['privacy'] as String,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedEvent = null;
                              });
                            },
                            child: const Icon(Icons.close, size: 24),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Owner
                      if (event['owner'] != null)
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Colors.grey,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              event['owner'] as String,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),

                      // Date & Time
                      _buildDetailRow(
                        Icons.calendar_today,
                        '${_formatDate(start)}, ${start.year}',
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        Icons.access_time,
                        '${_formatTime(start)} - ${_formatTime(end)}',
                      ),
                      const SizedBox(height: 16),

                      // Location
                      if (event['location'] != null) ...[
                        _buildDetailRow(
                          Icons.location_on,
                          event['location'] as String,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Attendees
                      if (event['attendees'] != null) ...[
                        const Text(
                          'Attendees',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...(event['attendees'] as List<String>).map((attendee) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    color: Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  attendee,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 24),
                      ],

                      // Exercises
                      if (event['exercises'] != null) ...[
                        const Text(
                          'Exercises',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...(event['exercises'] as List<Map<String, String>>).map((exercise) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${exercise['name']} (${exercise['sets']} - ${exercise['weight']})',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 24),
                      ],

                      // View in Workouts button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // Navigate to workouts screen
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CalendarPage.forgeBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'View in Workouts Screen',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Notes
                      const Text(
                        'Notes',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          event['notes'] as String? ?? '',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.black54),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }


  // Helper methods
  List<String> _generateHours() {
    return List.generate(21, (i) {
      final hour = 4 + i;
      if (hour < 12) {
        return '${hour}:00 AM';
      } else if (hour == 12) {
        return '12:00 PM';
      } else {
        return '${hour - 12}:00 PM';
      }
    });
  }

  List<Map<String, dynamic>> _getMultiViewDays() {
    return [
      {'label': 'S'},
      {'label': 'M'},
      {'label': 'T'},
      {'label': 'W'},
    ];
  }

  List<Map<String, dynamic>> _getEventsForDate(DateTime date) {
    return _dummyEvents.where((event) {
      final eventDate = event['start'] as DateTime;
      return eventDate.year == date.year &&
          eventDate.month == date.month &&
          eventDate.day == date.day;
    }).toList();
  }

  String _formatDate(DateTime date) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}${_getDaySuffix(date.day)}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr $period';
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
