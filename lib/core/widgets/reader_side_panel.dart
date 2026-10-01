import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:yomou/core/widgets/ios/ios_sheet.dart';
import 'package:yomou/core/widgets/responsive.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// Width bounds for a reader side panel on a wide window.
///
/// A third of the window, within limits. The lower bound is what a chapter row
/// needs for its number and title to sit on one line; the upper bound stops the
/// panel from becoming a column of stretched text on a 2560px monitor. A window
/// narrower than three times the upper bound simply gets a proportionally
/// narrower panel.
const double kSidePanelMinWidth = 360;
const double kSidePanelMaxWidth = 460;

/// Presents [builder] as a panel anchored to the right edge on a wide window,
/// and as a bottom sheet on a phone.
///
/// The two are different presentations of the same content, not two content
/// sets. A centred dialog over a full-bleed page is the wrong shape on a
/// desktop: it covers the page you are reading to change a setting about the
/// page you are reading, and a bottom sheet that stops short of the full width
/// leaves the two halves of the screen unrelated to each other. Anchoring to
/// the right keeps the page visible on the left and puts the controls in the
/// column a side panel is expected to occupy.
///
/// On a phone this is [showIosSheet] unchanged -- the app's one bottom sheet,
/// with its grabber and its top-only rounding. A panel the width of the screen
/// would just be a full-screen page with extra steps, and the bottom sheet is
/// the platform's own answer.
Future<T?> showReaderSidePanel<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  if (!usesWideLayout(context)) {
    return showIosSheet<T>(
      context,
      isScrollControlled: isScrollControlled,
      builder: builder,
    );
  }

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    // Long enough to read as the panel arriving rather than appearing, short
    // enough not to be in the way of a control someone is reaching for.
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _SidePanelShell(
        title: title,
        child: Builder(builder: builder),
      );
    },
    // Slides in from the right edge, which is the edge it is anchored to, and
    // fades rather than scaling: the panel's width does not change, only its
    // position, so a scale would imply a resize that never happens.
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

/// The panel itself. Full height, fixed width, anchored right.
class _SidePanelShell extends StatelessWidget {
  const _SidePanelShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final panelWidth = (width / 3).clamp(
      kSidePanelMinWidth,
      kSidePanelMaxWidth,
    );

    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: panelWidth,
        height: MediaQuery.sizeOf(context).height,
        child: Material(
          color: dark ? const Color(0xFF1C1C1E) : Colors.white,
          // Rounded on the left only: the right edge is the screen edge, so a
          // corner there would be a radius around nothing.
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
          ),
          // The panel sits over a page, so it needs to read as a layer above it
          // rather than as part of the same plane.
          elevation: 16,
          shadowColor: Colors.black54,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SidePanelHeader(title: title),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidePanelHeader extends StatelessWidget {
  const _SidePanelHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 20, right: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: Icon(RemixIcons.close_line, size: 22),
            color: cs.onSurfaceVariant,
            tooltip: AppLocalizations.of(context).close,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
