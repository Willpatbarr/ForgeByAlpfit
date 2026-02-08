import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PersistentBottomNav extends StatelessWidget {
  const PersistentBottomNav({super.key});

  static const Color forgeBlue = Color(0xFF4D7CFF);

  @override
  Widget build(BuildContext context) {
    // Now we're in the router context, so we can safely use GoRouterState
    final currentLocation = GoRouterState.of(context).uri.path;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Feed',
                route: '/feed',
                isActive: currentLocation == '/feed',
              ),
              _buildNavItem(
                context,
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today,
                label: 'Calendar',
                route: '/calendar',
                isActive: currentLocation == '/calendar',
              ),
              _buildNavItem(
                context,
                icon: Icons.add_circle_outline,
                activeIcon: Icons.add_circle,
                label: 'Event',
                route: '/event',
                isActive: currentLocation == '/event',
              ),
              _buildNavItem(
                context,
                icon: Icons.people_outline,
                activeIcon: Icons.people,
                label: 'Social',
                route: '/social',
                isActive: currentLocation == '/social',
              ),
              _buildNavItem(
                context,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                route: '/profile',
                isActive: currentLocation == '/profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String route,
    required bool isActive,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          if (!isActive) {
            context.go(route);
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? forgeBlue : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? forgeBlue : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

