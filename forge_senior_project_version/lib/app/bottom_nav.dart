import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/direct_messages_service.dart';

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
      // top: false — otherwise iOS applies status-bar padding above this bar (wrong place).
      child: SafeArea(
        top: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 2),
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
              StreamBuilder<Map<String, int>>(
                stream: getDirectUnreadCountsStream(),
                builder: (context, snapshot) {
                  final totalUnread = (snapshot.data ?? const <String, int>{})
                      .values
                      .fold<int>(0, (sum, count) => sum + count);
                  return _buildNavItem(
                    context,
                    icon: Icons.people_outline,
                    activeIcon: Icons.people,
                    label: 'Social',
                    route: '/social',
                    isActive: currentLocation == '/social',
                    badgeCount: totalUnread,
                  );
                },
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
    int badgeCount = 0,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          if (!isActive) {
            context.go(route);
          }
        },
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isActive ? activeIcon : icon,
                    color: isActive ? forgeBlue : Colors.grey,
                    size: 24,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: const BoxDecoration(
                          color: forgeBlue,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

