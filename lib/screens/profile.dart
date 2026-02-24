import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../repositories/cycle_repository.dart';
import '../services/profile_service.dart';
import '../services/theme_service.dart';
import '../design/typography.dart';
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

        return Scaffold(
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
                        colors: isDark 
                            ? [theme.colorScheme.surfaceContainerHighest, theme.colorScheme.surfaceContainerHigh]
                            : [const Color(0xFF1A1A1A), const Color(0xFF6B6B6B)],
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
                        colors: isDark 
                            ? [theme.colorScheme.surfaceContainerHighest, theme.colorScheme.surfaceContainerHigh]
                            : [const Color(0xFF1A1A1A), const Color(0xFF6B6B6B)],
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

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  void _cycleTheme() {
    final current = ThemeService.instance.themeMode;
    final next = switch (current) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    ThemeService.instance.setThemeMode(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final mode = ThemeService.instance.themeMode;
        final isDark = mode == ThemeMode.dark || 
            (mode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
        
        return GestureDetector(
          onTap: _cycleTheme,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return RotationTransition(
                    turns: Tween(begin: 0.5, end: 1.0).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOut),
                    ),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: CustomPaint(
                  key: ValueKey(isDark),
                  size: const Size(22, 22),
                  painter: _EclipsePainter(
                    isDark: isDark,
                    color: theme.colorScheme.onSurface,
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

class _EclipsePainter extends CustomPainter {
  final bool isDark;
  final Color color;
  
  _EclipsePainter({required this.isDark, required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    canvas.drawCircle(center, radius, paint);
    
    if (isDark) {
      final clearPaint = Paint()
        ..blendMode = BlendMode.clear;
      
      canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
      canvas.drawCircle(center, radius, paint);
      
      final eclipseCenter = Offset(center.dx + radius * 0.35, center.dy - radius * 0.35);
      canvas.drawCircle(eclipseCenter, radius * 0.7, clearPaint);
      canvas.restore();
    }
  }
  
  @override
  bool shouldRepaint(_EclipsePainter oldDelegate) => 
      isDark != oldDelegate.isDark || color != oldDelegate.color;
}
