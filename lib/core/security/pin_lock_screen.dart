import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/security/app_lock.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// Numeric keypad + PIN dots. Calls [onVerify] when 4 digits are entered; on a
/// true return it invokes [onSuccess], otherwise it clears and shows [_error].
class PinEntryView extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool Function(String pin) onVerify;
  final ValueChanged<String> onSuccess;
  final VoidCallback? onCancel;

  const PinEntryView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onVerify,
    required this.onSuccess,
    this.onCancel,
  });

  static const pinLength = 4;

  @override
  State<PinEntryView> createState() => _PinEntryViewState();
}

class _PinEntryViewState extends State<PinEntryView> {
  String _pin = '';
  bool _error = false;

  void _add(String digit) {
    if (_pin.length >= PinEntryView.pinLength) return;
    setState(() {
      _pin += digit;
      _error = false;
    });
    if (_pin.length < PinEntryView.pinLength) return;
    if (widget.onVerify(_pin)) {
      widget.onSuccess(_pin);
    } else {
      setState(() {
        _error = true;
        _pin = '';
      });
    }
  }

  void _remove() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        cs.brightness == Brightness.dark
            ? const Color(0xFF232326)
            : const Color(0xFFF0F1F5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Icon(RemixIcons.lock_line, color: cs.primary, size: 36),
        const SizedBox(height: 12),
        Text(
          widget.title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          widget.subtitle,
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < PinEntryView.pinLength; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length
                      ? cs.primary
                      : (dark ? Colors.white24 : Colors.black12),
                ),
              ),
          ],
        ),
        if (_error) ...[
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context).appLockWrongPin,
            style: TextStyle(color: cs.error, fontSize: 13),
          ),
        ],
        const SizedBox(height: 20),
        _buildKeypad(cs, dark, bg),
        if (widget.onCancel != null) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: widget.onCancel,
            child: Text(AppLocalizations.of(context).appLockCancel),
          ),
        ],
      ],
    );
  }

  Widget _buildKeypad(ColorScheme cs, bool dark, Color bg) {
    Widget key(String label) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Material(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _add(label),
                child: SizedBox(
                  height: 56,
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [key('1'), key('2'), key('3')]),
        Row(children: [key('4'), key('5'), key('6')]),
        Row(children: [key('7'), key('8'), key('9')]),
        Row(
          children: [
            Expanded(child: Container()),
            key('0'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Material(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _remove,
                    child: const SizedBox(
                      height: 56,
                      child: Center(
                        child: Icon(
                          RemixIcons.delete_back_2_line,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Full-screen lock overlay shown above every route when the app is locked.
class PinLockScreen extends ConsumerWidget {
  const PinLockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final controller = ref.read(appLockProvider.notifier);
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Center(
            child: SingleChildScrollView(
              child: PinEntryView(
                title: l.appLockEnterTitle,
                subtitle: l.appLockEnterSubtitle,
                onVerify: controller.verify,
                onSuccess: (_) => controller.setLocked(false),
              ),
            ),
          ),
        ),
      ),
    );
  }
}