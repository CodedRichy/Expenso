import 'package:flutter/material.dart';
import '../utils/route_args.dart';

class PaymentResult extends StatelessWidget {
  final String status; // 'success', 'failed', 'cancelled'
  final double? amount;
  final String? transactionId;

  const PaymentResult({
    super.key,
    this.status = 'success',
    this.amount,
    this.transactionId,
  });

  @override
  Widget build(BuildContext context) {
    final group = RouteArgs.getGroup(context);
    if (group == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).maybePop());
      return const Scaffold(body: SizedBox.shrink());
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: status == 'success' ? const Color(0xFF1A1A1A) : const Color(0xFFE5E5E5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      status == 'success'
                          ? Icons.check
                          : status == 'failed'
                              ? Icons.error_outline
                              : Icons.close,
                      color: status == 'success' ? Colors.white : const Color(0xFF6B6B6B),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Column(
                    children: [
                      Text(
                        status == 'success'
                            ? 'Payment successful'
                            : status == 'failed'
                                ? 'Payment failed'
                                : 'Payment cancelled',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (status == 'success' && amount != null) ...[
                        Text(
                          '₹${amount!.toStringAsFixed(0).replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]},',
                          )} transferred',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            color: const Color(0xFF6B6B6B),
                          ),
                        ),
                        if (transactionId != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Transaction ID: $transactionId',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color(0xFF9B9B9B),
                            ),
                          ),
                        ],
                      ],
                      if (status == 'failed')
                        Text(
                          'The transaction could not be completed',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            color: const Color(0xFF6B6B6B),
                          ),
                        ),
                      if (status == 'cancelled')
                        Text(
                          'No amount was transferred',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            color: const Color(0xFF6B6B6B),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                          context,
                          '/cycle-settled',
                          arguments: group,
                        );
                      },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 0),
                    ),
                    child: Text(
                      status == 'success' ? 'Done' : 'Close',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
