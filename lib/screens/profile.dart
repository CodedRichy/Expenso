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

  static const Color _blackGradientStart = Color(0xFF1A1A1A);
  static const Color _blackGradientEnd = Color(0xFF6B6B6B);

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
                        color: const Color(0xFF1A1A1A),
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Profile',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Identity card (black gradient)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A1A1A).withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_blackGradientStart, _blackGradientEnd],
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
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1A1A1A),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
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
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.12),
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
                                  color: _nameDirty ? Colors.white : Colors.white54,
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
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Payment Settings
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A1A1A).withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_blackGradientStart, _blackGradientEnd],
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
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Payment Settings',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.95),
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
                            color: Colors.white.withValues(alpha: 0.7),
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
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'e.g. name@upi',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 16,
                                  ),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.12),
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
                                  color: _upiDirty ? Colors.white : Colors.white54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Appearance Settings
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A1A1A).withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_blackGradientStart, _blackGradientEnd],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.palette_outlined,
                              size: 20,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Appearance',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ListenableBuilder(
                          listenable: ThemeService.instance,
                          builder: (context, _) {
                            return Row(
                              children: [
                                _ThemeOption(
                                  icon: Icons.brightness_auto,
                                  label: 'System',
                                  selected: ThemeService.instance.themeMode == ThemeMode.system,
                                  onTap: () => ThemeService.instance.setThemeMode(ThemeMode.system),
                                ),
                                const SizedBox(width: 12),
                                _ThemeOption(
                                  icon: Icons.light_mode,
                                  label: 'Light',
                                  selected: ThemeService.instance.themeMode == ThemeMode.light,
                                  onTap: () => ThemeService.instance.setThemeMode(ThemeMode.light),
                                ),
                                const SizedBox(width: 12),
                                _ThemeOption(
                                  icon: Icons.dark_mode,
                                  label: 'Dark',
                                  selected: ThemeService.instance.themeMode == ThemeMode.dark,
                                  onTap: () => ThemeService.instance.setThemeMode(ThemeMode.dark),
                                ),
                              ],
                            );
                          },
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

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(color: Colors.white24)
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 24,
                color: selected ? Colors.white : Colors.white60,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
