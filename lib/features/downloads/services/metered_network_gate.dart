import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/storage/storage_stats.dart';
import 'package:yomou/features/settings/providers/download_settings_provider.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// What the user chose at the cellular-download prompt.
enum MeteredDecision {
  /// "Allow always" — persists [kNetworkAllow].
  always,

  /// "Allow once" — this download only, leaves the setting untouched.
  once,

  /// "Don't allow" — persists [kNetworkDeny].
  never,
}

/// Result of [askAboutMeteredDownload]: whether the download may proceed.
typedef MeteredVerdict = ({bool allowed, MeteredDecision decision});

/// Resolves whether a download may use mobile data, prompting when the
/// "Downloading over cellular network" setting is "Ask every time".
///
/// Mirrors Kotatsu's `AppRouter.askForDownloadOverMeteredNetwork`:
///
/// * "Allow" — proceeds without a prompt.
/// * "Don't allow" — refused, also persisted so it stops asking.
/// * "Ask every time" — prompts *only* when the active network is actually
///   metered, so it never interrupts you on Wi-Fi. "Allow always" and
///   "Don't allow" both write the answer back to the setting; "Allow once"
///   is the only non-destructive choice, applying to that download alone.
///
/// Returns `null` when the prompt is dismissed, so callers can treat that as
/// a refusal.
Future<MeteredVerdict?> askAboutMeteredDownload(
  BuildContext context,
  WidgetRef ref,
) async {
  final policy = ref.read(downloadSettingsProvider).cellularNetwork;

  if (policy == kNetworkAllow) {
    return (allowed: true, decision: MeteredDecision.always);
  }
  if (policy == kNetworkDeny) {
    return (allowed: false, decision: MeteredDecision.never);
  }

  // kNetworkAsk — never interrupt on Wi-Fi or unmetered connections.
  if (!await isActiveNetworkMetered()) {
    return (allowed: true, decision: MeteredDecision.once);
  }
  if (!context.mounted) return null;

  final decision = await showDialog<MeteredDecision>(
    context: context,
    builder: (context) => const _MeteredDownloadDialog(),
  );
  if (decision == null) return null;

  // Only the one-off answer stays local; the other two persist so the user
  // isn't asked again after choosing.
  switch (decision) {
    case MeteredDecision.always:
      await ref
          .read(downloadSettingsProvider.notifier)
          .setCellularNetwork(kNetworkAllow);
    case MeteredDecision.never:
      await ref
          .read(downloadSettingsProvider.notifier)
          .setCellularNetwork(kNetworkDeny);
    case MeteredDecision.once:
      break;
  }
  return (
    allowed: decision != MeteredDecision.never,
    decision: decision,
  );
}

/// Yomou-styled prompt shown before a download starts on mobile data.
class _MeteredDownloadDialog extends StatelessWidget {
  const _MeteredDownloadDialog();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      icon: Icon(RemixIcons.signal_wifi_line, color: cs.primary, size: 28),
      title: Text(
        l.dlsCellularConfirmTitle,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      content: Text(
        l.dlsCellularConfirmBody,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, height: 1.4, color: cs.onSurfaceVariant),
      ),
      actions: [
        _DialogAction(
          label: l.dlsCellularAllowOnce,
          color: cs.onSurfaceVariant,
          onTap: () => Navigator.pop(context, MeteredDecision.once),
        ),
        _DialogAction(
          label: l.dlsCellularDontAllow,
          color: cs.onSurfaceVariant,
          onTap: () => Navigator.pop(context, MeteredDecision.never),
        ),
        _DialogAction(
          label: l.dlsCellularAllowAlways,
          color: cs.primary,
          emphasis: true,
          onTap: () => Navigator.pop(context, MeteredDecision.always),
        ),
      ],
    );
  }
}

/// One full-width pill button in the dialog's action row.
class _DialogAction extends StatelessWidget {
  const _DialogAction({
    required this.label,
    required this.color,
    required this.onTap,
    this.emphasis = false,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  /// Draws the accent-tinted fill used for the affirmative choice.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: emphasis
              ? color.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
