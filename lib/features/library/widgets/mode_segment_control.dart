import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// How many places the detail list can be in. Fixed at three: Chapters, Pages,
/// Bookmarks.
const int kModeSegmentCount = 3;

/// The indicator's travel. Shared by the indicator and the labels it moves
/// under, so the two never fall out of step.
const Duration kModeSegmentSlide = Duration(milliseconds: 220);
const Curve kModeSegmentCurve = Curves.easeOutCubic;

/// Where the mode control's indicator sits when [activeTab] is the selected one
/// out of [tabs].
///
/// The indicator is a segment wide and slides between fixed stops across the
/// track, so what it needs is the fraction of the track's free space it should
/// sit at -- -1 at the left, 0 in the middle, 1 at the right -- which is what
/// `Alignment.x` means. Kept out of the widget rather than inlined so the
/// arithmetic can be pinned by a test: an indicator that lands under the wrong
/// label is the kind of bug that reads as a styling choice and survives review.
Alignment modeSegmentIndicatorAlignment(int activeTab, int tabs) {
  if (tabs <= 1) return Alignment.center;
  final index = activeTab.clamp(0, tabs - 1);
  return Alignment(-1 + (index / (tabs - 1)) * 2, 0);
}

/// The detail pane's mode control: one track, one background, one indicator
/// that slides between Chapters, Pages and Bookmarks.
///
/// One component rather than three buttons in a row. Three chips that each
/// light themselves up is a row of buttons however it is dressed; it is the
/// movement of a single indicator between positions that makes this read as one
/// switch, and the travel is also what tells the eye where the selection went
/// when it changes.
///
/// Labelled rather than icon-only, because the pane has the width and because
/// the middle one is easy to misread: it shows the pages of the chapter you are
/// on, not a grid of chapters.
///
/// The active fill is a plain white pill on a deliberately darkened track.
/// White on the untinted M3 container is real but quiet -- the container roles
/// only reach surfaceContainerHighest, which is a step off white, enough to see
/// a pill but not enough to see a *selection*. Tinting the pill instead was
/// tried and dropped: it moves the fill in hue but keeps it at almost the same
/// lightness as the track, so it reads as a coloured patch rather than a raised
/// one. Darkening the track buys the contrast in the one channel that makes a
/// toggle legible, and leaves the fill free to be plain white.
class ModeSegmentControl extends StatelessWidget {
  const ModeSegmentControl({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
    this.unreadCount = 0,
    this.badge,
  });

  final int activeTab;
  final ValueChanged<int> onTabSelected;

  /// Unread chapters, shown on the Chapters segment. Zero hides the badge.
  final int unreadCount;

  /// Overrides the default unread badge. The badge is a slot because the tray's
  /// icon tabs next to this control wear the same one, and there is no sense in
  /// building it twice.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final segments = <Widget>[
      _buildSegment(
        icon: RemixIcons.list_unordered,
        label: l.detailTabChapters,
        active: activeTab == 0,
        scheme: scheme,
        onTap: () => onTabSelected(0),
        badge: unreadCount > 0 ? (badge ?? _UnreadBadge(unreadCount)) : null,
      ),
      _buildSegment(
        icon: RemixIcons.grid_line,
        label: l.detailTabPages,
        active: activeTab == 1,
        scheme: scheme,
        onTap: () => onTabSelected(1),
      ),
      _buildSegment(
        icon: RemixIcons.bookmark_2_line,
        label: l.bookmarks,
        active: activeTab == 2,
        scheme: scheme,
        onTap: () => onTabSelected(2),
      ),
    ];
    return Container(
      key: const ValueKey('modeSegmentTrack'),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        // The track has to be a real container for the pill to float in. The
        // M3 containers top out at surfaceContainerHighest, which is a step off
        // white -- enough to see a pill, not enough to see a *selection*. A
        // little black under it buys the difference, and only in light: in dark
        // the track is already far below the fill and darkening it further
        // would only muddy it.
        color: dark
            ? scheme.surfaceContainerHighest
            : Color.alphaBlend(
                Colors.black.withValues(alpha: 0.07),
                scheme.surfaceContainerHighest,
              ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        // The indicator spills a pixel or two past the track's inner edge and
        // must not be cut off; the track's own padding absorbs the rest.
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              duration: kModeSegmentSlide,
              curve: kModeSegmentCurve,
              alignment: modeSegmentIndicatorAlignment(
                activeTab,
                kModeSegmentCount,
              ),
              child: FractionallySizedBox(
                widthFactor: 1 / kModeSegmentCount,
                heightFactor: 1,
                child: DecoratedBox(
                  key: const ValueKey('modeSegmentIndicator'),
                  decoration: BoxDecoration(
                    // A raised pill on the track, which is how the reference
                    // reads: something floating inside a container rather than
                    // three segments that happen to touch. White on the grey
                    // track in light, a lift off the track in dark -- the
                    // indicator has to be lighter than what it sits on for the
                    // "pressed" read to survive, whatever the hue.
                    color: dark
                        ? Colors.white.withValues(alpha: 0.30)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    // The shadow is what turns a flat rectangle into a floating
                    // pill; without it a white fill on a light track is a patch
                    // of slightly different grey. Soft and warm, not a hard
                    // drop -- this is a toggle, not a card.
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: dark ? 0.40 : 0.18),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final segment in segments) Expanded(child: segment),
            ],
          ),
        ],
      ),
    );
  }

  /// One segment: a label and its icon.
  ///
  /// The selected state lives on the indicator behind it, so this only has to
  /// decide how loudly to say its own name -- and to animate that, so the label
  /// and the indicator arrive together rather than in two beats.
  Widget _buildSegment({
    required IconData icon,
    required String label,
    required bool active,
    required ColorScheme scheme,
    required VoidCallback onTap,
    Widget? badge,
  }) {
    final dark = scheme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: active ? 1 : 0),
        duration: kModeSegmentSlide,
        curve: kModeSegmentCurve,
        builder: (context, t, _) {
          final fg = Color.lerp(
            scheme.onSurfaceVariant,
            dark ? Colors.white : scheme.onSurface,
            t,
          )!;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: fg, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg,
                          fontSize: 13,
                          fontWeight: FontWeight.lerp(
                            FontWeight.w500,
                            FontWeight.w700,
                            t,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // The unread count rides the segment rather than the icon, so
                // it sits at the segment's corner and stays legible whether the
                // indicator is under it or not.
                if (badge != null) Positioned(top: -9, right: 6, child: badge),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The default unread-count pip, used when the caller does not supply one.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
