import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firebase/firestore_refs.dart';

/// Account type for registration: regular user or gym.
enum AccountType { user, gym }

/// Handles Firebase Auth and creation of user documents in Firestore.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password.
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  /// Sign up with email, password, display name, and account type. Creates Firestore user doc.
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required AccountType accountType,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user == null) return;

    await user.updateDisplayName(displayName.trim());

    final name = displayName.trim();
    final ref = FirestoreRefs.userDoc(user.uid);
    await ref.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': name,
      'displayNameLower': name.toLowerCase(),
      'accountType': accountType.name,
      'contactInfo': null,
      'friendIds': <String>[],
      'joinedGymIds': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Sign out.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
