import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../services/connectivity_service.dart';

class OfflineBanner extends StatelessWidget {
  final String? customMessage;
  final VoidCallback? onRetry;

  const OfflineBanner({
    super.key,
    this.customMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ConnectivityService.instance,
      builder: (context, _) {
        if (ConnectivityService.instance.isOnline) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.warningBackground,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    customMessage ?? 'Offline — showing last known state',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (onRetry != null)
                  GestureDetector(
                    onTap: onRetry,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        'Retry',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
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

class OfflineAwareScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final VoidCallback? onRetry;

  const OfflineAwareScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.backgroundColor,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor ?? AppColors.background,
      floatingActionButton: floatingActionButton,
      body: Column(
        children: [
          OfflineBanner(onRetry: onRetry),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class OfflineDisabledButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String disabledTooltip;
  final ButtonStyle? style;

  const OfflineDisabledButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.disabledTooltip = 'Not available offline',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ConnectivityService.instance,
      builder: (context, _) {
        final isOffline = ConnectivityService.instance.isOffline;
        
        if (isOffline) {
          return Tooltip(
            message: disabledTooltip,
            child: ElevatedButton(
              onPressed: null,
              style: style,
              child: child,
            ),
          );
        }

        return ElevatedButton(
          onPressed: onPressed,
          style: style,
          child: child,
        );
      },
    );
  }
}

class OfflineDisabledIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String disabledTooltip;
  final Color? color;
  final double? iconSize;

  const OfflineDisabledIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.disabledTooltip = 'Not available offline',
    this.color,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ConnectivityService.instance,
      builder: (context, _) {
        final isOffline = ConnectivityService.instance.isOffline;
        
        return Tooltip(
          message: isOffline ? disabledTooltip : '',
          child: IconButton(
            onPressed: isOffline ? null : onPressed,
            icon: Icon(icon),
            color: isOffline ? AppColors.textTertiary : color,
            iconSize: iconSize,
          ),
        );
      },
    );
  }
}
