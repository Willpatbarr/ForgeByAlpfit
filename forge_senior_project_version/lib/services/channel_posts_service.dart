import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/firebase/firestore_refs.dart';

/// Post map: id, channelName, authorUid, authorName, content, createdAt, likeIds (List).
/// Comment map: id, authorUid, authorName, content, createdAt.

Stream<List<Map<String, dynamic>>> getChannelPostsStream(
    String gymUid, String channelName) {
  return FirestoreRefs.channelPosts(gymUid)
      .where('channelName', isEqualTo: channelName)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => {
                'id': d.id,
                ...?d.data(),
                'createdAt': d.data()['createdAt'],
              })
          .toList());
}

Future<void> createPost(String gymUid, String channelName, String content) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not signed in');
  final trimmed = content.trim();
  if (trimmed.isEmpty) throw Exception('Post content cannot be empty');

  String authorName = user.displayName ?? user.email ?? 'User';
  try {
    final doc = await FirestoreRefs.userDoc(user.uid).get();
    final d = doc.data();
    if (d != null && d['displayName'] != null) {
      authorName = d['displayName'] as String;
    }
  } catch (_) {}

  await FirestoreRefs.channelPosts(gymUid).add({
    'channelName': channelName,
    'authorUid': user.uid,
    'authorName': authorName,
    'content': trimmed,
    'createdAt': FieldValue.serverTimestamp(),
    'likeIds': <String>[],
  });
}

Future<void> togglePostLike(String gymUid, String postId) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw Exception('Not signed in');

  final ref = FirestoreRefs.channelPostDoc(gymUid, postId);
  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(ref);
    final likeIds = List<String>.from(
        (snap.data()?['likeIds'] as List<dynamic>?)?.map((e) => e.toString()) ?? []);
    if (likeIds.contains(uid)) {
      likeIds.remove(uid);
    } else {
      likeIds.add(uid);
    }
    tx.update(ref, {'likeIds': likeIds});
  });
}

Stream<List<Map<String, dynamic>>> getCommentsStream(
    String gymUid, String postId) {
  return FirestoreRefs.postComments(gymUid, postId)
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => {'id': d.id, ...?d.data(), 'createdAt': d.data()['createdAt']})
          .toList());
}

Future<void> addComment(String gymUid, String postId, String content) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Not signed in');
  final trimmed = content.trim();
  if (trimmed.isEmpty) throw Exception('Comment cannot be empty');

  String authorName = user.displayName ?? user.email ?? 'User';
  try {
    final doc = await FirestoreRefs.userDoc(user.uid).get();
    final d = doc.data();
    if (d != null && d['displayName'] != null) {
      authorName = d['displayName'] as String;
    }
  } catch (_) {}

  await FirestoreRefs.postComments(gymUid, postId).add({
    'authorUid': user.uid,
    'authorName': authorName,
    'content': trimmed,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> deletePost(String gymUid, String postId) async {
  final ref = FirestoreRefs.channelPostDoc(gymUid, postId);
  final commentsRef = FirestoreRefs.postComments(gymUid, postId);
  final commentsSnap = await commentsRef.get();
  final batch = FirebaseFirestore.instance.batch();
  for (final doc in commentsSnap.docs) {
    batch.delete(doc.reference);
  }
  batch.delete(ref);
  await batch.commit();
}

Future<void> deleteComment(
    String gymUid, String postId, String commentId) async {
  await FirestoreRefs.postComments(gymUid, postId).doc(commentId).delete();
}

/// Returns true if current user is the gym owner (can delete any post/comment).
bool isCurrentUserGymOwner(String gymUid) {
  return FirebaseAuth.instance.currentUser?.uid == gymUid;
}
