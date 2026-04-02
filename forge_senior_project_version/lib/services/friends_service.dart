import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/firebase/firestore_refs.dart';

/// Whether the current user and [otherUid] are friends (either has the other in `friendIds`).
Future<bool> areFriendsWith(String otherUid) async {
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUid == null || otherUid.isEmpty || otherUid == currentUid) {
    return false;
  }
  final doc = await FirestoreRefs.userDoc(currentUid).get();
  final friendIds = (doc.data()?['friendIds'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toSet() ??
      <String>{};
  return friendIds.contains(otherUid);
}

/// Adds each user to the other's `friendIds` (used when accepting a friend request).
/// [accepterUid] must be the signed-in user.
Future<void> acceptFriendBidirectional({
  required String requesterUid,
}) async {
  final accepterUid = FirebaseAuth.instance.currentUser?.uid;
  if (accepterUid == null) throw Exception('Not signed in');
  if (requesterUid.isEmpty || requesterUid == accepterUid) {
    throw Exception('Invalid user');
  }

  final batch = FirebaseFirestore.instance.batch();
  batch.set(
    FirestoreRefs.userDoc(accepterUid),
    {
      'friendIds': FieldValue.arrayUnion([requesterUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );
  batch.set(
    FirestoreRefs.userDoc(requesterUid),
    {
      'friendIds': FieldValue.arrayUnion([accepterUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );
  await batch.commit();
}

/// Add a friend by UID. Updates the current user's friendIds with [friendUid].
/// No-op if adding self or if already friends. Creates friendIds if missing (existing accounts).
///
/// Prefer [sendFriendRequestDm] + accept flow for UX; this is kept for legacy call sites.
Future<void> addFriend(String friendUid) async {
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUid == null) throw Exception('Not signed in');
  if (friendUid == currentUid) return;

  final ref = FirestoreRefs.userDoc(currentUid);
  await ref.set({
    'friendIds': FieldValue.arrayUnion([friendUid]),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

/// Remove a friend by UID from the current user's friendIds.
Future<void> removeFriend(String friendUid) async {
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUid == null) throw Exception('Not signed in');

  final ref = FirestoreRefs.userDoc(currentUid);
  await ref.set({
    'friendIds': FieldValue.arrayRemove([friendUid]),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

/// Returns list of {uid, name} for each friend of the current user.
Future<List<Map<String, String>>> getFriendIdsWithNames() async {
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUid == null) return [];

  final doc = await FirestoreRefs.userDoc(currentUid).get();
  final friendIds = doc.data()?['friendIds'] as List<dynamic>?;
  if (friendIds == null || friendIds.isEmpty) return [];

  final list = <Map<String, String>>[];
  for (final id in friendIds) {
    final friendUid = id is String ? id : id.toString();
    if (friendUid.isEmpty) continue;
    try {
      final friendDoc = await FirestoreRefs.userDoc(friendUid).get();
      final data = friendDoc.data();
      if (friendDoc.exists && data != null) {
        list.add({
          'uid': friendUid,
          'name': (data['displayName'] as String?) ?? 'Unknown',
        });
      } else {
        list.add({'uid': friendUid, 'name': 'Unknown'});
      }
    } catch (_) {
      list.add({'uid': friendUid, 'name': 'Unknown'});
    }
  }
  return list;
}
