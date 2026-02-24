import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../services/sync_status_service.dart';

class SyncStatusIndicator extends StatelessWidget {
  final bool compact;

  const SyncStatusIndicator({super.key, this.compact = true});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SyncStatusService.instance,
      builder: (context, _) {
        final service = SyncStatusService.instance;
        
        if (compact) {
          return _buildCompact(service);
        }
        return _buildFull(service);
      },
    );
  }

  Widget _buildCompact(SyncStatusService service) {
    final (IconData icon, Color color, String tooltip) = switch (service.status) {
      SyncStatus.synced => (Icons.cloud_done_outlined, AppColors.success, 'Synced ${service.lastSyncDisplay}'),
      SyncStatus.syncing => (Icons.sync, AppColors.accent, 'Syncing...'),
      SyncStatus.offline => (Icons.cloud_off_outlined, AppColors.warning, 'Offline'),
      SyncStatus.error => (Icons.cloud_off, AppColors.error, 'Sync error'),
    };

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: service.isSyncing
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            : Icon(icon, size: 16, color: color),
      ),
    );
  }

  Widget _buildFull(SyncStatusService service) {
    final (IconData icon, Color color, String text) = switch (service.status) {
      SyncStatus.synced => (Icons.cloud_done_outlined, AppColors.success, 'Last synced ${service.lastSyncDisplay}'),
      SyncStatus.syncing => (Icons.sync, AppColors.accent, 'Syncing...'),
      SyncStatus.offline => (Icons.cloud_off_outlined, AppColors.warning, 'Offline — using cached data'),
      SyncStatus.error => (Icons.cloud_off, AppColors.error, 'Sync error'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceLg,
        vertical: AppSpacing.spaceMd,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          service.isSyncing
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.spaceMd),
          Text(
            text,
            style: AppTypography.captionSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
