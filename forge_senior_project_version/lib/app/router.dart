import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/feed/presentation/view/feed_page.dart';
import '../features/calendar/presentation/view/calendar_page.dart';
import '../features/event_creator/presentation/view/event_creator_page.dart';
import '../features/social/presentation/view/social_page.dart';
import '../features/profile/presentation/view/profile_page.dart';
import 'bottom_nav.dart';
import '../features/auth/presentation/view/login_page.dart';
import '../features/auth/presentation/view/register_page.dart';
import 'auth_state.dart';

// Route order for determining slide direction
final Map<String, int> _routeOrder = {
  '/feed': 0,
  '/calendar': 1,
  '/event': 2,
  '/social': 3,
  '/profile': 4,
};

// Global variable to track current route
String _currentRoute = '/feed';

// Helper function to get slide direction based on route indices
Offset _getSlideOffset(String fromRoute, String toRoute) {
  final fromIndex = _routeOrder[fromRoute] ?? 0;
  final toIndex = _routeOrder[toRoute] ?? 0;
  
  if (toIndex > fromIndex) {
    // Moving right (slide in from right)
    return const Offset(1.0, 0.0);
  } else if (toIndex < fromIndex) {
    // Moving left (slide in from left)
    return const Offset(-1.0, 0.0);
  } else {
    // Same route, no slide
    return Offset.zero;
  }
}

// Custom page transition builder
Page<T> _buildPageWithTransition<T extends Object?>(
  Widget child,
  GoRouterState state,
) {
  final toRoute = state.uri.path;
  final slideOffset = _getSlideOffset(_currentRoute, toRoute);
  
  // Update current route for next navigation
  _currentRoute = toRoute;
  
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Slide transition
      return SlideTransition(
        position: Tween<Offset>(
          begin: slideOffset,
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
        ),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 150),
  );
}

String? _redirect(BuildContext context, GoRouterState state) {
  final loggedIn = FirebaseAuth.instance.currentUser != null;
  final onLogin = state.uri.path == '/login';
  final onRegister = state.uri.path == '/register';
  if (!loggedIn && !onLogin && !onRegister) return '/login';
  if (loggedIn && (onLogin || onRegister)) return '/feed';
  return null;
}

final router = GoRouter(
  initialLocation: '/login',
  refreshListenable: AuthStateNotifier.instance,
  redirect: _redirect,
  routes: [
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const LoginPage(),
      ),
    ),
    GoRoute(
      path: '/register',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const RegisterPage(),
      ),
    ),
    ShellRoute(
      builder: (context, state, child) {
        return Scaffold(
          body: Column(
            children: [
              // Router view takes up available space
              Expanded(child: child),
              // Persistent bottom nav - always visible and stationary
              const PersistentBottomNav(),
            ],
          ),
        );
      },
      routes: [
        GoRoute(
          path: '/feed',
          pageBuilder: (context, state) => _buildPageWithTransition(
            const FeedPage(),
            state,
          ),
        ),
        GoRoute(
          path: '/calendar',
          pageBuilder: (context, state) => _buildPageWithTransition(
            const CalendarPage(),
            state,
          ),
        ),
        GoRoute(
          path: '/event',
          pageBuilder: (context, state) => _buildPageWithTransition(
            EventCreatorPage(eventId: state.uri.queryParameters['edit']),
            state,
          ),
        ),
        GoRoute(
          path: '/social',
          pageBuilder: (context, state) => _buildPageWithTransition(
            const SocialPage(),
            state,
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => _buildPageWithTransition(
            const ProfilePage(),
            state,
          ),
        ),
      ],
    ),
  ],
);
