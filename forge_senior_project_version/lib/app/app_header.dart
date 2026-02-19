import 'package:flutter/material.dart';

/// Shared header bar with Forge logo and optional leading/trailing widgets.
/// Use on Feed, Calendar, Event Creator, Social, and Profile pages.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.leading,
    this.trailing,
  });

  static const Color forgeBlue = Color(0xFF4D7CFF);

  /// Wordmark vertical offset in pixels. Positive = down from center, negative = up.
  static const double wordmarkOffsetDy = 10;

  /// Optional widget on the left (e.g. menu button). If null, only logo is shown on the left.
  final Widget? leading;

  /// Optional widget on the right (e.g. profile avatar). If null, shows default circle icon.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: forgeBlue,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          SizedBox(
            width: 44,
            height: 44,
            child: Image.asset('images/forgeIcon.png', fit: BoxFit.contain),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            height: 44,
            child: ClipRect(
              child: Transform.translate(
                offset: Offset(0, wordmarkOffsetDy),
                child: Image.asset(
                  'images/forgeWordmarkWhite.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const Spacer(),
          trailing ??
              SizedBox(
                width: 44,
                height: 44,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.grey,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
