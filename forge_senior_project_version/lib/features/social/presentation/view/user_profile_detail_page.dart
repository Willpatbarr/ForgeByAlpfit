import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/firebase/firestore_refs.dart';
import '../../../../services/direct_messages_service.dart';
import '../../../../services/friends_service.dart';
import '../../../../services/profile_avatar_service.dart';
import 'direct_message_page.dart';

/// Full-screen profile opened from search, friend lists, or friend-request cards.
class UserProfileDetailPage extends StatefulWidget {
  const UserProfileDetailPage({
    super.key,
    required this.profile,
    required this.isGym,
  });

  final Map<String, dynamic> profile;
  final bool isGym;

  static const Color forgeBlue = Color(0xFF4D7CFF);
  static const Color background = Color(0xFFF5F5F7);

  @override
  State<UserProfileDetailPage> createState() => _UserProfileDetailPageState();
}

class _UserProfileDetailPageState extends State<UserProfileDetailPage> {
  bool _loading = true;
  bool _isFriend = false;
  Uint8List? _avatarBytes;
  bool _avatarLoadDone = false;
  String? _avatarDownloadUrl;

  @override
  void initState() {
    super.initState();
    _loadFriendStatus();
    _loadAvatarBytes();
  }

  Future<void> _loadAvatarBytes() async {
    final uid = widget.profile['uid'] as String?;
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _avatarLoadDone = true);
      return;
    }
    final loaded = await loadProfileAvatarFromStorage(uid);
    if (!mounted) return;
    setState(() {
      _avatarBytes = loaded.bytes;
      _avatarDownloadUrl = loaded.downloadUrl;
      _avatarLoadDone = true;
    });
  }

  Future<void> _loadFriendStatus() async {
    final uid = widget.profile['uid'] as String?;
    if (uid == null || uid.isEmpty || widget.isGym) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final f = await areFriendsWith(uid);
    if (mounted) {
      setState(() {
        _isFriend = f;
        _loading = false;
      });
    }
  }

  Widget _buildAvatarPlaceholder() {
    return Icon(
      widget.isGym ? Icons.fitness_center : Icons.person,
      size: 60,
      color: Colors.grey,
    );
  }

  Future<void> _sendFriendRequest(BuildContext context) async {
    final uid = widget.profile['uid'] as String?;
    if (uid == null) return;
    try {
      await sendFriendRequestDm(uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Friend request sent to ${widget.profile['name'] ?? 'User'}',
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

  Widget _buildAvatarContent() {
    if (!_avatarLoadDone) {
      return const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_avatarBytes != null && _avatarBytes!.isNotEmpty) {
      return Image.memory(
        _avatarBytes!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      );
    }
    final url = _avatarDownloadUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        webHtmlElementStrategy:
            kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never,
        errorBuilder: (_, __, ___) => Center(child: _buildAvatarPlaceholder()),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      );
    }
    return Center(child: _buildAvatarPlaceholder());
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.profile['name'] as String? ?? 'User';
    return Scaffold(
      backgroundColor: UserProfileDetailPage.background,
      appBar: AppBar(
        backgroundColor: UserProfileDetailPage.forgeBlue,
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
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                shape: widget.isGym ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: widget.isGym ? BorderRadius.circular(24) : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: ClipRRect(
                borderRadius: widget.isGym
                    ? BorderRadius.circular(24)
                    : BorderRadius.circular(60),
                child: _buildAvatarContent(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (!widget.isGym) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isFriend
                              ? null
                              : () => _sendFriendRequest(context),
                          icon: Icon(
                            _isFriend ? Icons.check : Icons.person_add,
                          ),
                          label: Text(_isFriend ? 'Friends' : 'Add Friend'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: UserProfileDetailPage.forgeBlue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (widget.isGym || _isFriend)
                            ? () {
                                final uid = widget.profile['uid'] as String?;
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
                              }
                            : null,
                        icon: const Icon(Icons.message),
                        label: const Text('Message'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: UserProfileDetailPage.forgeBlue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(
                            color: UserProfileDetailPage.forgeBlue,
                          ),
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

/// Loads a user profile map from Firestore and opens [UserProfileDetailPage].
Future<void> openUserProfileDetailFromUid(
  BuildContext context, {
  required String uid,
}) async {
  try {
    final doc = await FirestoreRefs.userDoc(uid).get();
    final d = doc.data();
    final isGym = (d?['accountType'] as String?)?.toLowerCase() == 'gym';
    if (!context.mounted) return;
    final name = (d?['displayName'] as String?)?.trim().isNotEmpty == true
        ? (d!['displayName'] as String).trim()
        : 'User';
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (ctx) => UserProfileDetailPage(
          profile: {
            'uid': uid,
            'name': name,
            'avatar': d?['avatarUrl'] as String?,
          },
          isGym: isGym,
        ),
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open profile')),
      );
    }
  }
}
