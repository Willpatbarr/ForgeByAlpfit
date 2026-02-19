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
