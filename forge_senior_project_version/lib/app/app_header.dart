import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'auth_state.dart';
import '../services/profile_avatar_service.dart';
import '../widgets/storage_avatar.dart';

/// Shared header bar with Forge logo and optional leading/trailing widgets.
/// Use on Feed, Calendar, Event Creator, Social, and Profile pages.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, this.leading, this.trailing});

  static const Color forgeBlue = Color(0xFF4D7CFF);

  /// Wordmark vertical nudge on web (logical pixels, down = positive).
  static const double wordmarkOffsetDy = 2;

  /// Wordmark vertical nudge on iOS/Android (tweak to align with the flame icon).
  static const double wordmarkOffsetDyMobile = 6;

  /// Optional widget on the left (e.g. menu button). If null, only logo is shown on the left.
  final Widget? leading;

  /// Optional widget on the right. If null, shows tappable profile photo (or default icon).
  final Widget? trailing;

  static const double _avatarSize = 40;

  /// Scales wordmark vs [Expanded] width and row height. Same ratio on both axes so
  /// [BoxFit.contain] isn’t stuck on height-only (changing width alone then had no effect).
  static const double _wordmarkScale = 38 / 64;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Container(
        color: forgeBlue,
        padding: EdgeInsets.only(
          left: 14,
          right: 14,
          top: topInset + 8,
          bottom: 8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            SizedBox(
              width: _avatarSize,
              height: _avatarSize,
              child: Image.asset('images/forgeIcon.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wordmarkW =
                      constraints.maxWidth * _wordmarkScale;
                  final wordmarkH = _avatarSize * _wordmarkScale;
                  Widget asset() => Image.asset(
                        'images/forgeWordmarkWhite.png',
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                        filterQuality: FilterQuality.medium,
                      );
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: wordmarkW,
                      height: wordmarkH,
                      child: kIsWeb
                          ? ClipRect(
                              clipBehavior: Clip.hardEdge,
                              child: Transform.translate(
                                offset: const Offset(0, wordmarkOffsetDy),
                                child: asset(),
                              ),
                            )
                          : Transform.translate(
                              offset:
                                  const Offset(0, wordmarkOffsetDyMobile),
                              child: asset(),
                            ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 6),
            trailing ?? const _HeaderProfileChip(),
          ],
        ),
      ),
    );
  }
}

class _HeaderProfileChip extends StatelessWidget {
  const _HeaderProfileChip();

  @override
  Widget build(BuildContext context) {
    // Web: [currentUser] can be null on the first frame while IndexedDB restores
    // the session. Without listening to auth, the chip stays on uid null forever
    // (no Storage requests) until something else rebuilds this widget.
    return ListenableBuilder(
      listenable: Listenable.merge([
        AvatarHeaderRefreshNotifier.version,
        AuthStateNotifier.instance,
      ]),
      builder: (context, _) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => context.go('/profile'),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: AppHeader._avatarSize,
              height: AppHeader._avatarSize,
              child: ClipOval(
                child: ColoredBox(
                  color: Colors.white,
                  child: StorageAvatar(
                    uid: uid,
                    size: AppHeader._avatarSize,
                    borderRadius: BorderRadius.circular(
                      AppHeader._avatarSize / 2,
                    ),
                    showLoading: false,
                    placeholder: const Center(
                      child: Icon(Icons.person, color: Colors.grey, size: 22),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
