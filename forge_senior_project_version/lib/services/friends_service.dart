import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/firebase/firestore_refs.dart';

/// Add a friend by UID. Updates the current user's friendIds with [friendUid].
/// No-op if adding self or if already friends. Creates friendIds if missing (existing accounts).
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
