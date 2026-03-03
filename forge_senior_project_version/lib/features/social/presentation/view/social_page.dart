import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../app/app_header.dart';
import '../../../../core/firebase/firestore_refs.dart';
import '../../../../services/friends_service.dart';
import '../../../../services/gyms_service.dart';
import '../../../../services/search_service.dart';
import 'channel_page.dart';

enum SocialTab { messages, friends, gyms, channels, search }

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  static const Color background = Color(0xFFF5F5F7);
  static const Color forgeBlue = Color(0xFF4D7CFF);

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Dummy data
  final List<Map<String, dynamic>> _messages = [
    {
      'name': 'Alex Smith',
      'lastMessage': 'Hey, are we still on for the workout?',
      'time': '2m ago',
      'unread': true,
      'avatar': null,
    },
    {
      'name': 'Jordan Taylor',
      'lastMessage': 'Thanks for the invite!',
      'time': '1h ago',
      'unread': false,
      'avatar': null,
    },
    {
      'name': 'Workout Group',
      'lastMessage': 'Sam: See you all at 9am!',
      'time': '3h ago',
      'unread': true,
      'avatar': null,
      'isGroup': true,
    },
    {
      'name': 'BYU-I Fitness Center',
      'lastMessage': 'New class starting next week!',
      'time': '1d ago',
      'unread': false,
      'avatar': null,
      'isGym': true,
    },
  ];

  final List<Map<String, dynamic>> _friends = [
    {'name': 'Alex Smith', 'avatar': null, 'mutualFriends': 5},
    {'name': 'Jordan Taylor', 'avatar': null, 'mutualFriends': 3},
    {'name': 'Sam Johnson', 'avatar': null, 'mutualFriends': 8},
    {'name': 'Riley Brown', 'avatar': null, 'mutualFriends': 2},
    {'name': 'Taylor Davis', 'avatar': null, 'mutualFriends': 4},
  ];

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadAccountTypeAndChannels();
  }

  Future<void> _loadAccountTypeAndChannels() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isGym = false);
      return;
    }
    try {
      final doc = await FirestoreRefs.userDoc(uid).get();
      final accountType = doc.data()?['accountType'] as String?;
      final isGym = accountType == 'gym';
      if (mounted) setState(() => _isGym = isGym);
      if (isGym) await _loadChannels();
    } catch (_) {
      if (mounted) setState(() => _isGym = false);
    }
    await _loadJoinedGyms();
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
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SocialPage.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            const AppHeader(),

            // Tabs
            _buildTabs(),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMessagesTab(),
                  _buildFriendsTab(),
                  _buildGymsTab(),
                  _buildChannelsTab(),
                  _buildSearchTab(),
                ],
              ),
            ),
          ],
        ),
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
        tabs: const [
          Tab(text: 'Messages'),
          Tab(text: 'Friends'),
          Tab(text: 'Gyms'),
          Tab(text: 'Channels'),
          Tab(text: 'Search'),
        ],
      ),
    );
  }

  Widget _buildMessagesTab() {
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
        // TODO: Navigate to chat
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
                  child: message['avatar'] != null
                      ? ClipOval(
                          child: Image.network(
                            message['avatar'] as String,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          message['isGroup'] == true
                              ? Icons.group
                              : message['isGym'] == true
                                  ? Icons.fitness_center
                                  : Icons.person,
                          color: Colors.grey,
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
    return ListView.builder(
      itemCount: _friends.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final friend = _friends[index];
        return _buildFriendItem(friend);
      },
    );
  }

  Widget _buildFriendItem(Map<String, dynamic> friend) {
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
              child: friend['avatar'] != null
                  ? ClipOval(
                      child: Image.network(
                        friend['avatar'] as String,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      color: Colors.grey,
                    ),
            ),
            const SizedBox(width: 12),
            // Friend info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend['name'] as String,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${friend['mutualFriends']} mutual friends',
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
                // TODO: Navigate to chat
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
              child: gym['avatar'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        gym['avatar'] as String,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(
                      Icons.fitness_center,
                      color: Colors.grey,
                      size: 32,
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
              child: result['avatar'] != null
                  ? ClipRRect(
                      borderRadius: isGym
                          ? BorderRadius.circular(12)
                          : BorderRadius.circular(28),
                      child: Image.network(
                        result['avatar'] as String,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(
                      isGym ? Icons.fitness_center : Icons.person,
                      color: Colors.grey,
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
      await addFriend(friendUid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${friendName ?? 'User'} added as friend')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add friend: $e')),
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
        builder: (context) => _ProfileViewPage(profile: profile, isGym: isGym),
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

// Profile View Page
class _ProfileViewPage extends StatelessWidget {
  final Map<String, dynamic> profile;
  final bool isGym;

  const _ProfileViewPage({
    required this.profile,
    required this.isGym,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SocialPage.background,
      appBar: AppBar(
        backgroundColor: SocialPage.forgeBlue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Avatar
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                shape: isGym ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isGym ? BorderRadius.circular(24) : null,
              ),
              child: profile['avatar'] != null
                  ? ClipRRect(
                      borderRadius: isGym
                          ? BorderRadius.circular(24)
                          : BorderRadius.circular(60),
                      child: Image.network(
                        profile['avatar'] as String,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(
                      isGym ? Icons.fitness_center : Icons.person,
                      size: 60,
                      color: Colors.grey,
                    ),
            ),
            const SizedBox(height: 16),
            // Name
            Text(
              profile['name'] as String,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (!isGym) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uid = profile['uid'] as String?;
                          if (uid == null) return;
                          try {
                            await addFriend(uid);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${profile['name'] ?? 'User'} added as friend')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Could not add friend: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add Friend'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SocialPage.forgeBlue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Message
                      },
                      icon: const Icon(Icons.message),
                      label: const Text('Message'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: SocialPage.forgeBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: SocialPage.forgeBlue),
                      ),
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
