import 'package:flutter/material.dart';

import 'package:yomou/core/theme/amoled.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';
import 'package:yomou/widgets/cached_manga_image.dart';

/// Kotatsu's "Content unavailable" sheet: shown when a manga's source is not
/// installed at all (a Kotatsu/Tachiyomi import leftover), the case where the
/// chapter list can do nothing but report a missing source.
///
/// The reader gets a real choice instead of a dead-end line: find the same
/// work on another source, or close. Genuine load failures (timeouts,
/// captchas, titles removed from the source) never reach this dialog -- those
/// keep the plain error text, because collapsing them into "missing source"
/// hides the real cause (see `mangaDetailChapterFailure`).
///
/// Resolves `true` when the reader chooses "Find on other sources", `null`
/// when dismissed, so the caller can open the Alternatives search.
Future<bool?> showContentUnavailableDialog(
  BuildContext context, {
  required String imageUrl,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _ContentUnavailableDialog(imageUrl: imageUrl),
  );
}

class _ContentUnavailableDialog extends StatelessWidget {
  const _ContentUnavailableDialog({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: dark ? amoled(context, 0xFF2C2C2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedMangaImage(
                    imageUrl: imageUrl,
                    width: 96,
                    height: 136,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: scheme.error,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: dark ? amoled(context, 0xFF2C2C2E) : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.priority_high_rounded,
                      size: 13,
                      color: scheme.onError,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              l.contentUnavailable,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: dark
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l.contentUnavailableBody1,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: dark ? Colors.white60 : const Color(0xFF49454F),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.contentUnavailableBody2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: dark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text(
                  l.findOnOtherSources,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  l.close,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}