import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:forge_senior_project_version/core/constants/app_text_styles.dart';
import '../../../../app/app_header.dart';

enum FeedLayout { base, schedule, updates }

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  static const Color background = Color(0xFFF5F5F7);
  static const Color forgeBlue = Color(0xFF4D7CFF);

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  FeedLayout _currentLayout = FeedLayout.base;
  final ScrollController _updatesScrollController = ScrollController();
  final ScrollController _scheduleScrollController = ScrollController();
  double _scheduleHourHeight = 60.0; // Default height between hours

  static const List<String> _dummyFriends = [
    'Alex',
    'Jordan',
    'Sam',
    'Taylor',
    'Riley',
  ];

  static const List<Map<String, dynamic>> _dummyGoals = [
    {'label': 'Workouts', 'current': 4, 'target': 5},
    {'label': 'Meals', 'current': 2, 'target': 3},
    {'label': 'Runs', 'current': 3, 'target': 4},
  ];

  static const String _dummyUpdatesText = '4 Updates – BYU-I + 4 others';

  // Dummy schedule events
  static const List<Map<String, dynamic>> _dummyEvents = [
    {
      'title': 'Your Workout',
      'start': '9:00 AM',
      'end': '10:30 AM',
      'color': Colors.orange,
      'hasInvite': true,
    },
    {
      'title': 'Lunch',
      'start': '11:00 AM',
      'end': '12:00 PM',
      'color': Colors.yellow,
      'hasInvite': false,
    },
    {
      'title': "Ethan's Workout",
      'start': '9:00 AM',
      'end': '10:30 AM',
      'color': Colors.blue,
      'hasAttend': true,
    },
  ];

  // Dummy updates
  static const List<Map<String, dynamic>> _dummyUpdates = [
    {
      'source': 'BYU-I',
      'text':
          'Lorem ipsum dolor itset lorem ipsum dolor itset lorem ipsum dolor itset',
      'hasImage': true,
    },
    {
      'source': 'Ethan',
      'text': 'Completed a goal or sum type beat',
      'hasImage': false,
    },
  ];

  @override
  void dispose() {
    _updatesScrollController.dispose();
    _scheduleScrollController.dispose();
    super.dispose();
  }

  void _switchToLayout(FeedLayout layout) {
    if (_currentLayout != layout) {
      setState(() {
        _currentLayout = layout;
      });
    }
  }

  void _navigateToCalendar({String? eventId, String? timeSlot}) {
    // Navigate to calendar page - can pass eventId or timeSlot if needed
    context.go('/calendar');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FeedPage.background,
      body: SafeArea(
        child: Column(
          children: [
            // ---------- TOP HEADER BAR ----------
            const AppHeader(),

            // ---------- MAIN CONTENT ----------
            Expanded(
              child: _buildMainContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    // Always build base layout, with expandable sections
    return _buildBaseLayout();
  }

  // ---------- LAYOUT 1: BASE FEED (Non-scrollable) ----------
  Widget _buildBaseLayout() {
    final bool isScheduleExpanded = _currentLayout == FeedLayout.schedule;
    final bool isUpdatesExpanded = _currentLayout == FeedLayout.updates;

    return Column(
      children: [
        const SizedBox(height: 12),
        // Day selector
        Center(
          child: GestureDetector(
            onTap: () {
              if (isScheduleExpanded) {
                _switchToLayout(FeedLayout.base);
              } else {
                _switchToLayout(FeedLayout.schedule);
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: FeedPage.forgeBlue,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Wednesday',
                style: AppTextStyles.title
                    .copyWith(fontSize: 24, fontWeight: AppTextStyles.lightWeight, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Arrow - rotates based on state
        GestureDetector(
          onTap: () {
            if (isScheduleExpanded) {
              _switchToLayout(FeedLayout.base);
            } else {
              _switchToLayout(FeedLayout.schedule);
            }
          },
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 300),
            turns: isScheduleExpanded ? 0.5 : 0.0,
            child: const Icon(
              Icons.expand_more,
              size: 28,
              color: Colors.black54,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Main content area - handles schedule, cards, and updates
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Schedule section - expands/collapses with slide animation
                    if (isScheduleExpanded)
                      Flexible(
                        fit: FlexFit.loose,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, -0.3),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeInOutCubic,
                              )),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: _buildExpandedSchedule(key: const ValueKey('schedule')),
                        ),
                      ),

                    // Cards section - only show when updates are NOT expanded
                    if (!isUpdatesExpanded) ...[
                      Expanded(
                        child: SingleChildScrollView(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.0, 0.1),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeInOutCubic,
                                  )),
                                  child: child,
                                ),
                              );
                            },
                            child: isScheduleExpanded
                                ? _buildCollapsedCards(key: const ValueKey('collapsed'))
                                : _buildFullCards(key: const ValueKey('full')),
                          ),
                        ),
                      ),
                      _buildUpdatesBar(),
                      const SizedBox(height: 16),
                    ] else
                      // Updates section - expands to fill entire space when opened
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 1.0), // Slide up from bottom
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeInOutCubic,
                              )),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: _buildExpandedUpdates(key: const ValueKey('expanded')),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Helper methods for expandable sections
  Widget _buildFullCards({Key? key}) {
    return Column(
      key: key,
      children: [
        // First row: Cardio + Friends
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _FeedSectionCard(
                title: 'Cardio',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.directions_run,
                      size: 64,
                      color: Colors.orangeAccent,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Workout of the day',
                      style: AppTextStyles.bodySmallWithColor(Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _FeedSectionCard(
                title: 'Friends',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _dummyFriends.map((name) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.white24,
                            child: Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmallWithColor(Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Second row: Goals
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _FeedSectionCard(
                title: 'Goals',
                child: Column(
                  children: _dummyGoals.map((goal) {
                    final String label = goal['label'] as String;
                    final int current = goal['current'] as int;
                    final int target = goal['target'] as int;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _GoalRow(
                        label: label,
                        current: current,
                        target: target,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              flex: 2,
              child: SizedBox.shrink(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCollapsedCards({Key? key}) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        _CollapsedCard(title: 'Cardio', onTap: () => _switchToLayout(FeedLayout.base)),
        const SizedBox(height: 6),
        _CollapsedCard(title: 'Friends', onTap: () => _switchToLayout(FeedLayout.base)),
        const SizedBox(height: 6),
        _CollapsedCard(title: 'Goals', onTap: () => _switchToLayout(FeedLayout.base)),
      ],
    );
  }

  Widget _buildExpandedSchedule({Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 350),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return _ScheduleTimeline(
              events: _dummyEvents,
              hourHeight: _scheduleHourHeight,
              scrollController: _scheduleScrollController,
              availableWidth: constraints.maxWidth,
              onEventTap: (event) => _navigateToCalendar(
                eventId: event['title'] as String,
              ),
              onTimeSlotTap: (time) => _navigateToCalendar(
                timeSlot: time,
              ),
              onScaleUpdate: (scale) {
                setState(() {
                  _scheduleHourHeight =
                      (_scheduleHourHeight * scale).clamp(40.0, 120.0);
                });
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildUpdatesBar({Key? key}) {
    final bool isUpdatesExpanded = _currentLayout == FeedLayout.updates;
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          if (isUpdatesExpanded) {
            _switchToLayout(FeedLayout.base);
          } else {
            _switchToLayout(FeedLayout.updates);
          }
        },
        child: _UpdatesBar(
          text: _dummyUpdatesText,
          isExpanded: isUpdatesExpanded,
        ),
      ),
    );
  }

  Widget _buildExpandedUpdates({Key? key}) {
    return Stack(
      key: key,
      children: [
        // Scrollable updates feed
        ListView.builder(
          controller: _updatesScrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _dummyUpdates.length,
          itemBuilder: (context, index) {
            final update = _dummyUpdates[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _UpdateCard(
                source: update['source'] as String,
                text: update['text'] as String,
                hasImage: update['hasImage'] as bool,
              ),
            );
          },
        ),
        // Fixed return button (bottom right)
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: FeedPage.forgeBlue,
            onPressed: () => _switchToLayout(FeedLayout.base),
            child: const Icon(
              Icons.expand_less,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }


}

// ------------ SCHEDULE TIMELINE WIDGET ------------
class _ScheduleTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final double hourHeight;
  final ScrollController scrollController;
  final double availableWidth;
  final Function(Map<String, dynamic>) onEventTap;
  final Function(String) onTimeSlotTap;
  final Function(double) onScaleUpdate;

  const _ScheduleTimeline({
    required this.events,
    required this.hourHeight,
    required this.scrollController,
    required this.availableWidth,
    required this.onEventTap,
    required this.onTimeSlotTap,
    required this.onScaleUpdate,
  });

  // Generate hours from 4am to 12am (midnight)
  List<String> _generateHours() {
    final hours = <String>[];
    for (int i = 4; i <= 24; i++) {
      final hour = i == 24 ? 12 : (i > 12 ? i - 12 : i);
      final period = i < 12 ? 'AM' : (i == 24 ? 'AM' : 'PM');
      hours.add('$hour:00 $period');
    }
    return hours;
  }

  // Parse time string to minutes from 4am
  int _timeToMinutes(String time) {
    final parts = time.split(' ');
    final timePart = parts[0];
    final period = parts[1];
    final hourMin = timePart.split(':');
    int hour = int.parse(hourMin[0]);
    int minute = hourMin.length > 1 ? int.parse(hourMin[1]) : 0;

    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;

    // Convert to minutes from 4am (240 minutes)
    int totalMinutes = (hour * 60) + minute;
    return totalMinutes - 240; // Offset from 4am
  }

  // Check if two events overlap
  bool _eventsOverlap(Map<String, dynamic> event1, Map<String, dynamic> event2) {
    final start1 = _timeToMinutes(event1['start'] as String);
    final end1 = _timeToMinutes(event1['end'] as String);
    final start2 = _timeToMinutes(event2['start'] as String);
    final end2 = _timeToMinutes(event2['end'] as String);

    return !(end1 <= start2 || end2 <= start1);
  }

  // Calculate column position for overlapping events
  List<Map<String, dynamic>> _calculateEventPositions(
      List<Map<String, dynamic>> events) {
    final positionedEvents = <Map<String, dynamic>>[];

    for (int i = 0; i < events.length; i++) {
      final event = Map<String, dynamic>.from(events[i]);
      int column = 0;
      int maxColumns = 1;

      // Find all overlapping events
      final overlapping = <int>[];
      for (int j = 0; j < i; j++) {
        if (_eventsOverlap(events[j], events[i])) {
          overlapping.add(j);
        }
      }

      // Find the rightmost column used by overlapping events
      for (final idx in overlapping) {
        final overlappedEvent = positionedEvents.firstWhere(
          (e) => e['index'] == idx,
        );
        final overlappedColumn = overlappedEvent['column'] as int;
        column = column > overlappedColumn ? column : overlappedColumn + 1;
      }

      // Calculate how many columns this group needs
      for (final idx in overlapping) {
        final overlappedEvent = positionedEvents.firstWhere(
          (e) => e['index'] == idx,
        );
        final overlappedColumns = overlappedEvent['maxColumns'] as int;
        maxColumns = maxColumns > overlappedColumns
            ? maxColumns
            : overlappedColumns;
      }

      // Update maxColumns for all overlapping events
      for (final idx in overlapping) {
        final overlappedEvent = positionedEvents.firstWhere(
          (e) => e['index'] == idx,
        );
        overlappedEvent['maxColumns'] = maxColumns + 1;
      }

      event['column'] = column;
      event['maxColumns'] = maxColumns + 1;
      event['index'] = i;
      positionedEvents.add(event);
    }

    return positionedEvents;
  }

  @override
  Widget build(BuildContext context) {
    final hours = _generateHours();
    final totalHeight = hours.length * hourHeight;

    return Container(
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
      child: GestureDetector(
        onScaleUpdate: (details) {
          onScaleUpdate(details.scale);
        },
        child: SingleChildScrollView(
          controller: scrollController,
          child: Stack(
            children: [
              // Time markers
              SizedBox(
                height: totalHeight,
                child: Column(
                  children: hours.map((hour) {
                    return Container(
                      height: hourHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(
                              hour,
                              style: AppTextStyles.captionWithColor(Colors.white70),
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
              ),
              // Events - calculate positions with stacking
              ..._calculateEventPositions(events).map((event) {
                final startMinutes = _timeToMinutes(event['start'] as String);
                final endMinutes = _timeToMinutes(event['end'] as String);
                final duration = endMinutes - startMinutes;
                final top = startMinutes * (hourHeight / 60);
                final height = duration * (hourHeight / 60);
                final column = event['column'] as int;
                final maxColumns = event['maxColumns'] as int;
                final eventWidth = availableWidth / maxColumns;
                final left = 80 + (column * eventWidth);

                return Positioned(
                  left: left,
                  width: eventWidth - 4, // Small gap between events
                  top: top,
                  height: height,
                  child: GestureDetector(
                    onTap: () => onEventTap(event),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: event['color'] as Color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        height: height,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    event['title'] as String,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      fontWeight: AppTextStyles.semiBoldWeight,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${event['start']} - ${event['end']}',
                                    style: AppTextStyles.captionWithColor(Colors.white70),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (event['hasInvite'] == true ||
                                event['hasAttend'] == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      event['hasInvite'] == true
                                          ? '+ Invite'
                                          : '+ Attend',
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: AppTextStyles.labelSmallSize,
                                        fontWeight: AppTextStyles.semiBoldWeight,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------ COLLAPSED CARD WIDGET ------------
class _CollapsedCard extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _CollapsedCard({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: FeedPage.forgeBlue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(
              title,
              style: AppTextStyles.subtitleWithColor(Colors.white),
            ),
            const Spacer(),
            const Icon(
              Icons.expand_less,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------ UPDATE CARD WIDGET ------------
class _UpdateCard extends StatelessWidget {
  final String source;
  final String text;
  final bool hasImage;

  const _UpdateCard({
    required this.source,
    required this.text,
    required this.hasImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: hasImage ? Colors.white : const Color(0xFF333333),
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
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: FeedPage.forgeBlue,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Text(
              source,
              style: AppTextStyles.subtitle.copyWith(
                fontWeight: AppTextStyles.semiBoldWeight,
                color: Colors.white,
              ),
            ),
          ),
          // Body
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasImage ? Colors.white : const Color(0xFF333333),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: hasImage
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          text,
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.image,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  )
                : Text(
                    text,
                    style: AppTextStyles.bodySmallWithColor(Colors.white),
                  ),
          ),
        ],
      ),
    );
  }
}

// ------------ REUSABLE CARD ------------
class _FeedSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _FeedSectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
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
          // header strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: FeedPage.forgeBlue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Text(
              title,
              style: AppTextStyles.subtitleWithColor(Colors.white),
            ),
          ),

          // body
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF333333),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ------------ GOAL ROW + RING ------------
class _GoalRow extends StatelessWidget {
  final String label;
  final int current;
  final int target;

  const _GoalRow({
    required this.label,
    required this.current,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final double progress =
        target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return Row(
      children: [
        Expanded(
          child: Text(
            '$label $current/$target',
            style: AppTextStyles.bodySmallWithColor(Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        _GoalProgressRing(
          progress: progress,
          current: current,
          target: target,
        ),
      ],
    );
  }
}

class _GoalProgressRing extends StatelessWidget {
  final double progress;
  final int current;
  final int target;

  const _GoalProgressRing({
    required this.progress,
    required this.current,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // base ring
          CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 4,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withValues(alpha: 0.25),
            ),
            backgroundColor: Colors.transparent,
          ),
          // progress ring
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 4,
            valueColor: const AlwaysStoppedAnimation<Color>(
              Colors.orangeAccent,
            ),
            backgroundColor: Colors.transparent,
          ),
          // number in center
          Text(
            '$current',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: AppTextStyles.semiBoldWeight,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------ UPDATES BAR ------------
class _UpdatesBar extends StatelessWidget {
  final String text;
  final bool isExpanded;

  const _UpdatesBar({
    required this.text,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_outlined,
            color: FeedPage.forgeBlue,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: AppTextStyles.mediumWeight,
                color: Colors.black87,
              ),
            ),
          ),
          AnimatedRotation(
            duration: const Duration(milliseconds: 300),
            turns: isExpanded ? 0.5 : 0.0,
            child: const Icon(
              Icons.expand_less,
              color: Colors.grey,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
