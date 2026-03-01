import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../design/colors.dart';

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

  @override
  Widget build(BuildContext context) {
    final letter = _initial(displayName);
    final hasPhoto = photoURL != null && photoURL!.trim().isNotEmpty;
    final letterBg = context.colorPrimary;
    final letterFg = Theme.of(context).colorScheme.onPrimary;

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: letterBg,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            letter,
            style: TextStyle(
              fontSize: size * 0.45,
              fontWeight: FontWeight.w600,
              color: letterFg,
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
                placeholder: (_, url) => const SizedBox.shrink(),
                errorWidget: (_, url, error) => const SizedBox.shrink(),
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
