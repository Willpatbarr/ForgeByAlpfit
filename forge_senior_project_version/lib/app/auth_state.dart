import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Notifies GoRouter when auth state changes so redirect can run.
final class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier._() {
    _subscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  static final AuthStateNotifier instance = AuthStateNotifier._();

  StreamSubscription<User?>? _subscription;

  void startListening() {
    // Subscription created in constructor; call this from main to ensure instance exists.
  }

  void dispose() {
    _subscription?.cancel();
  }
}
