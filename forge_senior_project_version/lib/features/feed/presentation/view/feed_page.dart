import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:forge_senior_project_version/core/constants/app_text_styles.dart';
import 'package:forge_senior_project_version/services/events_service.dart';
import 'package:forge_senior_project_version/services/friends_service.dart';
import 'package:forge_senior_project_version/services/updates_service.dart';
import 'package:forge_senior_project_version/services/channel_posts_service.dart';
import 'package:forge_senior_project_version/services/goals_service.dart';
import 'package:forge_senior_project_version/models/goal.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:forge_senior_project_version/features/social/presentation/view/channel_page.dart';
import '../../../../app/app_header.dart';

enum FeedLayout { base, updates }

// ------------ GRID SYSTEM ------------
/// Describes one widget placed on the feed grid (position + size in grid cells).
class FeedGridItem {
  const FeedGridItem({
    required this.col,
    required this.row,
    required this.width,
    required this.height,
    required this.child,
  });
  final int col;
  final int row;
  final int width;
  final int height;
  final Widget child;
}

/// Renders a grid of [gridWidth] x [gridHeight] and places [children] by their (col, row, width, height).
class FeedGrid extends StatelessWidget {
  const FeedGrid({
    super.key,
    required this.gridWidth,
    required this.gridHeight,
    required this.children,
    this.cellGap = 8.0,
  });

  final int gridWidth;
  final int gridHeight;
  final List<FeedGridItem> children;
  final double cellGap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;
        final cellWidth = (availableWidth - (gridWidth - 1) * cellGap) / gridWidth;
        final cellHeight = (availableHeight - (gridHeight - 1) * cellGap) / gridHeight;

        return Stack(
          children: children.map((item) {
            final left = item.col * (cellWidth + cellGap);
            final top = item.row * (cellHeight + cellGap);
            final w = item.width * cellWidth + (item.width - 1) * cellGap;
            final h = item.height * cellHeight + (item.height - 1) * cellGap;
            return Positioned(
              left: left,
              top: top,
              width: w,
              height: h,
              child: SizedBox.expand(child: item.child),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Builds a basic feed card: title bar + body. Use for static content.
Widget buildBasicFeedWidget({
  required String title,
  required int col,
  required int row,
  required int width,
  required int height,
  required Widget body,
  bool fillHeight = true,
}) {
  return _FeedSectionCard(title: title, child: body, fillHeight: fillHeight);
}

/// Builds a data-driven feed card: title bar + body from [bodyBuilder].
/// [bodyBuilder] is responsible for loading data and building the body (e.g. FutureBuilder/StreamBuilder).
Widget buildDataDrivenFeedWidget({
  required String name,
  required int col,
  required int row,
  required int width,
  required int height,
  required Widget Function(BuildContext context) bodyBuilder,
  bool fillHeight = true,
}) {
  return _FeedSectionCard(
    title: name,
    child: Builder(builder: bodyBuilder),
    fillHeight: fillHeight,
  );
}

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
  // (mini schedule removed)

  @override
  void dispose() {
    _updatesScrollController.dispose();
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
      body: Column(
        children: [
          // ---------- TOP HEADER BAR (extends behind status bar) ----------
          const AppHeader(),

          // ---------- MAIN CONTENT ----------
          Expanded(
            child: SafeArea(
              top: false,
              child: _buildMainContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    // Always build base layout, with expandable sections
    return _buildBaseLayout();
  }

  // ---------- LAYOUT 1: BASE FEED (Non-scrollable) ----------
  Widget _buildBaseLayout() {
    final bool isUpdatesExpanded = _currentLayout == FeedLayout.updates;

    return Column(
      children: [
        const SizedBox(height: 12),
        // Day selector (opens calendar)
        Center(
          child: GestureDetector(
            onTap: _navigateToCalendar,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Wednesday',
                    style: AppTextStyles.title.copyWith(
                      fontSize: 24,
                      fontWeight: AppTextStyles.lightWeight,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.chevron_right,
                    size: 26,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Main content area - handles cards and updates
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
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
                            child: _buildFullCards(key: const ValueKey('full')),
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
    // AspectRatio gives FeedGrid bounded height (SingleChildScrollView provides unbounded height
    // by default, which causes layout assertions)
    return AspectRatio(
      key: key,
      aspectRatio: 5 / 6, // grid is 5 wide x 6 tall
      child: FeedGrid(
        gridWidth: 5,
        gridHeight: 6,
        children: [
        // Next Workout: (0,0), 4 wide, 3 tall — data-driven
        FeedGridItem(
          col: 0,
          row: 0,
          width: 3,
          height: 3,
          child: buildDataDrivenFeedWidget(
            name: 'Next Workout',
            col: 0,
            row: 0,
            width: 3,
            height: 3,
            bodyBuilder: _buildNextWorkoutBody,
          ),
        ),
        // Goals: (0,3), 3 wide, 2 tall — data-driven
        FeedGridItem(
          col: 0,
          row: 3,
          width: 3,
          height: 2,
          child: buildDataDrivenFeedWidget(
            name: 'Goals',
            col: 0,
            row: 3,
            width: 3,
            height: 2,
            bodyBuilder: _buildGoalsBody,
          ),
        ),
        // Friends: (3,0), 2 wide, 4 tall — data-driven
        FeedGridItem(
          col: 3,
          row: 0,
          width: 2,
          height: 4,
          child: buildDataDrivenFeedWidget(
            name: 'Friends',
            col: 3,
            row: 0,
            width: 2,
            height: 4,
            bodyBuilder: _buildFriendsBody,
          ),
        ),
      ],
    ),
    );
  }

  /// Data-driven body: fetches next workout event and displays it.
  Widget _buildNextWorkoutBody(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: getNextWorkoutEventForUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: Colors.white70),
            ),
          );
        }
        final event = snapshot.data;
        if (event == null) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.directions_run,
                size: 64,
                color: Colors.orangeAccent,
              ),
              const SizedBox(height: 8),
              Text(
                'No upcoming workout',
                style: AppTextStyles.bodySmallWithColor(Colors.white),
              ),
            ],
          );
        }
        final title = event['title'] as String? ?? 'Workout';
        final startAt = event['startAt'] as DateTime?;
        final endAt = event['endAt'] as DateTime?;
        final timeStr = (startAt != null && endAt != null)
            ? '${_formatTime(startAt)} – ${_formatTime(endAt)}'
            : '';
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.subtitleWithColor(Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (timeStr.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                timeStr,
                style: AppTextStyles.bodySmallWithColor(Colors.white70),
              ),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => context.go('/calendar'),
              icon: const Icon(Icons.calendar_today, color: Colors.white, size: 18),
              label: Text(
                'View calendar',
                style: AppTextStyles.bodySmallWithColor(Colors.white),
              ),
              style: TextButton.styleFrom(
                backgroundColor: FeedPage.forgeBlue,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _formatTime(DateTime d) {
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final period = d.hour < 12 ? 'AM' : 'PM';
    final min = d.minute == 0 ? '' : ':${d.minute.toString().padLeft(2, '0')}';
    return '$hour$min $period';
  }

  Widget _buildGoalsBody(BuildContext context) {
    return StreamBuilder<List<Goal>>(
      stream: getActiveGoalsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(color: Colors.white70),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Goals unavailable',
              style: AppTextStyles.bodySmallWithColor(Colors.white70),
            ),
          );
        }

        final goals = snapshot.data ?? [];
        if (goals.isEmpty) {
          return Center(
            child: Text(
              'No goals yet',
              style: AppTextStyles.bodySmallWithColor(Colors.white70),
            ),
          );
        }

        final shown = goals.take(2).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...shown.map(
              (goal) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _GoalRow(
                  label: goal.name,
                  current: goal.currentCheckupsCompleted,
                  target: goal.requiredCheckupsPerPeriod,
                  onIncrement: () => _onGoalCheckIn(goal.id),
                  onDecrement: () => _onGoalUncheck(goal.id),
                ),
              ),
            ),
            if (goals.length > shown.length)
              Text(
                '+${goals.length - shown.length} more',
                style: AppTextStyles.captionWithColor(Colors.white70),
              ),
          ],
        );
      },
    );
  }

  Future<void> _onGoalCheckIn(String goalId) async {
    try {
      await checkIn(goalId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _onGoalUncheck(String goalId) async {
    try {
      await uncheckIn(goalId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Widget _buildFriendsBody(BuildContext context) {
    return FutureBuilder<List<Map<String, String>>>(
      future: getFriendIdsWithNames(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: Colors.white70),
            ),
          );
        }
        final friends = snapshot.data ?? [];
        if (friends.isEmpty) {
          return Center(
            child: Text(
              'No friends yet',
              style: AppTextStyles.bodySmallWithColor(Colors.white70),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: friends.map((f) {
            final name = f['name'] ?? 'Unknown';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, size: 14, color: Colors.white),
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
        );
      },
    );
  }

  Widget _buildUpdatesBar({Key? key}) {
    final bool isUpdatesExpanded = _currentLayout == FeedLayout.updates;
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 16),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: getFeedUpdatesStream(),
        builder: (context, snapshot) {
          String label;
          if (snapshot.connectionState == ConnectionState.waiting) {
            label = 'Loading updates…';
          } else if (snapshot.hasError) {
            label = 'Updates unavailable';
          } else {
            final count = snapshot.data?.length ?? 0;
            if (count == 0) {
              label = 'No updates yet';
            } else if (count == 1) {
              label = '1 update';
            } else {
              label = '$count updates';
            }
          }

          return GestureDetector(
            onTap: () {
              if (isUpdatesExpanded) {
                _switchToLayout(FeedLayout.base);
              } else {
                _switchToLayout(FeedLayout.updates);
              }
            },
            child: _UpdatesBar(
              text: label,
              isExpanded: isUpdatesExpanded,
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpandedUpdates({Key? key}) {
    return Stack(
      key: key,
      children: [
        // Scrollable updates feed
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: getFeedUpdatesStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Could not load updates',
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.black87),
                ),
              );
            }
            final updates = snapshot.data ?? [];
            if (updates.isEmpty) {
              return Center(
                child: Text(
                  'No updates yet',
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.black87),
                ),
              );
            }

            return ListView.builder(
              controller: _updatesScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: updates.length,
              itemBuilder: (context, index) {
                final update = updates[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: buildDataDrivenFeedWidget(
                    name: _updateTitle(update),
                    col: 0,
                    row: 0,
                    width: 1,
                    height: 1,
                    fillHeight: false,
                    bodyBuilder: (ctx) => _buildUpdateBody(ctx, update),
                  ),
                );
              },
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

  static String _updateTitle(Map<String, dynamic> update) {
    final type = update['type'] as String? ?? 'post';
    if (type == 'event') return 'Upcoming Event';
    final channel = update['channelName'] as String?;
    if (channel != null && channel.isNotEmpty) return '#$channel';
    return 'Update';
  }

  Widget _buildUpdateBody(BuildContext context, Map<String, dynamic> update) {
    final type = update['type'] as String? ?? 'post';
    if (type == 'event') {
      return _EventUpdateBody(update: update);
    }
    return _PostUpdateBody(
      update: update,
      onComment: () => _showCommentSheet(
        gymUid: update['gymUid'] as String,
        postId: update['postId'] as String,
      ),
    );
  }

  void _showCommentSheet({required String gymUid, required String postId}) {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Comments',
                style: AppTextStyles.subtitle.copyWith(color: Colors.black87),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: getCommentsStream(gymUid, postId),
                  builder: (context, snapshot) {
                    final comments = snapshot.data ?? [];
                    if (comments.isEmpty) {
                      return const Center(child: Text('No comments yet'));
                    }
                    return ListView.separated(
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, i) {
                        final c = comments[i];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c['authorName']?.toString() ?? 'User',
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: AppTextStyles.semiBoldWeight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(c['content']?.toString() ?? ''),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Add a comment…',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) async {
                  final text = controller.text.trim();
                  if (text.isEmpty) return;
                  controller.clear();
                  await addComment(gymUid, postId, text);
                },
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    ).whenComplete(controller.dispose);
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
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
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
              style: AppTextStyles.subtitleWithColor(Colors.white),
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
  final bool fillHeight;

  const _FeedSectionCard({
    required this.title,
    required this.child,
    this.fillHeight = true,
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
        mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
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

          // body (either fills remaining height or shrink-wraps)
          if (fillHeight)
            Expanded(
              child: Container(
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
            )
          else
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
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _GoalRow({
    required this.label,
    required this.current,
    required this.target,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final double progress =
        target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return Row(
      children: [
        Expanded(
          child: Text(
            '$label  $current/$target',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmallWithColor(Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onDecrement,
          child: const Icon(Icons.remove_circle_outline,
              size: 18, color: Colors.white70),
        ),
        const SizedBox(width: 6),
        _GoalProgressRing(
          progress: progress,
          current: current,
          target: target,
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onIncrement,
          child:
              const Icon(Icons.add_circle_outline, size: 18, color: Colors.white),
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

// ------------ UPDATE BODIES (DATA DRIVEN) ------------
class _EventUpdateBody extends StatelessWidget {
  final Map<String, dynamic> update;
  const _EventUpdateBody({required this.update});

  static String _formatTime(DateTime d) {
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final period = d.hour < 12 ? 'AM' : 'PM';
    final min = d.minute == 0 ? '' : ':${d.minute.toString().padLeft(2, '0')}';
    return '$hour$min $period';
  }

  @override
  Widget build(BuildContext context) {
    final owner = update['owner']?.toString() ?? 'Friend';
    final title = update['title']?.toString() ?? 'Event';
    final start = update['start'] as DateTime?;
    final end = update['end'] as DateTime?;
    final when = (start != null && end != null)
        ? '${_formatTime(start)} – ${_formatTime(end)}'
        : '';
    final location = update['location']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          owner,
          style: AppTextStyles.bodySmallWithColor(Colors.white70),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: AppTextStyles.subtitleWithColor(Colors.white),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (when.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(when, style: AppTextStyles.bodySmallWithColor(Colors.white70)),
        ],
        if (location != null && location.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            location,
            style: AppTextStyles.bodySmallWithColor(Colors.white70),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => context.go('/calendar'),
            icon: const Icon(Icons.calendar_today, color: Colors.white, size: 18),
            label: Text(
              'Open calendar',
              style: AppTextStyles.bodySmallWithColor(Colors.white),
            ),
            style: TextButton.styleFrom(
              backgroundColor: FeedPage.forgeBlue,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}

class _PostUpdateBody extends StatelessWidget {
  final Map<String, dynamic> update;
  final VoidCallback onComment;
  const _PostUpdateBody({required this.update, required this.onComment});

  @override
  Widget build(BuildContext context) {
    final gymUid = update['gymUid'] as String;
    final postId = update['postId'] as String;
    final channelName = update['channelName']?.toString() ?? 'general';
    final author = update['authorName']?.toString() ?? 'User';
    final content = update['content']?.toString() ?? '';
    final likeIds = (update['likeIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isLiked = myUid != null && likeIds.contains(myUid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          author,
          style: AppTextStyles.bodySmallWithColor(Colors.white70),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: AppTextStyles.bodySmallWithColor(Colors.white),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => togglePostLike(gymUid, postId),
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.redAccent : Colors.white,
                size: 18,
              ),
              label: Text(
                '${likeIds.length}',
                style: AppTextStyles.bodySmallWithColor(Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: getCommentsStream(gymUid, postId),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return TextButton.icon(
                  onPressed: onComment,
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                  label: Text(
                    '$count',
                    style: AppTextStyles.bodySmallWithColor(Colors.white),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (ctx) => ChannelPage(
                    gymUid: gymUid,
                    channelName: channelName,
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.open_in_new,
              size: 18,
              color: Colors.white,
            ),
            label: Text(
              'View in channel',
              style: AppTextStyles.bodySmallWithColor(Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
