import 'package:flutter/material.dart';

class EmptyStates extends StatelessWidget {
  final String type; // 'no-groups', 'no-expenses', 'new-cycle', 'no-expenses-new-cycle'
  /// For 'no-groups': called when the main action button is pressed. If null, navigates to '/create-group'.
  final VoidCallback? onActionPressed;
  /// When false, 'no-groups' returns only the inner content (no Scaffold) for use as body of parent Scaffold.
  final bool wrapInScaffold;

  const EmptyStates({
    super.key,
    this.type = 'no-groups',
    this.onActionPressed,
    this.wrapInScaffold = true,
  });

  @override
  Widget build(BuildContext context) {
    if (type == 'no-groups') {
      final Widget content = SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 40, 24, 32),
              child: Text(
                'Groups',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.6,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 96),
                  child: SizedBox(
                    width: 280,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No groups yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Create a group to start tracking shared expenses with automatic settlement cycles.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: const Color(0xFF6B6B6B),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: onActionPressed ?? () => Navigator.pushNamed(context, '/create-group'),
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
                            'Create Group',
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
          ],
        ),
      );
      if (!wrapInScaffold) return content;
      return Scaffold(
        backgroundColor: const Color(0xFFF7F7F8),
        body: content,
      );
    }

    if (type == 'no-expenses') {
      return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
            child: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No expenses yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add expenses as they occur. The group will settle at the end of the cycle.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: const Color(0xFF6B6B6B),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }

    if (type == 'new-cycle') {
      return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
            child: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'New cycle started',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Previous cycle is settled. Add new expenses for this cycle.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: const Color(0xFF6B6B6B),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }

    if (type == 'no-expenses-new-cycle') {
      return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
            child: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No expenses yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the button below to start the cycle!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: const Color(0xFF6B6B6B),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }

    return const SizedBox.shrink();
  }
}
