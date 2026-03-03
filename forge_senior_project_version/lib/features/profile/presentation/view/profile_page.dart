import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/app_header.dart';
import '../../../../app/auth_state.dart';
import '../../../../core/firebase/firestore_refs.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/friends_service.dart';
import '../../../../services/gyms_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  static const Color background = Color(0xFFF5F5F7);
  static const Color forgeBlue = Color(0xFF4D7CFF);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // User profile data (loaded from Firestore)
  String _userName = '';
  String? _contactInfo;
  bool _isEditingProfile = false;
  bool _profileLoading = true;
  String? _loadError;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  // Friends list loaded from Firestore (current user's friendIds → friend profiles)
  List<Map<String, dynamic>> _friends = [];

  // Joined gyms loaded from Firestore (current user's joinedGymIds → gym profiles)
  List<Map<String, dynamic>> _joinedGyms = [];

  // For gym accounts: whether current user is a gym, and list of members (users who added this gym)
  String? _accountType;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _profileLoading = false;
        _userName = 'Guest';
      });
      _nameController.text = _userName;
      return;
    }
    try {
      final doc = await FirestoreRefs.userDoc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final name = data['displayName'] as String? ?? user.displayName ?? user.email ?? 'User';
        final contact = data['contactInfo'] as String?;
        final accountType = data['accountType'] as String?;
        setState(() {
          _userName = name;
          _contactInfo = contact;
          _accountType = accountType;
          _profileLoading = false;
        });
        _nameController.text = _userName;
        _contactController.text = contact ?? '';
        await _loadFriends(data['friendIds'] as List<dynamic>?);
        if (accountType == 'gym') {
          await _loadMembers();
        } else {
          await _loadGyms(data['joinedGymIds'] as List<dynamic>?);
        }
      } else {
        setState(() {
          _userName = user.displayName ?? user.email ?? 'User';
          _accountType = null;
          _profileLoading = false;
        });
        _nameController.text = _userName;
        _contactController.text = _contactInfo ?? '';
        await _loadFriends(null);
        await _loadGyms(null);
      }
    } catch (e) {
      setState(() {
        _loadError = e.toString();
        _userName = user.displayName ?? user.email ?? 'User';
        _accountType = null;
        _profileLoading = false;
      });
      _nameController.text = _userName;
      await _loadFriends(null);
      await _loadGyms(null);
    }
  }

  Future<void> _loadFriends(List<dynamic>? friendIds) async {
    if (friendIds == null || friendIds.isEmpty) {
      setState(() => _friends = []);
      return;
    }
    final list = <Map<String, dynamic>>[];
    for (final id in friendIds) {
      final uid = id is String ? id : id.toString();
      if (uid.isEmpty) continue;
      try {
        final doc = await FirestoreRefs.userDoc(uid).get();
        if (doc.exists && doc.data() != null) {
          final d = doc.data()!;
          list.add({
            'uid': uid,
            'name': d['displayName'] as String? ?? 'Unknown',
            'avatar': d['avatarUrl'] as String?,
          });
        }
      } catch (_) {}
    }
    setState(() => _friends = list);
  }

  Future<void> _loadGyms(List<dynamic>? joinedGymIds) async {
    if (joinedGymIds == null || joinedGymIds.isEmpty) {
      setState(() => _joinedGyms = []);
      return;
    }
    final list = <Map<String, dynamic>>[];
    for (final id in joinedGymIds) {
      final uid = id is String ? id : id.toString();
      if (uid.isEmpty) continue;
      try {
        final doc = await FirestoreRefs.userDoc(uid).get();
        if (doc.exists && doc.data() != null) {
          final d = doc.data()!;
          list.add({
            'uid': uid,
            'name': d['displayName'] as String? ?? 'Unknown',
            'avatar': d['avatarUrl'] as String?,
          });
        }
      } catch (_) {}
    }
    setState(() => _joinedGyms = list);
  }

  Future<void> _loadMembers() async {
    final gymUid = FirebaseAuth.instance.currentUser?.uid;
    if (gymUid == null) {
      setState(() => _members = []);
      return;
    }
    try {
      final list = await getGymMemberProfiles(gymUid);
      setState(() => _members = list);
    } catch (_) {
      setState(() => _members = []);
    }
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    AuthStateNotifier.instance.notifyListeners();
    if (mounted) context.go('/login');
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
            const AppHeader(),

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
                    // For gyms: Members (users who added this gym). For regular users: Joined gym communities.
                    if (_accountType == 'gym')
                      _buildMembersSection()
                    else
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
                  onTap: () async {
                    if (_isEditingProfile) {
                      final name = _nameController.text.trim();
                      final contact = _contactController.text.trim();
                      setState(() {
                        _userName = name.isEmpty ? _userName : name;
                        _contactInfo = contact.isEmpty ? null : contact;
                        _isEditingProfile = false;
                      });
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid != null) {
                        try {
                          await FirestoreRefs.userDoc(uid).set({
                            'displayName': _userName,
                            'displayNameLower': _userName.toLowerCase(),
                            'contactInfo': _contactInfo,
                            'updatedAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));
                        } catch (_) {}
                      }
                    } else {
                      setState(() => _isEditingProfile = true);
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
            child: _profileLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
              children: [
                if (_loadError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Could not load profile',
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  ),
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
                // Log out button
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text('Log out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
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
            onTap: () async {
              final uid = friend['uid'] as String?;
              if (uid == null) return;
              try {
                await removeFriend(uid);
                final currentUid = FirebaseAuth.instance.currentUser?.uid;
                List<dynamic>? ids;
                if (currentUid != null) {
                  final doc = await FirestoreRefs.userDoc(currentUid).get();
                  ids = doc.data()?['friendIds'] as List<dynamic>?;
                }
                await _loadFriends(ids);
              } catch (_) {}
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

  Widget _buildMembersSection() {
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
                  'Members',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${_members.length}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _members.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No members yet. Users who add your gym will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  )
                : Column(
                    children: _members.map((member) => _buildMemberItem(member)).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberItem(Map<String, dynamic> member) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: member['avatar'] != null
                ? ClipOval(
                    child: Image.network(
                      member['avatar'] as String,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(
                    Icons.person,
                    color: Colors.grey,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              member['name'] as String,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              final uid = member['uid'] as String?;
              if (uid == null) return;
              try {
                await removeMemberFromGym(uid);
                await _loadMembers();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${member['name'] ?? 'Member'} removed')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not remove member: $e')),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person_remove,
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
            onTap: () async {
              final uid = gym['uid'] as String?;
              if (uid == null) return;
              try {
                await removeGym(uid);
                final currentUid = FirebaseAuth.instance.currentUser?.uid;
                List<dynamic>? ids;
                if (currentUid != null) {
                  final doc = await FirestoreRefs.userDoc(currentUid).get();
                  ids = doc.data()?['joinedGymIds'] as List<dynamic>?;
                }
                await _loadGyms(ids);
              } catch (_) {}
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
