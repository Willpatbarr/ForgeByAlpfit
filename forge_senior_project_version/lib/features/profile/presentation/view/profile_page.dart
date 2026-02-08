import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  static const Color background = Color(0xFFF5F5F7);
  static const Color forgeBlue = Color(0xFF4D7CFF);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // User profile data
  String _userName = 'John Doe';
  String? _contactInfo;
  bool _isEditingProfile = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  // Dummy friends list
  final List<Map<String, dynamic>> _friends = [
    {'name': 'Alex Smith', 'avatar': null},
    {'name': 'Jordan Taylor', 'avatar': null},
    {'name': 'Sam Johnson', 'avatar': null},
    {'name': 'Riley Brown', 'avatar': null},
    {'name': 'Taylor Davis', 'avatar': null},
  ];

  // Dummy gym communities
  final List<Map<String, dynamic>> _joinedGyms = [
    {'name': 'BYU-I Fitness Center', 'avatar': null},
    {'name': 'Rexburg Gym', 'avatar': null},
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = _userName;
    _contactController.text = _contactInfo ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfilePage.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // Profile section
                    _buildProfileSection(),
                    const SizedBox(height: 24),
                    // Friends section
                    _buildFriendsSection(),
                    const SizedBox(height: 24),
                    // Gym communities section
                    _buildGymCommunitiesSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: ProfilePage.forgeBlue,
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

  Widget _buildProfileSection() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: ProfilePage.forgeBlue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Profile',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (_isEditingProfile) {
                      // Save changes
                      setState(() {
                        _userName = _nameController.text;
                        _contactInfo = _contactController.text.isEmpty
                            ? null
                            : _contactController.text;
                        _isEditingProfile = false;
                      });
                    } else {
                      // Start editing
                      setState(() {
                        _isEditingProfile = true;
                      });
                    }
                  },
                  child: Icon(
                    _isEditingProfile ? Icons.check : Icons.edit,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Profile photo
                GestureDetector(
                  onTap: _isEditingProfile ? _changeProfilePhoto : null,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.grey,
                        ),
                      ),
                      if (_isEditingProfile)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: ProfilePage.forgeBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Name field
                _buildEditableField(
                  label: 'Name',
                  controller: _nameController,
                  enabled: _isEditingProfile,
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),

                // Contact info field
                _buildEditableField(
                  label: 'Contact Info (Optional)',
                  controller: _contactController,
                  enabled: _isEditingProfile,
                  icon: Icons.phone_outlined,
                  isOptional: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    required IconData icon,
    bool isOptional = false,
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
          enabled: enabled,
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled
                ? Colors.white
                : Colors.grey.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: enabled
                    ? ProfilePage.forgeBlue
                    : Colors.transparent,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: enabled
                    ? ProfilePage.forgeBlue
                    : Colors.transparent,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: ProfilePage.forgeBlue,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            hintText: isOptional ? 'Optional' : '',
            hintStyle: TextStyle(
              color: Colors.grey.withValues(alpha: 0.5),
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

  Widget _buildFriendsSection() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: ProfilePage.forgeBlue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Friends',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${_friends.length}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Friends list
          Padding(
            padding: const EdgeInsets.all(16),
            child: _friends.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No friends yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  )
                : Column(
                    children: _friends.map((friend) {
                      return _buildFriendItem(friend);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendItem(Map<String, dynamic> friend) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
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
          // Name
          Expanded(
            child: Text(
              friend['name'] as String,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          // Remove button
          GestureDetector(
            onTap: () {
              setState(() {
                _friends.remove(friend);
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close,
                size: 18,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGymCommunitiesSection() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: ProfilePage.forgeBlue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Joined Gym Communities',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${_joinedGyms.length}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Gyms list
          Padding(
            padding: const EdgeInsets.all(16),
            child: _joinedGyms.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No gym communities joined yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  )
                : Column(
                    children: _joinedGyms.map((gym) {
                      return _buildGymItem(gym);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGymItem(Map<String, dynamic> gym) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
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
                  ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              gym['name'] as String,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          // Leave button
          GestureDetector(
            onTap: () {
              setState(() {
                _joinedGyms.remove(gym);
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.exit_to_app,
                size: 18,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _changeProfilePhoto() {
    // TODO: Implement photo picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Photo picker coming soon'),
      ),
    );
  }
}
