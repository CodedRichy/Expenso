import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Avatar for a member: photo from [photoURL] if set, otherwise letter from [displayName].
/// Matches black gradient theme when showing letter fallback.
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

    if (photoURL != null && photoURL!.trim().isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: _letterBg,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: photoURL!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (context, url) => Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: size * 0.45,
                  fontWeight: FontWeight.w600,
                  color: _letterFg,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: size * 0.45,
                  fontWeight: FontWeight.w600,
                  color: _letterFg,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: _letterBg,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w600,
          color: _letterFg,
        ),
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
