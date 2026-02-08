import 'package:cloud_firestore/cloud_firestore.dart';

abstract class FirestoreRefs {
  static FirebaseFirestore get _store => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get users =>
      _store.collection('users');

  static DocumentReference<Map<String, dynamic>> userDoc(String userId) =>
      users.doc(userId);
}
