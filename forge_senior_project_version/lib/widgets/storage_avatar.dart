import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/profile_avatar_service.dart';

/// Loads `avatars/{uid}/profile`. Uses [Image.memory] when possible; on web,
/// if bytes are missing, uses [Image.network] with [WebHtmlElementStrategy.prefer]
/// so the engine uses an HTML img (works with Storage when canvas fetch does not).
class StorageAvatar extends StatefulWidget {
  const StorageAvatar({
    super.key,
    required this.uid,
    required this.size,
    this.borderRadius,
    required this.placeholder,
    this.showLoading = true,
  });

  final String? uid;
  final double size;
  final BorderRadius? borderRadius;
  final Widget placeholder;
  final bool showLoading;

  @override
  State<StorageAvatar> createState() => _StorageAvatarState();
}

class _StorageAvatarState extends State<StorageAvatar> {
  Uint8List? _bytes;
  String? _downloadUrl;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StorageAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _bytes = null;
      _downloadUrl = null;
      _resolved = false;
      _load();
    }
  }

  Future<void> _load() async {
    final uid = widget.uid;
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _resolved = true);
      return;
    }
    final loaded = await AvatarBytesMemoryCache.load(uid);
    if (!mounted) return;
    setState(() {
      _bytes = loaded.bytes;
      _downloadUrl = loaded.downloadUrl;
      _resolved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ??
        BorderRadius.circular(widget.size <= 0 ? 0 : widget.size / 2);

    if (!_resolved && widget.showLoading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: SizedBox(
            width: widget.size * 0.42,
            height: widget.size * 0.42,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!_resolved) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: widget.placeholder,
      );
    }
    if (_bytes != null && _bytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.memory(
          _bytes!,
          fit: BoxFit.cover,
          width: widget.size,
          height: widget.size,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        ),
      );
    }
    final url = _downloadUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: widget.size,
          height: widget.size,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          webHtmlElementStrategy: kIsWeb
              ? WebHtmlElementStrategy.prefer
              : WebHtmlElementStrategy.never,
          errorBuilder: (_, __, ___) => widget.placeholder,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: widget.size * 0.42,
                height: widget.size * 0.42,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      );
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: widget.placeholder,
    );
  }
}
