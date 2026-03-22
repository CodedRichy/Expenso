import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../repositories/cycle_repository.dart';
import '../../services/connectivity_service.dart';
import '../../services/profile_service.dart';
import '../../services/auth_service.dart';
import '../../services/locale_service.dart';
import '../../design/typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/member_avatar.dart';
import '../../widgets/tap_scale.dart';
import '../../widgets/fade_in.dart';
import '../../services/feature_flag_service.dart';
import 'package:flutter/services.dart';

/// Profile screen: identity (avatar, display name) and Payment Settings (UPI ID).
/// Display name is the same value used for Groq fuzzy matching in the Magic Bar.
///
/// Set [kPrivacyPolicyUrl] to your live privacy policy URL for store compliance.
/// Opens in the user's external browser (not in-app), per privacy best practice.
const String kPrivacyPolicyUrl =
    'https://github.com/CodedRichy/Expenso/blob/main/PRIVACY.md';

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
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );
    if (xFile == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final file = File(xFile.path);
      final url = await ProfileService.instance.uploadAvatar(
        repo.currentUserId,
        file,
      );
      if (url != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo updated'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Upload failed. Enable Supabase Storage in Dashboard (Storage) for profile photos.',
            ),
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
    if (ConnectivityService.instance.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save name while offline'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final repo = CycleRepository.instance;
    repo.setGlobalProfile(name, phone: repo.currentUserPhone, email: repo.currentUserEmail);
    Supabase.instance.client.auth.updateUser(UserAttributes(data: {'display_name': name}));
    setState(() => _nameDirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveUpi() async {
    final upiId = _upiController.text.trim();
    if (ConnectivityService.instance.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save UPI ID while offline'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final repo = CycleRepository.instance;
    await repo.updateCurrentUserUpiId(upiId.isEmpty ? null : upiId);
    setState(() => _upiDirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('UPI ID saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // theme is kept for colorScheme usage within builder
    final theme = Theme.of(context);


    return ListenableBuilder(
      listenable: CycleRepository.instance,
      builder: (context, _) {
        final repo = CycleRepository.instance;
        final displayName = repo.currentUserName.isEmpty
            ? 'You'
            : repo.currentUserName;
        final photoURL = repo.currentUserPhotoURL;

        return GradientScaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      TapScale(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          child: const Icon(Icons.chevron_left, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Profile',
                        style: context.headingMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        GlassCard(
                          padding: const EdgeInsets.all(24),
                          borderRadius: AppSpacing.radiusMedium,
                          child: FadeIn(
                            duration: const Duration(milliseconds: 400),
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: _uploadingPhoto
                                      ? null
                                      : _pickAndUploadPhoto,
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
                                              color: theme.colorScheme.scrim
                                                  .withValues(alpha: 0.5),
                                              borderRadius:
                                                  BorderRadius.circular(44),
                                            ),
                                            child: Center(
                                              child: SizedBox(
                                                width: 28,
                                                height: 28,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
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
                                              color: context.colorPrimary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Display name',
                                  style: context.labelSmall.copyWith(
                                    color: context.colorTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _nameController,
                                        style: context.labelLarge.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: Colors.black.withValues(
                                            alpha: 0.04,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TapScale(
                                      onTap: _nameDirty &&
                                              _nameController.text
                                                  .trim()
                                                  .isNotEmpty
                                          ? _saveName
                                          : null,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _nameDirty
                                              ? context.colorPrimary
                                              : context.colorPrimary
                                                    .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            AppSpacing.radiusSmall,
                                          ),
                                        ),
                                        child: Text(
                                          'Save',
                                          style: context.labelMedium.copyWith(
                                            color: _nameDirty
                                                ? Colors.white
                                                : context.colorPrimary
                                                      .withValues(alpha: 0.5),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This name is used in groups and for Magic Bar matching.',
                                  style: context.caption.copyWith(
                                    color: context.colorTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          borderRadius: AppSpacing.radiusMedium,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.payment,
                                    size: 20,
                                    color: context.colorPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Payment Settings',
                                    style: context.labelLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'UPI ID',
                                style: context.labelSmall.copyWith(
                                  color: context.colorTextSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _upiController,
                                      keyboardType: TextInputType.emailAddress,
                                      autocorrect: false,
                                      style: context.labelLarge,
                                      decoration: InputDecoration(
                                        hintText: 'e.g. name@upi',
                                        isDense: true,
                                        filled: true,
                                        fillColor: Colors.black.withValues(
                                          alpha: 0.04,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TapScale(
                                    onTap: _upiDirty ? _saveUpi : null,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _upiDirty
                                            ? context.colorPrimary
                                            : context.colorPrimary.withValues(
                                                alpha: 0.1,
                                              ),
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusSmall,
                                        ),
                                      ),
                                      child: Text(
                                        'Save',
                                        style: context.labelMedium.copyWith(
                                          color: _upiDirty
                                              ? Colors.white
                                              : context.colorPrimary
                                                    .withValues(alpha: 0.5),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _BetaAccessTile(),
                        const SizedBox(height: 24),
                        _LocaleTile(),
                        const SizedBox(height: 24),
                        _PrivacyPolicyTile(url: kPrivacyPolicyUrl),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
                          child: Semantics(
                            label: 'Log out',
                            button: true,
                            child: TapScale(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Log out?'),
                                      content: const Text(
                                        'You will need to sign in again to access your account.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Log out'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true && context.mounted) {
                                    await AuthService.instance.signOut();
                                    CycleRepository.instance.clearAuth();
                                    if (context.mounted) {
                                      Navigator.of(
                                        context,
                                      ).popUntil((route) => route.isFirst);
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                  minimumSize: const Size(double.infinity, 0),
                                ),
                                child: const Text(
                                  'Log out',
                                  style: AppTypography.button,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _LocaleTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {

    return ListenableBuilder(
      listenable: LocaleService.instance,
      builder: (context, _) {
        final current = LocaleService.instance.localeCode;
        final label = current == null || current.isEmpty
            ? 'Device default'
            : () {
                final option = LocaleService.options.where(
                  (e) => e.value == current,
                );
                return option.isEmpty ? current : option.first.key;
              }();
        return Semantics(
          label: 'Number format: $label',
          button: true,
          child: InkWell(
            onTap: () {
              showModalBottomSheet<void>(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Number format', style: context.subheader),
                      ),
                      ...LocaleService.options.map((e) {
                        final selected =
                            (e.value.isEmpty && current == null) ||
                            (e.value.isNotEmpty && e.value == current);
                        return ListTile(
                          title: Text(e.key),
                          trailing: selected ? const Icon(Icons.check) : null,
                          onTap: () {
                            LocaleService.instance.setLocale(
                              e.value.isEmpty ? null : e.value,
                            );
                            Navigator.pop(ctx);
                          },
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              borderRadius: AppSpacing.radiusMedium,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.numbers,
                    size: 22,
                    color: context.colorTextSecondary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Number format', style: context.sectionLabel),
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(label, style: context.bodyPrimary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 22,
                    color: context.colorTextTertiary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PrivacyPolicyTile extends StatelessWidget {
  final String url;

  const _PrivacyPolicyTile({required this.url});

  Future<void> _openUrl(BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } on Exception catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Privacy policy',
      button: true,
      child: TapScale(
        onTap: () => _openUrl(context),
        child: GlassCard(
          padding: const EdgeInsets.all(20),
          borderRadius: AppSpacing.radiusMedium,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.privacy_tip_outlined,
                size: 20,
                color: context.colorPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Privacy policy',
                  style: context.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.open_in_new,
                size: 18,
                color: context.colorTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BetaAccessTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {

    final repo = CycleRepository.instance;
    final flags = FeatureFlagService.instance;
    final isBeta = flags.isBetaTester;
    final uid = repo.currentUserId;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: AppSpacing.radiusMedium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isBeta ? Icons.verified_user : Icons.science_outlined,
                size: 20,
                color: isBeta ? Colors.green : context.colorTextSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                isBeta ? 'Beta Tester' : 'Experimental Features',
                style: context.labelLarge.copyWith(fontWeight: FontWeight.w600),
              ),
              if (isBeta) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isBeta
                ? 'You have access to experimental features before they release to everyone.'
                : 'Share your User ID with the creator to join the beta program.',
            style: context.bodySecondary.copyWith(height: 1.4),
          ),
          const SizedBox(height: 16),
          TapScale(
            onTap: () {
              Clipboard.setData(ClipboardData(text: uid));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('User ID copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR USER ID',
                          style: context.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          uid.isEmpty ? 'Not logged in' : uid,
                          style: context.caption.copyWith(
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.copy,
                    size: 16,
                    color: context.colorPrimary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
