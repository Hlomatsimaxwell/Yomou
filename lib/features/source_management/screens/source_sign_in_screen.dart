import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yomou/data/sources/source_network.dart';

/// In-app browser for per-source sign-in. The user logs in on the source's
/// website; on close the WebView's cookies are captured and returned so they
/// can be sent as a `Cookie` header on every request for that source.
class SourceSignInScreen extends StatefulWidget {
  final String sourceId;
  final String sourceName;
  final String initialUrl;

  const SourceSignInScreen({
    super.key,
    required this.sourceId,
    required this.sourceName,
    required this.initialUrl,
  });

  /// Returns the captured cookie header (`name=value; ...`) or null.
  static Future<String?> _captureCookies(String url) async {
    try {
      final host = Uri.parse(url).host;
      final cookies = await CookieManager.instance().getAllCookies();
      final entries = <String>{};
      for (final c in cookies) {
        final domain = c.domain ?? '';
        if (domain.isNotEmpty && !domain.contains(host)) continue;
        final name = c.name;
        final value = c.value.toString();
        if (name.isEmpty || value.isEmpty) {
          continue;
        }
        entries.add('$name=$value');
      }
      final header = entries.join('; ');
      return header.isEmpty ? null : header;
    } catch (_) {
      return null;
    }
  }

  @override
  State<SourceSignInScreen> createState() => _SourceSignInScreenState();
}

class _SourceSignInScreenState extends State<SourceSignInScreen> {
  bool _captured = false;

  Future<String?> _capture() async {
    final header = await SourceSignInScreen._captureCookies(widget.initialUrl);
    _captured = true;
    await SourceNetworkConfig.setCookies(
      widget.sourceId,
      value: header ?? '',
    );
    return header;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop && !_captured) {
          await _capture();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              RemixIcons.close_line,
              color: dark ? Colors.white : const Color(0xFF1C1B1F),
            ),
            onPressed: () {
              _capture().then((header) {
                if (!context.mounted) return;
                Navigator.pop(context, header);
              });
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.sourceName,
                style: TextStyle(
                  color: dark ? Colors.white : const Color(0xFF1C1B1F),
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.initialUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dark ? Colors.white38 : Colors.black38,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                RemixIcons.external_link_line,
                color: dark ? Colors.white : const Color(0xFF1C1B1F),
              ),
              onPressed: () async {
                await launchUrl(
                  Uri.parse(widget.initialUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
              tooltip: 'Open in browser',
            ),
          ],
        ),
        body: SafeArea(
          child: InAppWebView(
            initialUrlRequest:
                URLRequest(url: WebUri(widget.initialUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              supportMultipleWindows: true,
              mediaPlaybackRequiresUserGesture: false,
            ),
            onCreateWindow: (controller, createWindowAction) async {
              final url = createWindowAction.request.url;
              if (url == null) return false;
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('New window'),
                  content: const Text('Open in external browser?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      child: const Text('Open'),
                    ),
                  ],
                ),
              );
              return true;
            },
          ),
        ),
      ),
    );
  }
}