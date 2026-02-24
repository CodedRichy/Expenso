import 'dart:io';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../design/colors.dart';
import '../repositories/cycle_repository.dart';
import '../services/profile_service.dart';
import '../services/theme_service.dart';
import '../design/typography.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/member_avatar.dart';

/// Profile screen: identity (avatar, display name) and Payment Settings (UPI ID).
/// Display name is the same value used for Groq fuzzy matching in the Magic Bar.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();
  bool _nameDirty = false;
  bool _upiDirty = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final repo = CycleRepository.instance;
    _nameController.text = repo.currentUserName;
    _upiController.text = repo.currentUserUpiId ?? '';
    _nameController.addListener(() => setState(() => _nameDirty = true));
    _upiController.addListener(() => setState(() => _upiDirty = true));
    repo.refreshCurrentUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final repo = CycleRepository.instance;
    if (repo.currentUserId.isEmpty) return;
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
    if (xFile == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final file = File(xFile.path);
      final url = await ProfileService.instance.uploadAvatar(repo.currentUserId, file);
      if (url != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo updated'), behavior: SnackBarBehavior.floating),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload failed. Enable Firebase Storage in Console (Build → Storage) for profile photos.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _saveName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final repo = CycleRepository.instance;
    repo.setGlobalProfile(repo.currentUserPhone, name);
    FirebaseAuth.instance.currentUser?.updateDisplayName(name);
    setState(() => _nameDirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name saved'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _saveUpi() async {
    final upiId = _upiController.text.trim();
    final repo = CycleRepository.instance;
    await repo.updateCurrentUserUpiId(upiId.isEmpty ? null : upiId);
    setState(() => _upiDirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('UPI ID saved'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return ListenableBuilder(
      listenable: CycleRepository.instance,
      builder: (context, _) {
        final repo = CycleRepository.instance;
        final displayName = repo.currentUserName.isEmpty ? 'You' : repo.currentUserName;
        final photoURL = repo.currentUserPhotoURL;

        return GradientScaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.chevron_left, size: 24),
                        color: Theme.of(context).colorScheme.onSurface,
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Profile',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const _ThemeToggleButton(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withValues(alpha: isDark ? 0.3 : 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [context.colorGradientStart, context.colorGradientEnd],
                      ),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              MemberAvatar(
                                displayName: displayName,
                                photoURL: photoURL,
                                size: 88,
                              ),
                              if (_uploadingPhoto)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(44),
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.camera_alt, size: 16, color: theme.colorScheme.onPrimary),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Display name',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark 
                                ? theme.colorScheme.onSurfaceVariant 
                                : Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? theme.colorScheme.onSurface : Colors.white,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: isDark 
                                      ? theme.colorScheme.surfaceContainerLow 
                                      : Colors.white.withValues(alpha: 0.12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _nameDirty && _nameController.text.trim().isNotEmpty ? _saveName : null,
                              child: Text(
                                'Save',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _nameDirty 
                                      ? (isDark ? theme.colorScheme.primary : Colors.white) 
                                      : (isDark ? theme.colorScheme.onSurfaceVariant : Colors.white54),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This name is used in groups and for Magic Bar matching.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark 
                                ? theme.colorScheme.onSurfaceVariant 
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withValues(alpha: isDark ? 0.2 : 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [context.colorGradientStart, context.colorGradientEnd],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.payment,
                              size: 20,
                              color: isDark 
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.9) 
                                  : Colors.white.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Payment Settings',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark 
                                    ? theme.colorScheme.onSurface 
                                    : Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'UPI ID',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark 
                                ? theme.colorScheme.onSurfaceVariant 
                                : Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _upiController,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? theme.colorScheme.onSurface : Colors.white,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'e.g. name@upi',
                                  hintStyle: TextStyle(
                                    color: isDark 
                                        ? theme.colorScheme.onSurfaceVariant 
                                        : Colors.white.withValues(alpha: 0.5),
                                    fontSize: 16,
                                  ),
                                  isDense: true,
                                  filled: true,
                                  fillColor: isDark 
                                      ? theme.colorScheme.surfaceContainerLow 
                                      : Colors.white.withValues(alpha: 0.12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _upiDirty ? _saveUpi : null,
                              child: Text(
                                'Save',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _upiDirty 
                                      ? (isDark ? theme.colorScheme.primary : Colors.white) 
                                      : (isDark ? theme.colorScheme.onSurfaceVariant : Colors.white54),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: ElevatedButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Log out?'),
                          content: const Text('You will need to sign in again with your phone number.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Log out'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await FirebaseAuth.instance.signOut();
                        CycleRepository.instance.clearAuth();
                        if (context.mounted) {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 0),
                    ),
                    child: const Text('Log out', style: AppTypography.button),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThemeToggleButton extends StatefulWidget {
  const _ThemeToggleButton();

  @override
  State<_ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends State<_ThemeToggleButton> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _eclipseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 750),
      vsync: this,
    );
    _eclipseAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    
    final mode = ThemeService.instance.themeMode;
    final isDark = mode == ThemeMode.dark || 
        (mode == ThemeMode.system && 
         WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
    if (isDark) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _cycleTheme() {
    final current = ThemeService.instance.themeMode;
    final next = switch (current) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    ThemeService.instance.setThemeMode(next);
    
    final willBeDark = next == ThemeMode.dark || 
        (next == ThemeMode.system && 
         MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    
    if (willBeDark) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurface;
    final bgColor = theme.scaffoldBackgroundColor;
    
    return GestureDetector(
      onTap: _cycleTheme,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: AnimatedBuilder(
            animation: _eclipseAnimation,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(24, 24),
                painter: _EclipsePainter(
                  progress: _eclipseAnimation.value,
                  color: iconColor,
                  backgroundColor: bgColor,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EclipsePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  
  _EclipsePainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });
  
  static const int _rayCount = 8;
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final rayPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    
    // Draw sun rays (fade out as moon comes in)
    final rayOpacity = 1.0 - progress;
    if (rayOpacity > 0) {
      rayPaint.color = color.withValues(alpha: rayOpacity);
      final rayInnerRadius = radius + 2;
      final rayOuterRadius = radius + 5;
      
      for (int i = 0; i < _rayCount; i++) {
        final angle = (i * math.pi * 2 / _rayCount) - math.pi / 2;
        final cosA = math.cos(angle);
        final sinA = math.sin(angle);
        final startX = center.dx + rayInnerRadius * cosA;
        final startY = center.dy + rayInnerRadius * sinA;
        final endX = center.dx + rayOuterRadius * cosA;
        final endY = center.dy + rayOuterRadius * sinA;
        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), rayPaint);
      }
    }
    
    // Draw the main circle (sun/moon base)
    canvas.drawCircle(center, radius, paint);
    
    // Draw the moon (cutout) sliding across
    if (progress > 0) {
      final cutoutPaint = Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.fill;
      
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
      
      final moonOffset = Offset(
        center.dx + radius * 1.2 * (1 - progress),
        center.dy - radius * 0.3 * progress,
      );
      canvas.drawCircle(moonOffset, radius * 0.85, cutoutPaint);
      
      canvas.restore();
    }
  }
  
  @override
  bool shouldRepaint(_EclipsePainter oldDelegate) => 
      progress != oldDelegate.progress || 
      color != oldDelegate.color ||
      backgroundColor != oldDelegate.backgroundColor;
}
