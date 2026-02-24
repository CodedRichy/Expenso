import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Avatar for a member: letter fallback renders IMMEDIATELY, photo loads as an upgrade layer.
/// Zero visible waiting time - the letter is always the base layer.
class MemberAvatar extends StatelessWidget {
  final String displayName;
  final String? photoURL;
  final double size;

  const MemberAvatar({
    super.key,
    required this.displayName,
    this.photoURL,
    this.size = 40,
  });

  static const Color _letterBg = Color(0xFF1A1A1A);
  static const Color _letterFg = Color(0xFFE8EAED);

  @override
  Widget build(BuildContext context) {
    final letter = _initial(displayName);
    final hasPhoto = photoURL != null && photoURL!.trim().isNotEmpty;

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: _letterBg,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            letter,
            style: TextStyle(
              fontSize: size * 0.45,
              fontWeight: FontWeight.w600,
              color: _letterFg,
            ),
          ),
          if (hasPhoto)
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: photoURL!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                memCacheWidth: (size * 2).toInt(),
                memCacheHeight: (size * 2).toInt(),
                fadeInDuration: const Duration(milliseconds: 200),
                fadeOutDuration: const Duration(milliseconds: 100),
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  static String _initial(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    final first = t.runes.first;
    return String.fromCharCode(first).toUpperCase();
  }
}
