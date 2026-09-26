import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yomou/data/providers/sources_provider.dart';
import 'package:yomou/data/sources/source_network.dart';
import 'package:yomou/features/source_management/screens/source_sign_in_screen.dart';
import 'package:yomou/features/source_management/services/source_tester.dart';
import 'package:yomou/l10n/generated/app_localizations.dart';

/// Per-source settings (the "Kotatsu-style" source settings): domain override,
/// user-agent override, in-app sign-in with cookie capture, cookie clearing,
/// CAPTCHA handling toggles, download slowdown and open-in-browser.
class SourceSettingsScreen extends ConsumerStatefulWidget {
  final String sourceId;
  final String sourceName;

  const SourceSettingsScreen({
    super.key,
    required this.sourceId,
    required this.sourceName,
  });

  @override
  ConsumerState<SourceSettingsScreen> createState() =>
      _SourceSettingsScreenState();
}

class _SourceSettingsScreenState extends ConsumerState<SourceSettingsScreen> {
  SourceNetworkConfig? _config;
  String? _defaultUa;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final config = await SourceNetworkConfig.forSource(widget.sourceId);
    final source = getSourceByName(widget.sourceName);
    final ua = source.headers?['User-Agent'];
    if (!mounted) return;
    setState(() {
      _config = config;
      _defaultUa = ua;
    });
  }

  AppLocalizations get _l => AppLocalizations.of(context);

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _editText({
    required String title,
    required String initial,
    required String hint,
    required Future<void> Function(String? value) onSave,
    bool resetOnEmpty = false,
  }) async {
    final controller = TextEditingController(text: initial);
    final dark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dark ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          title,
          style: TextStyle(
            color: dark ? Colors.white : const Color(0xFF1C1B1F),
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: dark ? Colors.white : const Color(0xFF1C1B1F)),
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, '__reset__'),
            child: Text(_l.reset),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(_l.save),
          ),
        ],
      ),
    );
    if (result == null) return;
    if (result == '__reset__') {
      await onSave(null);
      await _reload();
      return;
    }
    final value = result.trim();
    if (value.isEmpty && !resetOnEmpty) return;
    await onSave(value);
    await _reload();
  }

  Future<void> _startSignIn() async {
    final url = _config?.baseUrlOverride ?? _domainForFallback();
    final header = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => SourceSignInScreen(
          sourceId: widget.sourceId,
          sourceName: widget.sourceName,
          initialUrl: url,
        ),
      ),
    );
    await _reload();
    if (header != null && header.isNotEmpty) {
      _toast(_l.sourceAuthorized);
    }
  }

  String _domainForFallback() {
    final source = getSourceByName(widget.sourceName);
    return source.baseUrl;
  }

  Future<void> _openInBrowser() async {
    final url = _config?.baseUrlOverride ?? _domainForFallback();
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Widget _chevron() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Icon(
      RemixIcons.arrow_right_s_line,
      size: 20,
      color: dark ? Colors.white30 : Colors.black26,
    );
  }

  // Runs the source's real request plus one browse call and shows what the
  // server answered, so a dead source is distinguishable from a broken parser
  // without any host machine.
  Future<void> _runTest() async {
    if (_testing) return;
    setState(() => _testing = true);
    final source = getSourceBySourceId(widget.sourceId);
    SourceTestResult? result;
    if (source == null) {
      _toast(_l.sourceTestUnknown);
    } else {
      result = await testMangaSource(source);
    }
    if (!mounted) return;
    setState(() => _testing = false);
    if (result != null) _showTestResult(result);
  }

  void _showTestResult(SourceTestResult r) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ok = r.reachable;
    final color = ok
        ? const Color(0xFF2E7D32)
        : (r.blocked ? const Color(0xFFC62828) : const Color(0xFFE65100));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: dark ? const Color(0xFF1C1C1E) : Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        ok
                            ? RemixIcons.check_double_fill
                            : RemixIcons.alert_fill,
                        color: Color(color.toARGB32()),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        r.verdict,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(color.toARGB32()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _testLine('HTTP', r.status?.toString() ?? '—'),
                  _testLine('Time', '${r.elapsedMs} ms'),
                  if (r.contentType != null)
                    _testLine('Type', r.contentType!),
                  if (r.server != null) _testLine('Server', r.server!),
                  if (r.listingCount != null)
                    _testLine(
                      AppLocalizations.of(sheetContext).sourceTestTitles,
                      '${r.listingCount}',
                    ),
                  if (r.error != null)
                    _testLine(
                      AppLocalizations.of(sheetContext).sourceTestError,
                      r.error!,
                    ),
                  const SizedBox(height: 10),
                  Text(
                    r.url,
                    style: TextStyle(
                      fontSize: 12,
                      color: dark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  if (r.bodyHead.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: dark ? Colors.black26 : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        r.bodyHead,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          height: 1.35,
                          color: dark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _testLine(String label, String value) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: dark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: dark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final charcoal = dark ? Colors.white : const Color(0xFF1C1B1F);
    final muted = dark ? Colors.white54 : const Color(0xFF9E9E9E);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, size: 24, color: charcoal),
      title: Text(
        title,
        style: TextStyle(
          color: charcoal,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle,
                style: TextStyle(color: muted, fontSize: 13),
              ),
            ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final config = _config;
    if (config == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              RemixIcons.arrow_left_line,
              color: dark ? Colors.white : const Color(0xFF1C1B1F),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.sourceName,
            style: TextStyle(
              color: dark ? Colors.white : const Color(0xFF1C1B1F),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final defaultDomain = _domainForFallback();
    final cookiesPresent =
        config.cookies != null && config.cookies!.isNotEmpty;
    final source = getSourceByName(widget.sourceName);
    final supportsSignIn = source.supportsSignIn;
    final signedInSubtitle =
        cookiesPresent ? _l.signInLoggedInAs : _l.sourceNotSignedIn;

    Widget sectionDivider() => const SizedBox(height: 6);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            RemixIcons.arrow_left_line,
            color: dark ? Colors.white : const Color(0xFF1C1B1F),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.sourceName,
          style: TextStyle(
            color: dark ? Colors.white : const Color(0xFF1C1B1F),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _row(
            icon: RemixIcons.global_line,
            title: _l.sourceDomain,
            subtitle: _l.sourceDefault(
              config.baseUrlOverride ?? defaultDomain,
            ),
            trailing: _chevron(),
            onTap: () => _editText(
              title: _l.sourceDomain,
              hint: defaultDomain,
              initial: config.baseUrlOverride ?? defaultDomain,
              onSave: (value) => SourceNetworkConfig.setBaseUrl(
                widget.sourceId,
                value: value,
              ),
              resetOnEmpty: true,
            ),
          ),
          sectionDivider(),
          _row(
            icon: RemixIcons.user_smile_line,
            title: _l.sourceUserAgent,
            subtitle: _l.sourceDefault(
              config.userAgent ?? _defaultUa ?? 'Default',
            ),
            trailing: _chevron(),
            onTap: () => _editText(
              title: _l.sourceUserAgent,
              hint: _defaultUa ?? 'Default',
              initial: config.userAgent ?? _defaultUa ?? 'Default',
              onSave: (value) => SourceNetworkConfig.setUserAgent(
                widget.sourceId,
                value: value,
              ),
              resetOnEmpty: true,
            ),
          ),
          sectionDivider(),
          if (supportsSignIn) ...[
            _row(
              icon: RemixIcons.login_box_line,
              title: _l.sourceSignIn,
              subtitle: signedInSubtitle,
              trailing: _chevron(),
              onTap: _startSignIn,
            ),
            sectionDivider(),
          ],
          _row(
            icon: RemixIcons.delete_bin_line,
            title: _l.sourceClearCookies,
            subtitle: _l.sourceClearCookiesSubtitle,
            trailing: _chevron(),
            onTap: () async {
              await SourceNetworkConfig.clearCookies(widget.sourceId);
              await _reload();
              _toast(_l.sourceCookiesCleared);
            },
          ),
          sectionDivider(),
          _row(
            icon: RemixIcons.shield_check_line,
            title: _l.sourceCaptchaSolver,
            subtitle: _l.sourceCaptchaSolverSubtitle,
            trailing: Switch(
              value: config.captchaAutosolveDisabled ?? false,
              onChanged: (v) async {
                await SourceNetworkConfig.setCaptchaAutosolveDisabled(
                  widget.sourceId,
                  v,
                );
                await _reload();
              },
            ),
          ),
          sectionDivider(),
          _row(
            icon: RemixIcons.notification_badge_line,
            title: _l.sourceCaptchaNotif,
            subtitle: _l.sourceCaptchaNotifSubtitle,
            trailing: Switch(
              value: config.captchaNotificationsDisabled ?? false,
              onChanged: (v) async {
                await SourceNetworkConfig.setCaptchaNotificationsDisabled(
                  widget.sourceId,
                  v,
                );
                await _reload();
              },
            ),
          ),
          sectionDivider(),
          _row(
            icon: RemixIcons.speed_line,
            title: _l.sourceDownloadSlowdown,
            subtitle: _l.sourceDownloadSlowdownSubtitle,
            trailing: Switch(
              value: config.downloadSlowdown ?? false,
              onChanged: (v) async {
                await SourceNetworkConfig.setDownloadSlowdown(
                  widget.sourceId,
                  v,
                );
                await _reload();
              },
            ),
          ),
          sectionDivider(),
          _row(
            icon: RemixIcons.pulse_line,
            title: _l.sourceTest,
            subtitle: _l.sourceTestSubtitle,
            trailing: _testing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _chevron(),
            onTap: _runTest,
          ),
          sectionDivider(),
          _row(
            icon: RemixIcons.external_link_line,
            title: _l.sourceOpenInBrowser,
            subtitle: config.baseUrlOverride ?? defaultDomain,
            trailing: _chevron(),
            onTap: _openInBrowser,
          ),
        ],
      ),
    );
  }
}