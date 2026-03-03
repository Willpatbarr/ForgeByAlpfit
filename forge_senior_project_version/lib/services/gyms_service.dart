import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/firebase/firestore_refs.dart';

/// Add a gym by UID to the current user's joined gyms.
/// Also adds the current user to the gym's memberUserIds so the gym can see them in Members.
Future<void> addGym(String gymUid) async {
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUid == null) throw Exception('Not signed in');

  final userRef = FirestoreRefs.userDoc(currentUid);
  final gymRef = FirestoreRefs.userDoc(gymUid);

  await FirebaseFirestore.instance.runTransaction((tx) async {
    tx.set(userRef, {
      'joinedGymIds': FieldValue.arrayUnion([gymUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    tx.set(gymRef, {
      'memberUserIds': FieldValue.arrayUnion([currentUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });
}

/// Remove a gym by UID from the current user's joined gyms.
/// Also removes the current user from the gym's memberUserIds.
Future<void> removeGym(String gymUid) async {
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUid == null) throw Exception('Not signed in');

  final userRef = FirestoreRefs.userDoc(currentUid);
  final gymRef = FirestoreRefs.userDoc(gymUid);

  await FirebaseFirestore.instance.runTransaction((tx) async {
    tx.set(userRef, {
      'joinedGymIds': FieldValue.arrayRemove([gymUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    tx.set(gymRef, {
      'memberUserIds': FieldValue.arrayRemove([currentUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });
}

/// Returns profile maps (uid, name, avatar) for all users who have added this gym (members).
Future<List<Map<String, dynamic>>> getGymMemberProfiles(String gymUid) async {
  final gymDoc = await FirestoreRefs.userDoc(gymUid).get();
  final data = gymDoc.data();
  final memberIds = data?['memberUserIds'] as List<dynamic>?;
  if (memberIds == null || memberIds.isEmpty) return [];

  final list = <Map<String, dynamic>>[];
  for (final id in memberIds) {
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
  return list;
}

/// Removes a user from this gym's members. Callable only by the gym (current user).
/// Removes the member from the gym's memberUserIds and removes this gym from the member's joinedGymIds.
Future<void> removeMemberFromGym(String memberUid) async {
  final gymUid = FirebaseAuth.instance.currentUser?.uid;
  if (gymUid == null) throw Exception('Not signed in');

  final gymRef = FirestoreRefs.userDoc(gymUid);
  final memberRef = FirestoreRefs.userDoc(memberUid);

  await FirebaseFirestore.instance.runTransaction((tx) async {
    tx.set(gymRef, {
      'memberUserIds': FieldValue.arrayRemove([memberUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    tx.set(memberRef, {
      'joinedGymIds': FieldValue.arrayRemove([gymUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });
}

// --- Gym channel management (for gym accounts) ---

/// Returns the list of channel names for a gym. Stored in gym doc as `channelNames`.
Future<List<String>> getGymChannels(String gymUid) async {
  final doc = await FirestoreRefs.userDoc(gymUid).get();
  final data = doc.data();
  final raw = data?['channelNames'] as List<dynamic>?;
  if (raw == null || raw.isEmpty) return [];
  return raw.map((e) => e is String ? e : e.toString()).toList();
}

/// Adds a channel name to the gym. Callable by the gym (current user).
Future<void> addGymChannel(String gymUid, String channelName) async {
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUid == null) throw Exception('Not signed in');
  final name = channelName.trim();
  if (name.isEmpty) throw Exception('Channel name cannot be empty');

  final gymRef = FirestoreRefs.userDoc(gymUid);
  await gymRef.set({
    'channelNames': FieldValue.arrayUnion([name]),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

/// Removes a channel name from the gym. Callable by the gym (current user).
Future<void> removeGymChannel(String gymUid, String channelName) async {
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUid == null) throw Exception('Not signed in');

  final gymRef = FirestoreRefs.userDoc(gymUid);
  await gymRef.set({
    'channelNames': FieldValue.arrayRemove([channelName]),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
