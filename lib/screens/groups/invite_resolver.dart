import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../repositories/cycle_repository.dart';
import '../../services/firestore_service.dart';
import '../../widgets/expenso_loader.dart';

/// Handles deep links of the form: expenso://invite/{groupId}/{token}
///
/// Edge cases handled:
///   - Logged-out user → redirected to sign-in, link re-resolved after auth
///   - Already a member → redirected directly to the group
///   - Revoked / invalid token → rejection screen
///   - Deleted group → graceful failure screen
class InviteResolverScreen extends StatefulWidget {
  final String groupId;
  final String token;

  const InviteResolverScreen({
    super.key,
    required this.groupId,
    required this.token,
  });

  @override
  State<InviteResolverScreen> createState() => _InviteResolverScreenState();
}

enum _ResolveState {
  loading,
  alreadyMember,
  joining,
  success,
  invalidLink,
  error,
}

class _InviteResolverScreenState extends State<InviteResolverScreen> {
  _ResolveState _state = _ResolveState.loading;
  String _groupName = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    // Must be authenticated — RootScreen handles unauthenticated redirect,
    // so if we arrive here the user is signed in.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Fallback: shouldn't happen but guard anyway.
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
      }
      return;
    }

    final result = await FirestoreService.instance.resolveInviteLink(
      widget.groupId,
      widget.token,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() => _state = _ResolveState.invalidLink);
      return;
    }

    _groupName = result['groupName'] ?? 'Group';

    // Check if already a member (local cache).
    final repo = CycleRepository.instance;
    final existing = repo.getGroup(widget.groupId);
    if (existing != null && existing.memberIds.contains(user.uid)) {
      setState(() => _state = _ResolveState.alreadyMember);
      return;
    }

    setState(() => _state = _ResolveState.joining);
  }

  Future<void> _acceptAndJoin() async {
    try {
      final repo = CycleRepository.instance;
      await repo.acceptInvitation(widget.groupId);
      if (mounted) setState(() => _state = _ResolveState.success);
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ResolveState.error;
          _errorMessage = 'Could not join group. Please try again.';
        });
      }
    }
  }

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil('/groups', (r) => false);
  }

  void _goToGroup() {
    final repo = CycleRepository.instance;
    final group = repo.getGroup(widget.groupId);
    Navigator.of(context).pushNamedAndRemoveUntil('/groups', (r) => false);
    if (group != null) {
      Navigator.of(context).pushNamed('/group-detail', arguments: group);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _ResolveState.loading:
        return const Center(child: ExpensoLoader());

      case _ResolveState.alreadyMember:
        return _centeredCard(
          icon: Icons.group,
          iconColor: AppColors.primary,
          title: 'You\'re already in this group',
          subtitle: 'You\'re already a member of "$_groupName".',
          primaryLabel: 'Go to group',
          onPrimary: _goToGroup,
        );

      case _ResolveState.joining:
        return _centeredCard(
          icon: Icons.group_add_outlined,
          iconColor: AppColors.primary,
          title: 'Join "$_groupName"?',
          subtitle:
              'You\'ve been invited to join this group. Tap below to accept.',
          primaryLabel: 'Join group',
          onPrimary: _acceptAndJoin,
          secondaryLabel: 'Decline',
          onSecondary: _goHome,
        );

      case _ResolveState.success:
        return _centeredCard(
          icon: Icons.check_circle,
          iconColor: AppColors.success,
          title: 'Welcome to "$_groupName"!',
          subtitle: 'You\'ve successfully joined the group.',
          primaryLabel: 'Open group',
          onPrimary: _goToGroup,
        );

      case _ResolveState.invalidLink:
        return _centeredCard(
          icon: Icons.link_off,
          iconColor: AppColors.error,
          title: 'Invite link expired or revoked',
          subtitle:
              'This link is no longer valid. Ask a group admin to share a new one.',
          primaryLabel: 'Go to home',
          onPrimary: _goHome,
        );

      case _ResolveState.error:
        return _centeredCard(
          icon: Icons.error_outline,
          iconColor: AppColors.error,
          title: 'Something went wrong',
          subtitle: _errorMessage ?? 'An unexpected error occurred.',
          primaryLabel: 'Go to home',
          onPrimary: _goHome,
        );
    }
  }

  Widget _centeredCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String primaryLabel,
    required VoidCallback onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: iconColor),
          ),
          const SizedBox(height: AppSpacing.space3xl),
          Text(
            title,
            style: AppTypography.screenTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.spaceLg),
          Text(
            subtitle,
            style: AppTypography.bodySecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.space3xl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPrimary,
              child: Text(primaryLabel),
            ),
          ),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: AppSpacing.spaceMd),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSecondary,
                child: Text(secondaryLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
