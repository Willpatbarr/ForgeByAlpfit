import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/firebase/firestore_refs.dart';

/// Add a gym by UID to the current user's joined gyms.
Future<void> addGym(String gymUid) async {
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUid == null) throw Exception('Not signed in');

  final ref = FirestoreRefs.userDoc(currentUid);
  await ref.set({
    'joinedGymIds': FieldValue.arrayUnion([gymUid]),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

/// Remove a gym by UID from the current user's joined gyms.
Future<void> removeGym(String gymUid) async {
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUid == null) throw Exception('Not signed in');

  final ref = FirestoreRefs.userDoc(currentUid);
  await ref.set({
    'joinedGymIds': FieldValue.arrayRemove([gymUid]),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
