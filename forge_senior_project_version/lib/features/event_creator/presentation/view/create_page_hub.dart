import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/firebase/firestore_refs.dart';
import '../../../../services/events_service.dart';
import '../../../../services/friends_service.dart';
import '../../../../services/gyms_service.dart';
import '../../../../services/goals_service.dart';
import '../../../../services/plans_service.dart';
import '../../../../models/goal.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Top-level tabs on the Create (hub) page.
enum CreateHubTab {
  workouts,
  plans,
  goals,
  library,
}

/// Solid header colors for section bars (match design spec).
abstract class CreateSectionColors {
  static const Color popularBlue = Color(0xFF4D7CFF);
  static const Color fromGymsOrange = Color(0xFFFF8A4D);
  static const Color fromFriendsGreen = Color(0xFF43A047);
  static const Color currentBlue = Color(0xFF4D7CFF);
  static const Color previousMuted = Color(0xFF9DB4D8);
}

class CreatePageHub extends StatefulWidget {
  const CreatePageHub({
    super.key,
    required this.isGym,
    required this.onTabChanged,
    required this.onItemTap,
  });

  /// Reserved for future account-specific tab differences.
  final bool isGym;

  /// Notifies parent when the selected tab changes (for FAB behavior).
  final ValueChanged<CreateHubTab> onTabChanged;

  /// User tapped a tile to view details (workout / plan / goal name).
  final void Function(
    String title,
    CreateHubTab tab,
    String sectionTitle,
    String? itemId,
    bool itemEditable,
  ) onItemTap;

  @override
  State<CreatePageHub> createState() => _CreatePageHubState();
}

class _CreatePageHubState extends State<CreatePageHub>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Keys like `"workouts_0"` → expanded.
  final Map<String, bool> _expanded = {};

  int get _tabCount => 4;

  late DateTime _workoutsRangeStart;
  late DateTime _workoutsRangeEnd;
  late final StreamController<List<Map<String, dynamic>>>
      _workoutsEventsController;
  late final Stream<List<Map<String, dynamic>>> _workoutsEventsStream;
  StreamSubscription<List<Map<String, dynamic>>>? _workoutsEventsSub;

  // Keep Firestore streams alive exactly once and multicast them to all tab
  // subtrees. This prevents "Bad state: Stream has already been listened to"
  // during TabBarView lifecycle changes.
  late final StreamController<List<PlanSummary>> _plansController;
  late final StreamController<List<Goal>> _activeGoalsController;
  late final StreamController<List<Goal>> _allGoalsController;
  late final StreamController<_WorkoutsBucket> _libraryWorkoutsController;

  StreamSubscription<List<PlanSummary>>? _plansSub;
  StreamSubscription<List<Goal>>? _activeGoalsSub;
  StreamSubscription<List<Goal>>? _allGoalsSub;
  StreamSubscription<_WorkoutsBucket>? _libraryWorkoutsSub;
  StreamSubscription<User?>? _authSub;

  List<Map<String, dynamic>> _latestWorkoutsEvents = const [];
  List<PlanSummary> _latestPlans = const [];
  List<Goal> _latestActiveGoals = const [];
  List<Goal> _latestAllGoals = const [];
  _WorkoutsBucket _latestLibraryWorkouts =
      const _WorkoutsBucket(current: [], previous: []);
  List<String> _friendUids = const [];
  List<String> _gymUids = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController.addListener(_onTabControllerTick);
    _workoutsRangeStart = DateTime.now();
    _workoutsRangeEnd = _workoutsRangeStart.add(const Duration(days: 60));
    _workoutsEventsController =
        StreamController<List<Map<String, dynamic>>>.broadcast(onListen: () {
      if (!_workoutsEventsController.isClosed) {
        _workoutsEventsController.add(_latestWorkoutsEvents);
      }
    });
    _workoutsEventsStream = _workoutsEventsController.stream;

    _plansController = StreamController<List<PlanSummary>>.broadcast(
      onListen: () {
        if (!_plansController.isClosed) _plansController.add(_latestPlans);
      },
    );
    _activeGoalsController = StreamController<List<Goal>>.broadcast(
      onListen: () {
        if (!_activeGoalsController.isClosed) {
          _activeGoalsController.add(_latestActiveGoals);
        }
      },
    );
    _allGoalsController = StreamController<List<Goal>>.broadcast(
      onListen: () {
        if (!_allGoalsController.isClosed) {
          _allGoalsController.add(_latestAllGoals);
        }
      },
    );
    _libraryWorkoutsController = StreamController<_WorkoutsBucket>.broadcast(
      onListen: () {
        if (!_libraryWorkoutsController.isClosed) {
          _libraryWorkoutsController.add(_latestLibraryWorkouts);
        }
      },
    );

    // Seed with empty data immediately; then auth will repopulate.
    _latestWorkoutsEvents = const <Map<String, dynamic>>[];
    _latestPlans = const <PlanSummary>[];
    _latestActiveGoals = const <Goal>[];
    _latestAllGoals = const <Goal>[];
    _latestLibraryWorkouts = const _WorkoutsBucket(current: [], previous: []);

    _workoutsEventsController.add(_latestWorkoutsEvents);
    _plansController.add(_latestPlans);
    _activeGoalsController.add(_latestActiveGoals);
    _allGoalsController.add(_latestAllGoals);
    _libraryWorkoutsController.add(_latestLibraryWorkouts);

    // Start subscriptions only once Firebase auth is ready.
    _authSub = FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthUserChanged,
    );

    // Also kick it once synchronously so the page can populate even if the
    // auth stream doesn't emit immediately.
    _handleAuthUserChanged(FirebaseAuth.instance.currentUser);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onTabChanged(_currentTabFromIndex(_tabController.index));
    });
  }

  void _handleAuthUserChanged(User? user) {
    if (!mounted) return;

    // Cancel existing user subscriptions.
    _workoutsEventsSub?.cancel();
    _plansSub?.cancel();
    _activeGoalsSub?.cancel();
    _allGoalsSub?.cancel();
    _libraryWorkoutsSub?.cancel();

    _workoutsEventsSub = null;
    _plansSub = null;
    _activeGoalsSub = null;
    _allGoalsSub = null;
    _libraryWorkoutsSub = null;

    if (user == null) {
      _latestWorkoutsEvents = const <Map<String, dynamic>>[];
      _latestPlans = const <PlanSummary>[];
      _latestActiveGoals = const <Goal>[];
      _latestAllGoals = const <Goal>[];
      _latestLibraryWorkouts = const _WorkoutsBucket(current: [], previous: []);

      _workoutsEventsController.add(_latestWorkoutsEvents);
      _plansController.add(_latestPlans);
      _activeGoalsController.add(_latestActiveGoals);
      _allGoalsController.add(_latestAllGoals);
      _libraryWorkoutsController.add(_latestLibraryWorkouts);

      setState(() {
        _friendUids = const [];
        _gymUids = const [];
      });
      return;
    }

    final uid = user.uid;

    _workoutsEventsSub = getEventsForDateRangeStream(
      _workoutsRangeStart,
      _workoutsRangeEnd,
    ).listen(
      (data) {
        _latestWorkoutsEvents = data;
        _workoutsEventsController.add(data);
      },
      onError: (Object error, StackTrace st) {
        _workoutsEventsController.addError(error, st);
      },
    );

    _plansSub = getAllPlansStreamForCurrentUser().listen(
      (data) {
        _latestPlans = data;
        _plansController.add(data);
      },
      onError: (Object error, StackTrace st) {
        _plansController.addError(error, st);
      },
    );

    _activeGoalsSub = getActiveGoalsStream().listen(
      (data) {
        _latestActiveGoals = data;
        _activeGoalsController.add(data);
      },
      onError: (Object error, StackTrace st) {
        _activeGoalsController.addError(error, st);
      },
    );

    _allGoalsSub = getAllGoalsStream().listen(
      (data) {
        _latestAllGoals = data;
        _allGoalsController.add(data);
      },
      onError: (Object error, StackTrace st) {
        _allGoalsController.addError(error, st);
      },
    );

    final workoutsSource = FirestoreRefs.userEvents(uid)
        .where('eventType', isEqualTo: 'workout')
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      final items = snap.docs.map((d) {
        final m = d.data();
        final title = m['title'] as String? ?? '';
        final start = (m['startAt'] as Timestamp?)?.toDate();
        final end = (m['endAt'] as Timestamp?)?.toDate();
        return (
          id: d.id,
          title: title,
          start: start,
          end: end,
        );
      }).where((x) => x.title.isNotEmpty && x.end != null).toList();

      items.sort((a, b) => a.end!.compareTo(b.end!));

      final current = items
          .where((x) => !x.end!.isBefore(now))
          .toList()
        ..sort((a, b) {
          final sa = a.start ?? a.end!;
          final sb = b.start ?? b.end!;
          return sa.compareTo(sb);
        });

      final previous = items
          .where((x) => x.end!.isBefore(now))
          .toList()
        ..sort((a, b) {
          final sa = a.start ?? a.end!;
          final sb = b.start ?? b.end!;
          return sb.compareTo(sa);
        });

      return _WorkoutsBucket(
        current: current
            .take(8)
            .map((x) => _HubItemData(
                  id: x.id,
                  title: x.title,
                  itemEditable: true,
                ))
            .toList(),
        previous: previous
            .take(8)
            .map((x) => _HubItemData(
                  id: x.id,
                  title: x.title,
                  itemEditable: true,
                ))
            .toList(),
      );
    });

    _libraryWorkoutsSub = workoutsSource.listen(
      (data) {
        _latestLibraryWorkouts = data;
        _libraryWorkoutsController.add(data);
      },
      onError: (Object error, StackTrace st) {
        _libraryWorkoutsController.addError(error, st);
      },
    );

    _loadFriendAndGymUids();
  }

  Future<void> _loadFriendAndGymUids() async {
    try {
      final friends = await getFriendIdsWithNames();
      final gyms = await getJoinedGymsWithNames();
      if (!mounted) return;
      setState(() {
        _friendUids = friends
            .map((f) => f['uid'])
            .whereType<String>()
            .toList(growable: false);
        _gymUids = gyms
            .map((g) => g['uid'])
            .whereType<String>()
            .toList(growable: false);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _friendUids = const [];
        _gymUids = const [];
      });
    }
  }

  void _onTabControllerTick() {
    if (_tabController.indexIsChanging) return;
    widget.onTabChanged(_currentTabFromIndex(_tabController.index));
  }

  CreateHubTab _currentTabFromIndex(int i) {
    switch (i) {
      case 0:
        return CreateHubTab.workouts;
      case 1:
        return CreateHubTab.plans;
      case 2:
        return CreateHubTab.goals;
      default:
        return CreateHubTab.library;
    }
  }

  @override
  void didUpdateWidget(covariant CreatePageHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isGym != widget.isGym) {
      final wasIndex = _tabController.index;
      _tabController.removeListener(_onTabControllerTick);
      _tabController.dispose();
      final newLen = _tabCount;
      _tabController = TabController(
        length: newLen,
        vsync: this,
        initialIndex: wasIndex.clamp(0, newLen - 1),
      );
      _tabController.addListener(_onTabControllerTick);
      widget.onTabChanged(_currentTabFromIndex(_tabController.index));
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabControllerTick);
    _tabController.dispose();
    _authSub?.cancel();
    _workoutsEventsSub?.cancel();
    _workoutsEventsController.close();

    _plansSub?.cancel();
    _plansController.close();
    _activeGoalsSub?.cancel();
    _activeGoalsController.close();
    _allGoalsSub?.cancel();
    _allGoalsController.close();
    _libraryWorkoutsSub?.cancel();
    _libraryWorkoutsController.close();
    super.dispose();
  }

  String _sectionKey(CreateHubTab tab, int sectionIndex) =>
      '${tab.name}_$sectionIndex';

  bool _isExpanded(String key) => _expanded[key] ?? true;

  void _toggleSection(String key) {
    setState(() {
      _expanded[key] = !(_expanded[key] ?? true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildWorkoutsTab(),
              _buildPlansTab(),
              _buildGoalsTab(),
              _buildLibraryTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    const tabs = [
      Tab(text: 'Workouts'),
      Tab(text: 'Plans'),
      Tab(text: 'Goals'),
      Tab(text: 'Library'),
    ];

    return Material(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.black87,
        unselectedLabelColor: Colors.black38,
        indicatorColor: CreateSectionColors.popularBlue,
        labelStyle: AppTextStyles.body,
        unselectedLabelStyle: AppTextStyles.body,
        tabs: tabs,
      ),
    );
  }

  Widget _buildWorkoutsTab() {
    const tab = CreateHubTab.workouts;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _workoutsEventsStream,
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <Map<String, dynamic>>[];
        final workoutEvents = events
            .where((e) => (e['eventType'] as String? ?? '') == 'workout')
            .toList();

        DateTime? startOf(Map<String, dynamic> e) {
          final s = e['start'] as DateTime?;
          return s;
        }

        workoutEvents.sort((a, b) {
          final sa = startOf(a);
          final sb = startOf(b);
          if (sa == null && sb == null) return 0;
          if (sa == null) return 1;
          if (sb == null) return -1;
          return sa.compareTo(sb);
        });

        List<_HubItemData> uniqueTiles(
          Iterable<Map<String, dynamic>> src,
        ) {
          final seen = <String>{};
          final out = <_HubItemData>[];
          for (final e in src) {
            final id = e['id']?.toString() ?? '';
            final title = e['title'] as String? ?? '';
            final editable = e['isOwnEvent'] == true;
            if (id.isEmpty || title.isEmpty) continue;
            if (seen.add(id)) {
              out.add(
                _HubItemData(
                  id: id,
                  title: title,
                  itemEditable: editable,
                ),
              );
              if (out.length >= 8) break;
            }
          }
          return out;
        }

        final gymSet = _gymUids.toSet();
        final friendSet = _friendUids.toSet();

        final popular = uniqueTiles(workoutEvents);

        final gymOnly = workoutEvents.where((e) {
          final isOwn = e['isOwnEvent'] == true;
          final ownerId = e['ownerId'] as String?;
          return !isOwn && ownerId != null && gymSet.contains(ownerId);
        });

        final friendsOnly = workoutEvents.where((e) {
          final isOwn = e['isOwnEvent'] == true;
          final ownerId = e['ownerId'] as String?;
          return !isOwn && ownerId != null && friendSet.contains(ownerId);
        });

        final sections = [
          (
            title: 'Popular Workouts',
            color: CreateSectionColors.popularBlue,
            items: popular,
          ),
          (
            title: 'From Your Gyms',
            color: CreateSectionColors.fromGymsOrange,
            items: uniqueTiles(gymOnly),
          ),
          (
            title: 'From Your Friends',
            color: CreateSectionColors.fromFriendsGreen,
            items: uniqueTiles(friendsOnly),
          ),
        ];

        return _buildTabScroll(tab, sections);
      },
    );
  }

  Widget _buildGoalsTab() {
    const tab = CreateHubTab.goals;
    return StreamBuilder<List<Goal>>(
      stream: _activeGoalsController.stream,
      builder: (context, snapshot) {
        final goals = snapshot.data ?? const <Goal>[];
        final tiles = goals
            .where((g) => g.isActive)
            .take(8)
            .map((g) => _HubItemData(id: g.id, title: g.name, itemEditable: true))
            .toList();

        final sections = [
          (
            title: 'Popular Goals',
            color: CreateSectionColors.popularBlue,
            items: tiles,
          ),
          (
            title: 'From Your Gyms',
            color: CreateSectionColors.fromGymsOrange,
            items: const <_HubItemData>[],
          ),
          (
            title: 'From Your Friends',
            color: CreateSectionColors.fromFriendsGreen,
            items: const <_HubItemData>[],
          ),
        ];

        return _buildTabScroll(tab, sections);
      },
    );
  }

  Widget _buildPlansTab() {
    const tab = CreateHubTab.plans;
    return StreamBuilder<List<PlanSummary>>(
      stream: _plansController.stream,
      builder: (context, snapshot) {
        final plans = snapshot.data ?? const <PlanSummary>[];
        final popular = plans
            .where((p) => p.name.isNotEmpty)
            .map((p) => _HubItemData(id: p.id, title: p.name, itemEditable: true))
            .toList();
        final sections = [
          (
            title: 'Popular Plans',
            color: CreateSectionColors.popularBlue,
            items: popular,
          ),
          (
            title: 'From Your Gyms',
            color: CreateSectionColors.fromGymsOrange,
            items: const <_HubItemData>[],
          ),
          (
            title: 'From Your Friends',
            color: CreateSectionColors.fromFriendsGreen,
            items: const <_HubItemData>[],
          ),
        ];
        return _buildTabScroll(tab, sections);
      },
    );
  }

  Widget _buildLibraryTab() {
    const tab = CreateHubTab.library;

    return StreamBuilder<List<PlanSummary>>(
      stream: _plansController.stream,
      builder: (context, plansSnapshot) {
        final plans = plansSnapshot.data ?? const <PlanSummary>[];
        final now = DateTime.now();
        final currentPlans = plans
            .where((p) => !p.endDate.isBefore(now))
            .where((p) => p.name.isNotEmpty)
            .toList();
        final previousPlans = plans
            .where((p) => p.endDate.isBefore(now))
            .where((p) => p.name.isNotEmpty)
            .toList();

        return StreamBuilder<List<Goal>>(
          stream: _allGoalsController.stream,
          builder: (context, goalsSnapshot) {
            final goals = goalsSnapshot.data ?? const <Goal>[];
            final currentGoals = goals
                .where((g) => !g.endDate.isBefore(now))
                .where((g) => g.name.isNotEmpty)
                .take(8)
                .map((g) => _HubItemData(
                      id: g.id,
                      title: g.name,
                      itemEditable: true,
                    ))
                .toList();
            final previousGoals = goals
                .where((g) => g.endDate.isBefore(now))
                .where((g) => g.name.isNotEmpty)
                .take(8)
                .map((g) => _HubItemData(
                      id: g.id,
                      title: g.name,
                      itemEditable: true,
                    ))
                .toList();

            return StreamBuilder<_WorkoutsBucket>(
              stream: _libraryWorkoutsController.stream,
              builder: (context, workoutsSnapshot) {
                final workouts = workoutsSnapshot.data ??
                    const _WorkoutsBucket(current: [], previous: []);

                final sections = [
                  (
                    title: 'Current Workouts',
                    color: CreateSectionColors.currentBlue,
                    items: workouts.current,
                  ),
                  (
                    title: 'Current Plans',
                    color: CreateSectionColors.currentBlue,
                    items: currentPlans
                        .map((p) => _HubItemData(
                              id: p.id,
                              title: p.name,
                              itemEditable: true,
                            ))
                        .toList(),
                  ),
                  (
                    title: 'Current Goals',
                    color: CreateSectionColors.currentBlue,
                    items: currentGoals,
                  ),
                  (
                    title: 'Previous Workouts',
                    color: CreateSectionColors.previousMuted,
                    items: workouts.previous,
                  ),
                  (
                    title: 'Previous Plans',
                    color: CreateSectionColors.previousMuted,
                    items: previousPlans
                        .map((p) => _HubItemData(
                              id: p.id,
                              title: p.name,
                              itemEditable: true,
                            ))
                        .toList(),
                  ),
                  (
                    title: 'Previous Goals',
                    color: CreateSectionColors.previousMuted,
                    items: previousGoals,
                  ),
                ];

                return _buildTabScroll(tab, sections);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTabScroll(
    CreateHubTab tab,
    List<({String title, Color color, List<_HubItemData> items})> sections,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final s = sections[index];
        final key = _sectionKey(tab, index);
        final open = _isExpanded(key);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeaderBar(
                title: s.title,
                backgroundColor: s.color,
                expanded: open,
                onTap: () => _toggleSection(key),
              ),
              if (open) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 132,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: s.items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final item = s.items[i];
                      return _HubItemTile(
                        title: item.title,
                        onTap: () =>
                            widget.onItemTap(
                              item.title,
                              tab,
                              s.title,
                              item.id,
                              item.itemEditable,
                            ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // no additional placeholder data in hub sections
}

class _SectionHeaderBar extends StatelessWidget {
  const _SectionHeaderBar({
    required this.title,
    required this.backgroundColor,
    required this.expanded,
    required this.onTap,
  });

  final String title;
  final Color backgroundColor;
  final bool expanded;
  final VoidCallback onTap;

  /// Matches [_FeedSectionCard] / feed cards: soft drop shadow.
  static const List<BoxShadow> _feedCardShadow = [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: _feedCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            child: Ink(
              height: 48,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 44),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitleWithColor(Colors.white),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HubItemData {
  final String id;
  final String title;
  final bool itemEditable;

  const _HubItemData({
    required this.id,
    required this.title,
    required this.itemEditable,
  });
}

class _WorkoutsBucket {
  final List<_HubItemData> current;
  final List<_HubItemData> previous;

  const _WorkoutsBucket({
    required this.current,
    required this.previous,
  });
}

class _HubItemTile extends StatelessWidget {
  const _HubItemTile({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  static const Color _card = Color(0xFF3A3A3C);

  static const List<BoxShadow> _feedCardShadow = [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: _feedCardShadow,
      ),
      child: Material(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 148,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Center(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmallWithColor(Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
