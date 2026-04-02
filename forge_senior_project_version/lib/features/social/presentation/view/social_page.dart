import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../app/app_header.dart';
import '../../../../core/firebase/firestore_refs.dart';
import '../../../../services/gyms_service.dart';
import '../../../../services/search_service.dart';
import '../../../../services/direct_messages_service.dart';
import 'channel_page.dart';
import 'direct_message_page.dart';
import 'user_profile_detail_page.dart';
import '../../../../widgets/storage_avatar.dart';

enum SocialTab { messages, friends, gyms, channels, search }

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  static const Color background = Color(0xFFF5F5F7);
  static const Color forgeBlue = Color(0xFF4D7CFF);

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> with TickerProviderStateMixin {
  late TabController _tabController;
  bool get _usesGymTabLayout => _isGym == true;

  // Messages: derived from your joined gyms' latest channel posts.
  List<Map<String, dynamic>> _messages = [];
  bool _messagesLoading = true;

  // Friends: derived from your user's `friendIds`.
  List<Map<String, dynamic>> _friends = [];
  bool _friendsLoading = true;

  // Joined gyms loaded from Firestore (uid, name, avatar, channels, members)
  List<Map<String, dynamic>> _joinedGyms = [];
  bool _joinedGymsLoading = true;

  List<Map<String, dynamic>> _searchResults = [];
  final TextEditingController _searchController = TextEditingController();
  SearchFilter _searchFilter = SearchFilter.all;
  bool _searchLoading = false;
  Timer? _searchDebounce;

  // Gym-only: account type and channel management
  bool? _isGym;
  List<String> _gymChannels = [];
  bool _channelsLoading = false;
  final TextEditingController _newChannelController = TextEditingController();
  StreamSubscription<Map<String, int>>? _dmUnreadSub;
  Map<String, int> _dmUnreadByUid = const {};

  int get _gymsUnreadCount {
    final gymUids =
        _joinedGyms.map((g) => g['uid']?.toString() ?? '').where((x) => x.isNotEmpty);
    var total = 0;
    for (final uid in gymUids) {
      total += _dmUnreadByUid[uid] ?? 0;
    }
    return total;
  }

  int get _friendsUnreadCount {
    final friendUids =
        _friends.map((f) => f['uid']?.toString() ?? '').where((x) => x.isNotEmpty);
    var total = 0;
    for (final uid in friendUids) {
      total += _dmUnreadByUid[uid] ?? 0;
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    // Default to 4 tabs (no Channels) until we know if the account is a gym.
    // Without Messages tab:
    // - non-gym: Gyms, Friends, Search = 3
    // - gym: Gyms, Friends, Channels, Search = 4
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _dmUnreadSub = getDirectUnreadCountsStream().listen((counts) {
      if (!mounted) return;
      setState(() => _dmUnreadByUid = counts);
    });
    _loadAccountTypeAndChannels();
  }

  void _recreateTabControllerIfNeeded() {
    final desiredLength = _isGym == true ? 4 : 3;
    if (_tabController.length == desiredLength) return;

    final previous = _tabController;
    final next = TabController(
      length: desiredLength,
      vsync: this,
      // Reset to the first tab to avoid index-mapping issues when removing Messages.
      initialIndex: 0,
    );

    if (!mounted) {
      next.dispose();
      return;
    }

    // Swap controller in-state and dispose previous immediately.
    setState(() {
      _tabController = next;
    });
    previous.dispose();
  }

  Future<void> _loadAccountTypeAndChannels() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted && _isGym == null) {
        setState(() => _isGym = false);
      }
      return;
    }
    bool resolvedIsGym = false;
    try {
      final doc = await FirestoreRefs.userDoc(uid).get();
      final data = doc.data() ?? const <String, dynamic>{};
      final accountTypeRaw = data['accountType']?.toString().toLowerCase();
      final hasGymChannels = (data['channelNames'] as List<dynamic>?)?.isNotEmpty == true;
      final hasMemberField = data.containsKey('memberUserIds');
      resolvedIsGym =
          accountTypeRaw == 'gym' || hasGymChannels || hasMemberField;
      if (!mounted) return;
      setState(() => _isGym = resolvedIsGym);
      _recreateTabControllerIfNeeded();
    } catch (_) {
      // Do not downgrade a previously resolved account type on transient errors.
      if (mounted && _isGym == null) {
        setState(() => _isGym = false);
        _recreateTabControllerIfNeeded();
      }
      return;
    }

    if (resolvedIsGym) {
      // Channel loading errors should not downgrade account type.
      try {
        await _loadChannels();
      } catch (_) {}
    }
    await _loadJoinedGyms();
    await _loadFriendsList();
    await _loadMessagesList();
  }

  Future<void> _loadJoinedGyms() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() {
        _joinedGyms = [];
        _joinedGymsLoading = false;
      });
      return;
    }
    try {
      final doc = await FirestoreRefs.userDoc(uid).get();
      final joinedGymIds = doc.data()?['joinedGymIds'] as List<dynamic>?;
      if (joinedGymIds == null || joinedGymIds.isEmpty) {
        if (mounted) setState(() {
          _joinedGyms = [];
          _joinedGymsLoading = false;
        });
        return;
      }
      final list = <Map<String, dynamic>>[];
      for (final id in joinedGymIds) {
        final gymUid = id is String ? id : id.toString();
        if (gymUid.isEmpty) continue;
        try {
          final gymDoc = await FirestoreRefs.userDoc(gymUid).get();
          if (gymDoc.exists && gymDoc.data() != null) {
            final d = gymDoc.data()!;
            final channelNames = d['channelNames'] as List<dynamic>?;
            final memberIds = d['memberUserIds'] as List<dynamic>?;
            list.add({
              'uid': gymUid,
              'name': d['displayName'] as String? ?? 'Unknown',
              'avatar': d['avatarUrl'] as String?,
              'channels': channelNames?.map((e) => e.toString()).toList() ?? [],
              'members': memberIds?.length ?? 0,
            });
          }
        } catch (_) {}
      }
      if (mounted) setState(() {
        _joinedGyms = list;
        _joinedGymsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _joinedGyms = [];
        _joinedGymsLoading = false;
      });
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _loadFriendsList() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _friends = [];
          _friendsLoading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _friendsLoading = true);
    try {
      final isGymAccount = _isGym == true;

      if (isGymAccount) {
        final members = await getGymMemberProfiles(uid);
        members.sort(
          (a, b) => (a['name'] as String? ?? '')
              .compareTo((b['name'] as String? ?? ''),
          ),
        );
        if (mounted) {
          setState(() {
            _friends = members
                .map((m) => {
                      'uid': m['uid'],
                      'name': m['name'],
                      'avatar': m['avatar'],
                      'mutualFriends': null,
                    })
                .toList();
          });
        }
        return;
      }

      final currentDoc = await FirestoreRefs.userDoc(uid).get();
      final currentData = currentDoc.data() ?? const <String, dynamic>{};

      final rawIds = currentData['friendIds'] as List<dynamic>?;
      final userIds = (rawIds ?? []).whereType<String>().toList();
      if (userIds.isEmpty) {
        if (mounted) setState(() => _friends = []);
        return;
      }

      final currentFriendIdSet = (currentData['friendIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toSet() ??
          <String>{};

      final list = <Map<String, dynamic>>[];
      for (final friendUid in userIds) {
        try {
          final friendDoc = await FirestoreRefs.userDoc(friendUid).get();
          if (!friendDoc.exists || friendDoc.data() == null) continue;
          final d = friendDoc.data()!;
          final friendFriendIds =
              (d['friendIds'] as List<dynamic>?)?.whereType<String>().toList() ??
                  [];
          final mutualCount = friendFriendIds
              .toSet()
              .intersection(currentFriendIdSet)
              .length;

          list.add({
            'uid': friendUid,
            'name': (d['displayName'] as String?) ?? 'Unknown',
            'avatar': d['avatarUrl'] as String?,
            'mutualFriends': isGymAccount ? null : mutualCount,
          });
        } catch (_) {
          // Ignore individual load failures
        }
      }

      list.sort((a, b) =>
          (a['name'] as String).compareTo((b['name'] as String)));

      if (mounted) setState(() => _friends = list);
    } catch (_) {
      if (mounted) setState(() => _friends = []);
    } finally {
      if (mounted) setState(() => _friendsLoading = false);
    }
  }

  Future<void> _loadMessagesList() async {
    if (mounted) setState(() => _messagesLoading = true);
    try {
      if (_joinedGymsLoading || _joinedGyms.isEmpty) {
        if (mounted) setState(() => _messages = []);
        return;
      }

      final items = <Map<String, dynamic>>[];

      for (final gym in _joinedGyms) {
        final gymUid = gym['uid'] as String?;
        if (gymUid == null || gymUid.isEmpty) continue;

        final gymSnap = await FirestoreRefs.channelPosts(gymUid)
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get();

        for (final doc in gymSnap.docs) {
          final data = doc.data();
          final channelName = data['channelName']?.toString() ?? 'general';
          final authorName = data['authorName']?.toString() ?? 'User';
          final content = data['content']?.toString() ?? '';
          final ts = data['createdAt'] as Timestamp?;
          final createdAt =
              ts?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);

          items.add({
            'gymUid': gymUid,
            'channelName': channelName,
            'name': authorName,
            'lastMessage': content,
            'createdAt': createdAt,
            'time': _formatTimeAgo(createdAt),
            'unread': false,
            'avatar': null,
            'isGym': true,
            'postId': doc.id,
          });
        }
      }

      items.sort((a, b) =>
          (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));
      if (mounted) setState(() => _messages = items);
    } catch (_) {
      if (mounted) setState(() => _messages = []);
    } finally {
      if (mounted) setState(() => _messagesLoading = false);
    }
  }

  Future<void> _loadChannels() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (mounted) setState(() => _channelsLoading = true);
    try {
      final list = await getGymChannels(uid);
      if (mounted) setState(() {
        _gymChannels = list;
        _channelsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _gymChannels = [];
        _channelsLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
      return;
    }
    setState(() => _searchLoading = true);
    try {
      final results = await searchUsersAndGyms(
        query: query,
        filter: _searchFilter,
      );
      if (mounted) setState(() {
        _searchResults = results;
        _searchLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _newChannelController.dispose();
    _dmUnreadSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isGym == null) {
      return Scaffold(
        backgroundColor: SocialPage.background,
        body: Column(
          children: [
            const AppHeader(),
            Expanded(
              child: SafeArea(
                top: false,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: SocialPage.background,
      body: Column(
        children: [
          // Header (extends behind status bar)
          const AppHeader(),

          // Tabs + content (respect safe area except top — header owns it)
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  _buildTabs(),

                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: _usesGymTabLayout
                          ? [
                              _buildGymsTab(),
                              _buildFriendsTab(),
                              _buildChannelsTab(),
                              _buildSearchTab(),
                            ]
                          : [
                              _buildGymsTab(),
                              _buildFriendsTab(),
                              _buildSearchTab(),
                            ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: SocialPage.forgeBlue,
        unselectedLabelColor: Colors.grey,
        indicatorColor: SocialPage.forgeBlue,
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        tabs: _usesGymTabLayout
            ? [
                _buildTabWithBadge('Gyms', _gymsUnreadCount),
                _buildTabWithBadge('Members', _friendsUnreadCount),
                const Tab(text: 'Channels'),
                const Tab(text: 'Search'),
              ]
            : [
                _buildTabWithBadge('Gyms', _gymsUnreadCount),
                _buildTabWithBadge('Friends', _friendsUnreadCount),
                const Tab(text: 'Search'),
              ],
      ),
    );
  }

  Tab _buildTabWithBadge(String label, int unread) {
    if (unread <= 0) return Tab(text: label);
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Container(
            constraints: const BoxConstraints(minWidth: 18),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: const BoxDecoration(
              color: SocialPage.forgeBlue,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            child: Text(
              unread > 99 ? '99+' : unread.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesTab() {
    if (_messagesLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'No messages yet',
          style: TextStyle(fontFamily: 'Poppins', color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      itemCount: _messages.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageItem(message);
      },
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> message) {
    return InkWell(
      onTap: () {
        final gymUid = message['gymUid']?.toString();
        final channelName = message['channelName']?.toString();
        if (gymUid == null || gymUid.isEmpty || channelName == null) return;
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => ChannelPage(
              gymUid: gymUid,
              channelName: channelName,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: StorageAvatar(
                    uid: message['gymUid'] as String?,
                    size: 56,
                    borderRadius: BorderRadius.circular(28),
                    placeholder: Icon(
                      message['isGroup'] == true
                          ? Icons.group
                          : message['isGym'] == true
                              ? Icons.fitness_center
                              : Icons.person,
                      color: Colors.grey,
                    ),
                  ),
                ),
                if (message['unread'] == true)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: SocialPage.forgeBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Message content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        message['name'] as String,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: message['unread'] == true
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        message['time'] as String,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: message['unread'] == true
                              ? SocialPage.forgeBlue
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message['lastMessage'] as String,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: message['unread'] == true
                          ? Colors.black87
                          : Colors.black54,
                      fontWeight: message['unread'] == true
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab() {
    return StreamBuilder<List<IncomingFriendRequest>>(
      stream: getIncomingFriendRequestsStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('Incoming friend requests stream error: ${snap.error}');
        }
        final requests = snap.data ?? const <IncomingFriendRequest>[];
        final hasFriends = _friends.isNotEmpty;
        final streamWaitingFirst =
            snap.connectionState == ConnectionState.waiting &&
                snap.data == null;

        // Spinner until we know friend rows and/or first request snapshot.
        // Incoming requests are not blocked by [_friendsLoading] so they show
        // as soon as the stream emits.
        if (requests.isEmpty &&
            !hasFriends &&
            (_friendsLoading || streamWaitingFirst)) {
          return const Center(child: CircularProgressIndicator());
        }
        if (requests.isEmpty && !hasFriends) {
          return Center(
            child: Text(
              _isGym == true ? 'No members yet' : 'No friends yet',
              style: const TextStyle(fontFamily: 'Poppins', color: Colors.grey),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ...requests.map(_buildIncomingFriendRequestTile),
            if (hasFriends)
              ..._friends.map((f) => _buildFriendItem(f)),
          ],
        );
      },
    );
  }

  Widget _buildIncomingFriendRequestTile(IncomingFriendRequest r) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.grey),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.requesterName,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            r.text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              height: 1.35,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: SocialPage.forgeBlue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: r.requesterUid.isEmpty
                  ? null
                  : () => openUserProfileDetailFromUid(
                        context,
                        uid: r.requesterUid,
                      ),
              child: const Text(
                'View profile',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: r.requesterUid.isEmpty
                      ? null
                      : () async {
                          try {
                            await acceptIncomingFriendRequest(
                              requesterUid: r.requesterUid,
                              threadId: r.threadId,
                              messageId: r.messageId,
                            );
                            if (!mounted) return;
                            await _loadFriendsList();
                            if (!mounted) return;
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('You are now friends'),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not accept: $e')),
                            );
                          }
                        },
                  child: const Text(
                    'Accept',
                    style: TextStyle(fontFamily: 'Poppins'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    try {
                      await declineIncomingFriendRequest(
                        threadId: r.threadId,
                        messageId: r.messageId,
                      );
                      if (!mounted) return;
                      setState(() {});
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not decline: $e')),
                      );
                    }
                  },
                  child: const Text(
                    'Decline',
                    style: TextStyle(fontFamily: 'Poppins'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFriendItem(Map<String, dynamic> friend) {
    final friendUid = friend['uid'] as String?;
    final unread = friendUid == null ? 0 : (_dmUnreadByUid[friendUid] ?? 0);
    return InkWell(
      onTap: () {
        _showProfilePage(friend, isGym: false);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: StorageAvatar(
                uid: friendUid,
                size: 56,
                borderRadius: BorderRadius.circular(28),
                placeholder:
                    const Icon(Icons.person, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            // Friend info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          friend['name'] as String,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: SocialPage.forgeBlue,
                            borderRadius: BorderRadius.all(Radius.circular(999)),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : unread.toString(),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    friend['mutualFriends'] is int
                        ? '${friend['mutualFriends']} mutual friends'
                        : 'Member',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            // Message button
            IconButton(
              onPressed: () {
                final uid = friend['uid'] as String?;
                final name = friend['name'] as String? ?? 'Friend';
                if (uid == null || uid.isEmpty) return;
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => DirectMessagePage(
                      friendUid: uid,
                      friendName: name,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.message, color: SocialPage.forgeBlue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGymsTab() {
    if (_joinedGymsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_joinedGyms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fitness_center, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No gyms yet',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Search for a gym and tap to join. It will show up here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: _joinedGyms.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final gym = _joinedGyms[index];
        return _buildGymItem(gym);
      },
    );
  }

  Widget _buildGymItem(Map<String, dynamic> gym) {
    final gymUid = gym['uid'] as String?;
    final unread = gymUid == null ? 0 : (_dmUnreadByUid[gymUid] ?? 0);
    return InkWell(
      onTap: () {
        _showGymCommunityPage(gym);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
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
            // Gym avatar
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: StorageAvatar(
                uid: gymUid,
                size: 64,
                borderRadius: BorderRadius.circular(12),
                placeholder: const Icon(
                  Icons.fitness_center,
                  color: Colors.grey,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Gym info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gym['name'] as String,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${gym['members']} members',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(gym['channels'] as List?)?.length ?? 0} channels',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () {
                    final uid = gym['uid'] as String?;
                    final name = gym['name'] as String? ?? 'Gym';
                    if (uid == null || uid.isEmpty) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => DirectMessagePage(
                          friendUid: uid,
                          friendName: name,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.message, color: SocialPage.forgeBlue),
                ),
                if (unread > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: const BoxDecoration(
                        color: SocialPage.forgeBlue,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : unread.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelsTab() {
    if (_isGym != true) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Channel management is for gym accounts. Sign in as a gym to add and manage your social channels.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        // Add channel button
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _channelsLoading ? null : _showAddChannelDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add channel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: SocialPage.forgeBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _channelsLoading
              ? const Center(child: CircularProgressIndicator())
              : _gymChannels.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No channels yet. Tap "Add channel" to create one (e.g. General, Announcements, Workouts).',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _gymChannels.length,
                      itemBuilder: (context, index) {
                        final name = _gymChannels[index];
                        return _buildChannelItem(name);
                      },
                    ),
        ),
      ],
    );
  }

  void _showAddChannelDialog() {
    _newChannelController.clear();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add channel'),
        content: TextField(
          controller: _newChannelController,
          decoration: const InputDecoration(
            hintText: 'Channel name (e.g. General, Announcements)',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => _submitAddChannel(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => _submitAddChannel(context),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAddChannel(BuildContext dialogContext) async {
    final name = _newChannelController.text.trim();
    if (name.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    Navigator.pop(dialogContext);
    try {
      await addGymChannel(uid, name);
      await _loadChannels();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Channel "$name" added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add channel: $e')),
        );
      }
    }
  }

  void _openChannel(String channelName) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ChannelPage(
          gymUid: uid,
          channelName: channelName,
        ),
      ),
    );
  }

  Widget _buildChannelItem(String channelName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
          Expanded(
            child: InkWell(
              onTap: () => _openChannel(channelName),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.tag, color: SocialPage.forgeBlue, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        channelName,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;
              try {
                await removeGymChannel(uid, channelName);
                await _loadChannels();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Channel "$channelName" removed')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not remove channel: $e')),
                  );
                }
              }
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close, size: 20, color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search for users or gyms...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchLoading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  _buildSearchFilters(),
                ],
              ),
              filled: true,
              fillColor: Colors.grey.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
            ),
          ),
        ),
        // Search results
        Expanded(
          child: _searchLoading && _searchResults.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.trim().isEmpty
                            ? 'Search for users or gyms'
                            : 'No results',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return _buildSearchResultItem(result);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSearchFilters() {
    return PopupMenuButton<SearchFilter>(
      icon: const Icon(Icons.filter_list),
      onSelected: (value) {
        setState(() => _searchFilter = value);
        _runSearch();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: SearchFilter.all,
          child: Text('All'),
        ),
        const PopupMenuItem(
          value: SearchFilter.users,
          child: Text('Users Only'),
        ),
        const PopupMenuItem(
          value: SearchFilter.gyms,
          child: Text('Gyms Only'),
        ),
      ],
    );
  }

  Widget _buildSearchResultItem(Map<String, dynamic> result) {
    final isGym = result['isGym'] == true;
    return InkWell(
      onTap: () {
        _showProfilePage(result, isGym: isGym);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                shape: isGym ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isGym ? BorderRadius.circular(12) : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: StorageAvatar(
                uid: result['uid'] as String?,
                size: 56,
                borderRadius: isGym
                    ? BorderRadius.circular(12)
                    : BorderRadius.circular(28),
                placeholder: Icon(
                  isGym ? Icons.fitness_center : Icons.person,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name
            Expanded(
              child: Text(
                result['name'] as String,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            // Action button
            if (isGym)
              ElevatedButton(
                onPressed: () => _addGym(context, result['uid'] as String?, result['name'] as String?),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SocialPage.forgeBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: const Text(
                  'Join',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              )
            else
              IconButton(
                onPressed: () => _addFriend(context, result['uid'] as String?, result['name'] as String?),
                icon: const Icon(Icons.person_add, color: SocialPage.forgeBlue),
              ),
          ],
        ),
      ),
    );
  }


  Future<void> _addFriend(BuildContext context, String? friendUid, String? friendName) async {
    if (friendUid == null || friendUid.isEmpty) return;
    try {
      await sendFriendRequestDm(friendUid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Friend request sent to ${friendName ?? 'User'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _addGym(BuildContext context, String? gymUid, String? gymName) async {
    if (gymUid == null || gymUid.isEmpty) return;
    try {
      await addGym(gymUid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined ${gymName ?? 'gym'}')),
        );
        await _loadJoinedGyms();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not join gym: $e')),
        );
      }
    }
  }

  void _showProfilePage(Map<String, dynamic> profile, {required bool isGym}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            UserProfileDetailPage(profile: profile, isGym: isGym),
      ),
    );
  }

  void _showGymCommunityPage(Map<String, dynamic> gym) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _GymCommunityPage(gym: gym),
      ),
    );
  }
}

// Gym Community Page
class _GymCommunityPage extends StatefulWidget {
  final Map<String, dynamic> gym;

  const _GymCommunityPage({required this.gym});

  @override
  State<_GymCommunityPage> createState() => _GymCommunityPageState();
}

class _GymCommunityPageState extends State<_GymCommunityPage> {
  String? _selectedChannel;

  List<String> get _channels {
    final raw = widget.gym['channels'] as List?;
    if (raw == null || raw.isEmpty) return [];
    return raw.map((e) => e.toString()).toList();
  }

  void _openChannel(String channelName) {
    final gymUid = widget.gym['uid'] as String?;
    if (gymUid == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ChannelPage(
          gymUid: gymUid,
          channelName: channelName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channels = _channels;
    return Scaffold(
      backgroundColor: SocialPage.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  // Sidebar with channels (like Discord)
                  Container(
                    width: 80,
                    color: const Color(0xFF2C2C2C),
                    child: Column(
                      children: [
                        // Gym logo/name at top
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.fitness_center,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Divider(color: Colors.white24, height: 1),
                        // Channels
                        Expanded(
                          child: channels.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      'No channels',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView(
                                  children: channels.map((channel) {
                                    return GestureDetector(
                                      onTap: () => _openChannel(channel),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        child: Icon(
                                          Icons.tag,
                                          color: Colors.white70,
                                          size: 24,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                      ],
                    ),
                  ),
                  // Main content
                  Expanded(
                    child: Column(
                      children: [
                        // Header with gym name and back button
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.white,
                          child: Row(
                            children: [
                              // Back button
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.arrow_back),
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.fitness_center,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.gym['name'] as String,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '${widget.gym['members']} members',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Prompt and channel list
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 24),
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Tap a channel on the left to view and join the conversation.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                if (channels.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  Text(
                                    'Channels',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...channels.map((channel) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Material(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          child: InkWell(
                                            onTap: () => _openChannel(channel),
                                            borderRadius: BorderRadius.circular(12),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 14),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.tag,
                                                      size: 20,
                                                      color: SocialPage.forgeBlue),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    channel,
                                                    style: const TextStyle(
                                                      fontFamily: 'Poppins',
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w500,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  const Icon(Icons.chevron_right,
                                                      color: Colors.grey),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      )),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
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


  Widget _buildPostCard(Map<String, dynamic> post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post['author'] as String,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      post['time'] as String,
                      style: const TextStyle(
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
          const SizedBox(height: 12),
          Text(
            post['content'] as String,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  // TODO: Like post
                },
                icon: const Icon(Icons.favorite_border, size: 20),
                color: Colors.black54,
              ),
              Text(
                '${post['likes']}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () {
                  // TODO: Comment
                },
                icon: const Icon(Icons.comment_outlined, size: 20),
                color: Colors.black54,
              ),
              Text(
                '${post['comments']}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
