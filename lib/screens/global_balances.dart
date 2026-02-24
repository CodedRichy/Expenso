import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/global_balance.dart';
import '../repositories/cycle_repository.dart';
import '../services/connectivity_service.dart';
import '../services/identity_service.dart';
import '../utils/settlement_engine.dart';
import '../widgets/member_avatar.dart';
import '../widgets/offline_banner.dart';

class GlobalBalancesScreen extends StatefulWidget {
  const GlobalBalancesScreen({super.key});

  @override
  State<GlobalBalancesScreen> createState() => _GlobalBalancesScreenState();
}

class _GlobalBalancesScreenState extends State<GlobalBalancesScreen> {
  List<GlobalBalance> _balances = [];
  bool _loading = true;
  bool _showOptimized = false;
  List<OptimizedRoute> _optimizedRoutes = [];
  int _originalCount = 0;
  int _optimizedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  void _loadBalances() {
    final repo = CycleRepository.instance;
    final balances = repo.computeGlobalBalances();
    final (original, optimized, _) = repo.getOptimizationComparison();
    final routes = repo.computeOptimizedRoutes();
    setState(() {
      _balances = balances;
      _optimizedRoutes = routes;
      _originalCount = original;
      _optimizedCount = optimized;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OfflineBanner(onRetry: () => ConnectivityService.instance.checkNow()),
            _buildHeader(context),
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_balances.isEmpty)
              _buildEmptyState()
            else ...[
              if (_originalCount > 1 && _optimizedCount < _originalCount)
                _buildOptimizationBanner(),
              Expanded(
                child: _showOptimized
                    ? _buildOptimizedRoutesList()
                    : _buildBalancesList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final totalOwed = _balances
        .where((b) => b.theyOweYou)
        .fold<int>(0, (sum, b) => sum + b.netBalanceMinor);
    final totalOwe = _balances
        .where((b) => b.youOweThem)
        .fold<int>(0, (sum, b) => sum + b.netBalanceMinor.abs());

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.spaceXl,
        AppSpacing.screenPaddingH,
        AppSpacing.space2xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.arrow_back, size: 20),
                ),
              ),
              const SizedBox(width: AppSpacing.spaceXl),
              Expanded(
                child: Text(
                  'All Balances',
                  style: AppTypography.h2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2xl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You are owed',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${(totalOwed / 100).toStringAsFixed(0)}',
                        style: AppTypography.h1.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: Colors.white24,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.spaceXl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You owe',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${(totalOwe / 100).toStringAsFixed(0)}',
                          style: AppTypography.h1.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.spaceXl),
          Text(
            '${_balances.length} contact${_balances.length == 1 ? '' : 's'} across ${_countGroups()} group${_countGroups() == 1 ? '' : 's'}',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  int _countGroups() {
    final groups = <String>{};
    for (final b in _balances) {
      for (final c in b.breakdown) {
        groups.add(c.groupId);
      }
    }
    return groups.length;
  }

  Widget _buildOptimizationBanner() {
    final savings = _originalCount - _optimizedCount;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        0,
        AppSpacing.screenPaddingH,
        AppSpacing.spaceXl,
      ),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: _showOptimized ? AppColors.successBackground : AppColors.accentBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _showOptimized ? AppColors.success : AppColors.accent,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 20,
                color: _showOptimized ? AppColors.success : AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.spaceMd),
              Expanded(
                child: Text(
                  'God Mode',
                  style: AppTypography.labelLarge.copyWith(
                    color: _showOptimized ? AppColors.success : AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spaceMd,
                  vertical: AppSpacing.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: _showOptimized ? AppColors.success : AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '-$savings payment${savings == 1 ? '' : 's'}',
                  style: AppTypography.captionSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceMd),
          Text(
            _showOptimized
                ? 'Showing optimized payments: $_optimizedCount instead of $_originalCount'
                : 'Optimize $_originalCount payments down to $_optimizedCount',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceLg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() => _showOptimized = !_showOptimized),
              style: OutlinedButton.styleFrom(
                foregroundColor: _showOptimized ? AppColors.success : AppColors.accent,
                side: BorderSide(
                  color: _showOptimized ? AppColors.success : AppColors.accent,
                ),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.spaceLg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(_showOptimized ? 'Show per-contact view' : 'Show optimized payments'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimizedRoutesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
      itemCount: _optimizedRoutes.length + 1,
      itemBuilder: (context, index) {
        if (index == _optimizedRoutes.length) {
          return const SizedBox(height: AppSpacing.bottomNavClearance);
        }
        final route = _optimizedRoutes[index];
        return _OptimizedRouteCard(route: route, index: index + 1);
      },
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.spaceXl),
            Text(
              'All settled up!',
              style: AppTypography.h3.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.spaceMd),
            Text(
              'No outstanding balances with anyone',
              style: AppTypography.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalancesList() {
    final owedToYou = _balances.where((b) => b.theyOweYou).toList();
    final youOwe = _balances.where((b) => b.youOweThem).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
      children: [
        if (owedToYou.isNotEmpty) ...[
          _buildSectionHeader('Owed to you', AppColors.success),
          const SizedBox(height: AppSpacing.spaceMd),
          ...owedToYou.map((b) => _BalanceCard(balance: b, key: ValueKey(b.contactPhone))),
          const SizedBox(height: AppSpacing.space2xl),
        ],
        if (youOwe.isNotEmpty) ...[
          _buildSectionHeader('You owe', AppColors.debtRed),
          const SizedBox(height: AppSpacing.spaceMd),
          ...youOwe.map((b) => _BalanceCard(balance: b, key: ValueKey(b.contactPhone))),
        ],
        const SizedBox(height: AppSpacing.bottomNavClearance),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.spaceMd),
        Text(
          title,
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatefulWidget {
  final GlobalBalance balance;

  const _BalanceCard({super.key, required this.balance});

  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.balance;
    final isPositive = b.theyOweYou;
    final amountColor = isPositive ? AppColors.success : AppColors.debtRed;
    final amountPrefix = isPositive ? '+' : '-';
    final amountDisplay = (b.netBalanceMinor.abs() / 100).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: b.breakdown.length > 1
                ? () => setState(() => _expanded = !_expanded)
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Row(
                children: [
                  MemberAvatar(
                    name: b.contactName,
                    photoURL: b.contactPhotoURL,
                    size: 44,
                  ),
                  const SizedBox(width: AppSpacing.spaceXl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.contactName,
                          style: AppTypography.listItemTitle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${b.groupCount} group${b.groupCount == 1 ? '' : 's'}',
                          style: AppTypography.captionSmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$amountPrefix₹$amountDisplay',
                        style: AppTypography.h3.copyWith(
                          color: amountColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        isPositive ? 'owes you' : 'you owe',
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  if (b.breakdown.length > 1) ...[
                    const SizedBox(width: AppSpacing.spaceMd),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_expanded && b.breakdown.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.cardPadding,
                AppSpacing.spaceMd,
                AppSpacing.cardPadding,
                AppSpacing.cardPadding,
              ),
              child: Column(
                children: b.breakdown.map((c) {
                  final cPositive = c.balanceMinor > 0;
                  final cColor = cPositive ? AppColors.success : AppColors.debtRed;
                  final cPrefix = cPositive ? '+' : '-';
                  final cAmount = (c.balanceMinor.abs() / 100).toStringAsFixed(0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
                    child: Row(
                      children: [
                        Icon(
                          Icons.group_outlined,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: AppSpacing.spaceMd),
                        Expanded(
                          child: Text(
                            c.groupName,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          '$cPrefix₹$cAmount',
                          style: AppTypography.caption.copyWith(
                            color: cColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptimizedRouteCard extends StatelessWidget {
  final OptimizedRoute route;
  final int index;

  const _OptimizedRouteCard({required this.route, required this.index});

  @override
  Widget build(BuildContext context) {
    final repo = CycleRepository.instance;
    final fromIdentity = IdentityService.instance.getIdentity(route.fromPhone);
    final toIdentity = IdentityService.instance.getIdentity(route.toPhone);
    
    final isYouPaying = route.fromPhone == IdentityService.normalizePhone(repo.currentUserPhone);
    final isYouReceiving = route.toPhone == IdentityService.normalizePhone(repo.currentUserPhone);
    
    final fromName = isYouPaying ? 'You' : (fromIdentity?.displayName ?? route.fromPhone);
    final toName = isYouReceiving ? 'You' : (toIdentity?.displayName ?? route.toPhone);
    final amountDisplay = (route.amountMinor / 100).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.spaceMd),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.accentBackground,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: AppTypography.caption.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.spaceXl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: AppTypography.bodyPrimary,
                    children: [
                      TextSpan(
                        text: fromName,
                        style: TextStyle(
                          fontWeight: isYouPaying ? FontWeight.w600 : FontWeight.w400,
                          color: isYouPaying ? AppColors.debtRed : AppColors.textPrimary,
                        ),
                      ),
                      const TextSpan(text: ' pays '),
                      TextSpan(
                        text: toName,
                        style: TextStyle(
                          fontWeight: isYouReceiving ? FontWeight.w600 : FontWeight.w400,
                          color: isYouReceiving ? AppColors.success : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Direct settlement',
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹$amountDisplay',
            style: AppTypography.h3.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
