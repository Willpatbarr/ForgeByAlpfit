import 'package:flutter/material.dart';

enum SocialTab { messages, friends, gyms, search }

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

  final List<Map<String, dynamic>> _joinedGyms = [
    {
      'name': 'BYU-I Fitness Center',
      'avatar': null,
      'members': 1250,
      'channels': ['General', 'Announcements', 'Workouts'],
    },
    {
      'name': 'Rexburg Gym',
      'avatar': null,
      'members': 450,
      'channels': ['General', 'Events'],
    },
  ];

  final List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
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
            _buildHeader(),

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
                  _buildSearchTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: SocialPage.forgeBlue,
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
                    '${(gym['channels'] as List).length} channels',
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

  Widget _buildSearchTab() {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search for users or gyms...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _buildSearchFilters(),
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
            onChanged: (value) {
              // TODO: Implement search
            },
          ),
        ),
        // Search results
        Expanded(
          child: _searchResults.isEmpty
              ? const Center(
                  child: Text(
                    'Search for users or gyms',
                    style: TextStyle(
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
    return PopupMenuButton<String>(
      icon: const Icon(Icons.filter_list),
      onSelected: (value) {
        // TODO: Implement filter
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'all',
          child: Text('All'),
        ),
        const PopupMenuItem(
          value: 'users',
          child: Text('Users Only'),
        ),
        const PopupMenuItem(
          value: 'gyms',
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
                onPressed: () {
                  // TODO: Join gym or view community
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: SocialPage.forgeBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: const Text(
                  'View',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              )
            else
              IconButton(
                onPressed: () {
                  // TODO: Add friend
                },
                icon: const Icon(Icons.person_add, color: SocialPage.forgeBlue),
              ),
          ],
        ),
      ),
    );
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
                        onPressed: () {
                          // TODO: Add friend or message
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
  String _selectedChannel = 'General';

  // Dummy posts
  final List<Map<String, dynamic>> _posts = [
    {
      'author': 'BYU-I Fitness Center',
      'content': 'New yoga class starting next week! Sign up now.',
      'time': '2h ago',
      'likes': 45,
      'comments': 12,
    },
    {
      'author': 'BYU-I Fitness Center',
      'content': 'Reminder: Pool maintenance this weekend. Pool will be closed Saturday.',
      'time': '1d ago',
      'likes': 23,
      'comments': 5,
    },
  ];

  @override
  Widget build(BuildContext context) {
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
                          child: ListView(
                            children: (widget.gym['channels'] as List<String>).map((channel) {
                              final isSelected = channel == _selectedChannel;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedChannel = channel;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  color: isSelected
                                      ? SocialPage.forgeBlue.withValues(alpha: 0.3)
                                      : Colors.transparent,
                                  child: Icon(
                                    Icons.tag,
                                    color: isSelected ? Colors.white : Colors.white70,
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
                        // Channel name
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: Colors.white,
                          child: Row(
                            children: [
                              const Icon(Icons.tag, size: 16, color: Colors.black54),
                              const SizedBox(width: 8),
                              Text(
                                _selectedChannel,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Feed
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _posts.length,
                            itemBuilder: (context, index) {
                              final post = _posts[index];
                              return _buildPostCard(post);
                            },
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
