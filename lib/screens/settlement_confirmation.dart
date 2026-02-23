import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../design/typography.dart';
import '../models/models.dart';
import '../repositories/cycle_repository.dart';
import '../services/razorpay_order_service.dart';
import '../utils/route_args.dart';

class SettlementConfirmation extends StatefulWidget {
  const SettlementConfirmation({super.key});

  @override
  State<SettlementConfirmation> createState() => _SettlementConfirmationState();
}

class _SettlementConfirmationState extends State<SettlementConfirmation> {
  late final Razorpay _razorpay;
  bool _paymentInProgress = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (!mounted) return;
    setState(() => _paymentInProgress = false);
    final group = RouteArgs.getGroup(context);
    if (group != null) {
      Navigator.pushReplacementNamed(context, '/payment-result', arguments: group);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _paymentInProgress = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.message ?? 'Payment failed'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() => _paymentInProgress = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opened ${response.walletName ?? 'external app'}. Complete payment there.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _startRazorpayCheckout(Group group, int amountPaise) async {
    const minPaise = 100;
    final safeAmountPaise = amountPaise < minPaise ? minPaise : amountPaise;
    setState(() => _paymentInProgress = true);
    try {
      final result = await createRazorpayOrder(
        amountPaise: safeAmountPaise,
        receipt: 'expenso_${group.id}_${DateTime.now().millisecondsSinceEpoch}',
      );
      final options = <String, dynamic>{
        'key': result.keyId,
        'amount': safeAmountPaise,
        'currency': 'INR',
        'name': 'Expenso',
        'description': 'Settlement',
        'order_id': result.orderId,
      };
      _razorpay.open(options);
    } catch (e) {
      if (!mounted) return;
      setState(() => _paymentInProgress = false);
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open payment: $msg'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  static String _formatAmount(double n) {
    return n.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    final group = RouteArgs.getGroup(context);
    if (group == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).maybePop());
      return const Scaffold(body: SizedBox.shrink());
    }
    final method = RouteArgs.getSettlementMethod(context) ?? 'system';
    final isRazorpay = method == 'razorpay';
    final repo = CycleRepository.instance;
    final transfers = isRazorpay ? repo.getSettlementTransfersForCurrentUser(group.id) : null;
    final totalDue = transfers != null ? transfers.fold<double>(0, (s, t) => s + t.amount) : 0.0;
    final hasDues = totalDue >= 0.01;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left, size: 24),
                    color: const Color(0xFF1A1A1A),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₹${isRazorpay && hasDues ? _formatAmount(totalDue) : _formatAmount(group.amount)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -1.2,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isRazorpay && hasDues ? 'Your dues' : 'Cycle total',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _subtitleText(method, isRazorpay, hasDues),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF6B6B6B),
                          height: 1.5,
                        ),
                      ),
                      if (isRazorpay && transfers != null && transfers.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        ...transfers.map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  t.creditorDisplayName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                Text(
                                  '₹${_formatAmount(t.amount)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      _buildPendingSettlements(group.id, isRazorpay),
                      const SizedBox(height: 48),
                      _buildActions(
                        context,
                        group: group,
                        method: method,
                        isRazorpay: isRazorpay,
                        hasDues: hasDues,
                        totalDue: totalDue,
                        onPayPressed: () => _startRazorpayCheckout(group, (totalDue * 100).round()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitleText(String method, bool isRazorpay, bool hasDues) {
    if (isRazorpay) {
      if (hasDues) return 'Pay securely via card, UPI, or net banking.';
      return 'You have nothing to pay this cycle.';
    }
    if (method == 'upi') return 'You will be redirected to complete payment via UPI.';
    return 'This will close the current cycle. All pending balances will be cleared.';
  }

  Widget _buildActions(
    BuildContext context, {
    required Group group,
    required String method,
    required bool isRazorpay,
    required bool hasDues,
    required double totalDue,
    required VoidCallback onPayPressed,
  }) {
    final isCreator = CycleRepository.instance.isCurrentUserCreator(group.id);

    if (isRazorpay) {
      return Column(
        children: [
          if (hasDues)
            ElevatedButton(
              onPressed: _paymentInProgress ? null : onPayPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                minimumSize: const Size(double.infinity, 0),
              ),
              child: Text(
                _paymentInProgress ? 'Opening…' : 'Pay ₹${_formatAmount(totalDue)}',
                style: AppTypography.button,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'You’re all settled for this cycle.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Color(0xFF6B6B6B)),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A1A1A),
              side: const BorderSide(color: Color(0xFFE5E5E5)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              minimumSize: const Size(double.infinity, 0),
            ),
            child: const Text('Back', style: AppTypography.button),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (isCreator)
          ElevatedButton(
            onPressed: () {
              CycleRepository.instance.settleAndRestartCycle(group.id);
              Navigator.pushReplacementNamed(context, '/payment-result', arguments: group);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              minimumSize: const Size(double.infinity, 0),
            ),
            child: Text(
              method == 'upi' ? 'Continue to Payment' : 'Close Cycle',
              style: AppTypography.button,
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Only the group creator can close the cycle.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Color(0xFF6B6B6B)),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1A1A1A),
            side: const BorderSide(color: Color(0xFFE5E5E5)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            minimumSize: const Size(double.infinity, 0),
          ),
          child: const Text('Cancel', style: AppTypography.button),
        ),
      ],
    );
  }

  Widget _buildPendingSettlements(String groupId, bool isRazorpay) {
    final instructions = CycleRepository.instance.getSettlementInstructions(groupId);
    if (instructions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PENDING SETTLEMENTS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF9B9B9B),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          ...instructions.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                line,
                style: TextStyle(
                  fontSize: 15,
                  color: const Color(0xFF1A1A1A),
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
