import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/app_header.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../features/event_creator/presentation/view/event_creator_page.dart';
import '../../../../services/events_service.dart';

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
  DateTime _currentDate = DateTime.now();
  DateTime _monthViewDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

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

  final ScrollController _dayScrollController = ScrollController();
  Timer? _nowTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollDayViewToNow(jump: true);
    });
    _nowTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _currentView == CalendarView.day) {
        setState(() {
          // just trigger rebuild so now-line moves
        });
      }
    });
  }

  @override
  void dispose() {
    _nowTimer?.cancel();
    _dayScrollController.dispose();
    super.dispose();
  }

  void _scrollDayViewToNow({required bool jump}) {
    if (_currentView != CalendarView.day) return;
    if (!_dayScrollController.hasClients) return;

    final now = DateTime.now();
    final hourHeight = 80.0;
    final startHour = now.hour + now.minute / 60.0;

    // Timeline starts at 4am in the UI.
    final rawTop = (startHour - 4) * hourHeight;

    // Place "now" roughly one third down from the top of the viewport.
    final viewport = _dayScrollController.position.viewportDimension;
    final target = rawTop - (viewport / 3);

    final clamped = target.clamp(
      0.0,
      _dayScrollController.position.maxScrollExtent,
    );

    if (jump) {
      _dayScrollController.jumpTo(clamped);
    } else {
      _dayScrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
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
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppHeader(
                      leading: GestureDetector(
                        onTap: () {
                          setState(() => _showFilterPopup = !_showFilterPopup);
                        },
                        child: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
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

  Widget _buildViewTab(String label, CalendarView view) {
    final isSelected = _currentView == view;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentView = view;
        });
        if (view == CalendarView.day) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollDayViewToNow(jump: false);
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyWithColor(
            isSelected ? CalendarPage.forgeBlue : Colors.black87,
          ).copyWith(
            fontWeight: FontWeight.w600,
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

    return Column(
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: Colors.black87,
                onPressed: () {
                  setState(() {
                    _currentDate = _currentDate.subtract(const Duration(days: 1));
                  });
                },
              ),
              Text(
                dateStr,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: Colors.black87,
                onPressed: () {
                  setState(() {
                    _currentDate = _currentDate.add(const Duration(days: 1));
                  });
                },
              ),
            ],
          ),
        ),

        // Timeline (streams events from Firestore for this day)
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: getEventsForDayStream(_currentDate),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load events',
                    style: AppTextStyles.bodySmallWithColor(Colors.black54),
                  ),
                );
              }
              final eventsForDay = snapshot.data ?? [];
              return _buildDayTimeline(eventsForDay);
            },
          ),
        ),
      ],
    );
  }

  /// For each event, returns (columnIndex, totalColumns) so overlapping events
  /// are placed side by side. Events overlap when startA < endB && endA > startB.
  List<(int, int)> _eventColumns(List<Map<String, dynamic>> events) {
    if (events.isEmpty) return [];
    final starts = events.map((e) => (e['start'] as DateTime).millisecondsSinceEpoch).toList();
    final ends = events.map((e) => (e['end'] as DateTime).millisecondsSinceEpoch).toList();
    final result = <(int, int)>[];
    for (int i = 0; i < events.length; i++) {
      final overlapping = <int>[];
      for (int j = 0; j < events.length; j++) {
        if (starts[j] < ends[i] && ends[j] > starts[i]) overlapping.add(j);
      }
      overlapping.sort((a, b) => starts[a].compareTo(starts[b]));
      final columnIndex = overlapping.indexOf(i);
      result.add((columnIndex, overlapping.length));
    }
    return result;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDayTimeline(List<Map<String, dynamic>> events) {
    final hours = _generateHours();
    final hourHeight = 80.0;
    final columns = _eventColumns(events);
    const timeLabelWidth = 100.0;
    const rightMargin = 16.0;

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth - timeLabelWidth - rightMargin;
          return SingleChildScrollView(
            controller: _dayScrollController,
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
                // Current time line (only for today, between 4am and midnight)
                if (_isSameDay(_currentDate, DateTime.now()))
                  Builder(
                    builder: (context) {
                      final now = DateTime.now();
                      final nowHour = now.hour + now.minute / 60.0;
                      final top = (nowHour - 4) * hourHeight;
                      if (top < 0 || top > hours.length * hourHeight) {
                        return const SizedBox.shrink();
                      }
                      return Positioned(
                        top: top,
                        left: 0,
                        right: 0,
                        child: Row(
                          children: [
                            const SizedBox(width: 80),
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: CalendarPage.forgeBlue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Container(
                                      height: 2,
                                      color: CalendarPage.forgeBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: rightMargin),
                          ],
                        ),
                      );
                    },
                  ),
                // Events (side by side when overlapping)
                ...events.asMap().entries.map((entry) {
                  final index = entry.key;
                  final event = entry.value;
                  final start = event['start'] as DateTime;
                  final end = event['end'] as DateTime;
                  final startHour = start.hour + start.minute / 60.0;
                  final endHour = end.hour + end.minute / 60.0;
                  final top = (startHour - 4) * hourHeight;
                  final height = (endHour - startHour) * hourHeight;
                  final (columnIndex, totalColumns) = columns[index];
                  final eventWidth = availableWidth / totalColumns;
                  final left = timeLabelWidth + columnIndex * eventWidth;

                  return Positioned(
                    left: left,
                    width: eventWidth - 2,
                    top: top,
                    height: height,
                    child: GestureDetector(
                  onTap: () => _onEventTap(event),
                  child: SizedBox(
                    height: height,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
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
                            // Title: full (2 lines) when card is tall enough; 1 line only on very short cards
                            Text(
                              event['title'] as String,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              maxLines: height >= 70 ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Time: only when there's space left under the title (don't sacrifice title space)
                            if (height >= 90) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${_formatTime(start)} – ${_formatTime(end)}',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
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
                  ),
                  ),
                );
            }).toList(),
          ],
        ),
      );
        },
      ),
    );
  }

  void _onEventTap(Map<String, dynamic> event) {
    if (event['isOwnEvent'] != false) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => EventCreatorPage(
          eventId: event['id'] as String,
          embedded: true,
        ),
      );
    } else {
      setState(() => _selectedEvent = event);
    }
  }

  /// Events for the 4-day multi view: list of events, grouped by day index 0..3.
  List<List<Map<String, dynamic>>> _eventsByDay(List<Map<String, dynamic>> rangeEvents) {
    final start = _currentDate;
    final byDay = <List<Map<String, dynamic>>>[
      [],
      [],
      [],
      [],
    ];
    for (final event in rangeEvents) {
      final d = event['start'] as DateTime;
      for (int i = 0; i < 4; i++) {
        final dayDate = start.add(Duration(days: i));
        if (d.year == dayDate.year && d.month == dayDate.month && d.day == dayDate.day) {
          byDay[i].add(event);
          break;
        }
      }
    }
    return byDay;
  }

  Widget _buildMultiView() {
    final days = _getMultiViewDays();
    final rangeEnd = _currentDate.add(const Duration(days: 3));

    return Column(
      children: [
        // Date range header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: Colors.black87,
                onPressed: () {
                  setState(() {
                    _currentDate = _currentDate.subtract(const Duration(days: 1));
                  });
                },
              ),
              Text(
                '${_formatDate(_currentDate)} - ${_formatDate(rangeEnd)}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: Colors.black87,
                onPressed: () {
                  setState(() {
                    _currentDate = _currentDate.add(const Duration(days: 1));
                  });
                },
              ),
            ],
          ),
        ),

        // Multi-day grid (events from Firestore)
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: getEventsForDateRangeStream(_currentDate, rangeEnd),
            builder: (context, snapshot) {
              final rangeEvents = snapshot.data ?? [];
              final byDay = _eventsByDay(rangeEvents);

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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: days.asMap().entries.map((entry) {
                    final index = entry.key;
                    final day = entry.value;
                    final date = day['date'] as DateTime;
                    final isCurrentDay =
                        date.year == _currentDate.year &&
                        date.month == _currentDate.month &&
                        date.day == _currentDate.day;
                    final dayEvents = byDay[index];

                    return Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCurrentDay
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.transparent,
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
                            ...dayEvents.map((event) {
                              final start = event['start'] as DateTime;
                              final end = event['end'] as DateTime;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GestureDetector(
                                  onTap: () => _onEventTap(event),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: event['color'] as Color,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          event['title'] as String,
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_formatTime(start)} – ${_formatTime(end)}',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 10,
                                            color: Colors.white.withValues(alpha: 0.9),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthView() {
    return Column(
      children: [
        // Month header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: Colors.black87,
                onPressed: () {
                  setState(() {
                    _monthViewDate = DateTime(
                      _monthViewDate.year,
                      _monthViewDate.month - 1,
                      1,
                    );
                    _currentDate = _monthViewDate;
                  });
                },
              ),
              Text(
                _getMonthName(_monthViewDate),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: Colors.black87,
                onPressed: () {
                  setState(() {
                    _monthViewDate = DateTime(
                      _monthViewDate.year,
                      _monthViewDate.month + 1,
                      1,
                    );
                    _currentDate = _monthViewDate;
                  });
                },
              ),
            ],
          ),
        ),

        // Calendar grid (full height, events from Firestore)
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
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: getEventsForDateRangeStream(
                DateTime(_monthViewDate.year, _monthViewDate.month, 1),
                DateTime(_monthViewDate.year, _monthViewDate.month + 1, 0),
              ),
              builder: (context, snapshot) {
                final monthEvents = snapshot.data ?? [];
                final eventsByDay = _eventsForMonthMap(monthEvents);
                return _buildCalendarGrid(eventsByDay);
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Map day-of-month (1–31) to events for that day in the visible month.
  Map<int, List<Map<String, dynamic>>> _eventsForMonthMap(
    List<Map<String, dynamic>> monthEvents,
  ) {
    final map = <int, List<Map<String, dynamic>>>{};
    for (final event in monthEvents) {
      final d = event['start'] as DateTime;
      if (d.month != _monthViewDate.month || d.year != _monthViewDate.year) continue;
      map.putIfAbsent(d.day, () => []).add(event);
    }
    return map;
  }

  Widget _buildCalendarGrid(Map<int, List<Map<String, dynamic>>> eventsByDay) {
    final firstDay = DateTime(_monthViewDate.year, _monthViewDate.month, 1);
    final lastDay = DateTime(_monthViewDate.year, _monthViewDate.month + 1, 0);
    final firstWeekday = firstDay.weekday % 7; // 0 = Sunday, 6 = Saturday
    const rowCount = 6; // 6 weeks so grid fills height
    const colCount = 7;

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
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Calendar days: 6 rows filling full height, each day shows number + event titles
          ...List.generate(rowCount, (row) {
            return Expanded(
              child: Row(
                children: List.generate(colCount, (col) {
                  final index = row * colCount + col;
                  final day = index - firstWeekday + 1;
                  if (day < 1 || day > lastDay.day) {
                    return Expanded(child: const SizedBox.shrink());
                  }

                  final date = DateTime(_monthViewDate.year, _monthViewDate.month, day);
                  final eventsForDay = eventsByDay[day] ?? [];
                  final isCurrentDay =
                      date.year == _currentDate.year &&
                      date.month == _currentDate.month &&
                      date.day == _currentDate.day;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentDate = date;
                            _currentView = CalendarView.day;
                          });
                        },
                        child: SizedBox.expand(
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isCurrentDay
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                              Text(
                                '$day',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isCurrentDay
                                      ? CalendarPage.forgeBlue
                                      : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Event titles only (tap to edit)
                              ...eventsForDay.take(3).map((event) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: GestureDetector(
                                    onTap: () => _onEventTap(event),
                                    behavior: HitTestBehavior.opaque,
                                    child: Text(
                                      event['title'] as String? ?? '',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 10,
                                        color: Colors.white70,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              }),
                            ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
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
    final start = _currentDate;
    const shortWeekdays = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];

    return List.generate(4, (index) {
      final date = start.add(Duration(days: index));
      final weekdayLabel = shortWeekdays[date.weekday - 1];
      return {
        'label': '$weekdayLabel ${date.day}',
        'date': date,
      };
    });
  }

  List<Map<String, dynamic>> _getEventsForDate(DateTime date) {
    return [];
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

  String _getMonthName(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[date.month - 1];
  }
}
