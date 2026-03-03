import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../services/channel_posts_service.dart';

class ChannelPage extends StatefulWidget {
  final String gymUid;
  final String channelName;

  const ChannelPage({
    super.key,
    required this.gymUid,
    required this.channelName,
  });

  static const Color forgeBlue = Color(0xFF4D7CFF);

  @override
  State<ChannelPage> createState() => _ChannelPageState();
}

class _ChannelPageState extends State<ChannelPage> {
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final Map<String, bool> _expandedComments = {};

  bool get _isGymOwner =>
      isCurrentUserGymOwner(widget.gymUid);

  /// Extracts the Firebase Console index-creation URL from a Firestore error string.
  static String? _extractIndexUrl(String errorMessage) {
    const prefix = 'https://';
    final i = errorMessage.indexOf(prefix);
    if (i == -1) return null;
    final rest = errorMessage.substring(i);
    final end = rest.indexOf(RegExp(r'\s'));
    return end == -1 ? rest : rest.substring(0, end);
  }

  @override
  void dispose() {
    _postController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _showNewPostDialog() {
    _postController.clear();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Post in #${widget.channelName}'),
        content: TextField(
          controller: _postController,
          decoration: const InputDecoration(
            hintText: 'What\'s on your mind?',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _submitPost(ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => _submitPost(ctx),
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPost(BuildContext dialogContext) async {
    final content = _postController.text.trim();
    if (content.isEmpty) return;
    Navigator.pop(dialogContext);
    try {
      await createPost(widget.gymUid, widget.channelName, content);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post published')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not post: $e')),
        );
      }
    }
  }

  void _showCommentSheet(String postId) {
    _commentController.clear();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
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
            const Text(
              'Add a comment',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Write a comment...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _submitComment(ctx, postId),
              style: FilledButton.styleFrom(
                backgroundColor: ChannelPage.forgeBlue,
              ),
              child: const Text('Post comment'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitComment(BuildContext sheetContext, String postId) async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    Navigator.pop(sheetContext);
    try {
      await addComment(widget.gymUid, postId, content);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add comment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.tag, color: ChannelPage.forgeBlue, size: 22),
            const SizedBox(width: 8),
            Text(
              '#${widget.channelName}',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showNewPostDialog,
            tooltip: 'New post',
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: getChannelPostsStream(widget.gymUid, widget.channelName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final err = snapshot.error.toString();
            final indexUrl = _extractIndexUrl(err);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.orange.shade700),
                    const SizedBox(height: 16),
                    Text(
                      'This channel needs a Firestore index.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      indexUrl != null
                          ? 'Copy the link below, paste it in your browser, then tap Create to add the index. Wait 1–2 minutes and open this channel again.'
                          : 'Run in terminal: firebase login --reauth then firebase deploy --only firestore:indexes (from your project folder).',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (indexUrl != null)
                      FilledButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: indexUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copied. Paste it in your browser.')),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy link'),
                        style: FilledButton.styleFrom(
                          backgroundColor: ChannelPage.forgeBlue,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }
          final posts = snapshot.data ?? [];
          if (posts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No posts yet in #${widget.channelName}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _showNewPostDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Create first post'),
                      style: FilledButton.styleFrom(
                        backgroundColor: ChannelPage.forgeBlue,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              return _PostCard(
                gymUid: widget.gymUid,
                post: posts[index],
                currentUserUid: currentUid,
                isGymOwner: _isGymOwner,
                onLike: () => togglePostLike(widget.gymUid, posts[index]['id'] as String),
                onComment: () => _showCommentSheet(posts[index]['id'] as String),
                onDeletePost: () async {
                  await deletePost(widget.gymUid, posts[index]['id'] as String);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post deleted')),
                    );
                  }
                },
                onDeleteComment: (commentId) async {
                  await deleteComment(
                      widget.gymUid, posts[index]['id'] as String, commentId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Comment deleted')),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final String gymUid;
  final Map<String, dynamic> post;
  final String currentUserUid;
  final bool isGymOwner;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onDeletePost;
  final void Function(String commentId) onDeleteComment;

  const _PostCard({
    required this.gymUid,
    required this.post,
    required this.currentUserUid,
    required this.isGymOwner,
    required this.onLike,
    required this.onComment,
    required this.onDeletePost,
    required this.onDeleteComment,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _commentsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final postId = widget.post['id'] as String? ?? '';
    final authorName = widget.post['authorName'] as String? ?? 'Unknown';
    final content = widget.post['content'] as String? ?? '';
    final createdAt = widget.post['createdAt'] as Timestamp?;
    final likeIds = (widget.post['likeIds'] as List<dynamic>?)?.cast<String>() ?? [];
    final isLiked = widget.currentUserUid.isNotEmpty && likeIds.contains(widget.currentUserUid);

    String timeStr = '';
    if (createdAt != null) {
      final d = createdAt.toDate();
      final now = DateTime.now();
      if (now.difference(d).inDays > 0) {
        timeStr = '${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
      } else {
        timeStr = '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: ChannelPage.forgeBlue.withValues(alpha: 0.2),
                      child: Text(
                        (authorName.isNotEmpty ? authorName[0] : '?')
                            .toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: ChannelPage.forgeBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authorName,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          if (timeStr.isNotEmpty)
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.isGymOwner)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: Colors.red,
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete post?'),
                              content: const Text(
                                  'This post and all its comments will be removed.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) widget.onDeletePost();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  content,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _LikeButton(
                      likeIds: likeIds,
                      isLiked: isLiked,
                      onTap: widget.onLike,
                    ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: widget.onComment,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 20, color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          StreamBuilder<List<Map<String, dynamic>>>(
                            stream: getCommentsStream(widget.gymUid, postId),
                            builder: (context, snap) {
                              final count = snap.data?.length ?? 0;
                              return Text(
                                '$count',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() => _commentsExpanded = !_commentsExpanded);
                      },
                      child: Text(
                        _commentsExpanded ? 'Hide comments' : 'Comments',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: ChannelPage.forgeBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_commentsExpanded)
            _CommentsSection(
              gymUid: widget.gymUid,
              postId: postId,
              isGymOwner: widget.isGymOwner,
              onAddComment: widget.onComment,
              onDeleteComment: widget.onDeleteComment,
            ),
        ],
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  final List<String> likeIds;
  final bool isLiked;
  final VoidCallback onTap;

  const _LikeButton({
    required this.likeIds,
    required this.isLiked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            size: 22,
            color: isLiked ? Colors.red : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            '${likeIds.length}',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsSection extends StatelessWidget {
  final String gymUid;
  final String postId;
  final bool isGymOwner;
  final VoidCallback onAddComment;
  final void Function(String commentId) onDeleteComment;

  const _CommentsSection({
    required this.gymUid,
    required this.postId,
    required this.isGymOwner,
    required this.onAddComment,
    required this.onDeleteComment,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: getCommentsStream(gymUid, postId),
      builder: (context, snapshot) {
        final comments = snapshot.data ?? [];
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 1),
              const SizedBox(height: 12),
              if (comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No comments yet.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                )
              else
                ...comments.map((c) => _CommentTile(
                      comment: c,
                      isGymOwner: isGymOwner,
                      onDelete: () => onDeleteComment(c['id'] as String),
                    )),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onAddComment,
                icon: const Icon(Icons.add_comment, size: 18),
                label: const Text('Add a comment'),
                style: TextButton.styleFrom(
                  foregroundColor: ChannelPage.forgeBlue,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final bool isGymOwner;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    required this.isGymOwner,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final authorName = comment['authorName'] as String? ?? 'Unknown';
    final content = comment['content'] as String? ?? '';
    final createdAt = comment['createdAt'] as Timestamp?;
    String timeStr = '';
    if (createdAt != null) {
      final d = createdAt.toDate();
      timeStr = '${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: ChannelPage.forgeBlue.withValues(alpha: 0.2),
            child: Text(
              (authorName.isNotEmpty ? authorName[0] : '?').toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ChannelPage.forgeBlue,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      authorName,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (isGymOwner)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: Colors.red,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete comment?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) onDelete();
              },
            ),
        ],
      ),
    );
  }
}
