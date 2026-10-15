import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/i18n/app_strings.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../../shared/widgets/state_block.dart';

/// Reads a policy page inside the app.
///
/// Keeps Terms, PSARA and privacy pages in the app instead of throwing the
/// guard into a browser they may not have, and degrades to an explicit browser
/// hand-off when the page cannot load (offline, or a WebView platform that is
/// not available on this build). JavaScript stays disabled: these pages are
/// documents, and a policy page has no business running script.
class PolicyWebViewScreen extends StatefulWidget {
  const PolicyWebViewScreen({
    super.key,
    required this.title,
    this.url,
    this.assetPath,
    this.openInBrowser,
  });

  final String title;

  /// Remote page. Exactly one of [url] and [assetPath] is used.
  final String? url;

  /// Bundled page, for a policy that must open without connectivity.
  final String? assetPath;

  /// Overrides the browser hand-off, so tests never launch an intent.
  final Future<bool> Function(Uri uri)? openInBrowser;

  @override
  State<PolicyWebViewScreen> createState() => _PolicyWebViewScreenState();
}

class _PolicyWebViewScreenState extends State<PolicyWebViewScreen> {
  WebViewController? _controller;
  bool _loading = true;
  bool _failed = false;

  Uri? get _browserUri {
    final asset = widget.assetPath;
    if (asset != null && asset.trim().isNotEmpty) return null;
    final url = widget.url;
    if (url == null || url.trim().isEmpty) return null;
    return Uri.tryParse(url.trim());
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final controller =
          WebViewController()
            ..setJavaScriptMode(JavaScriptMode.disabled)
            ..setNavigationDelegate(
              NavigationDelegate(
                onPageStarted: (_) {
                  if (mounted) setState(() => _loading = true);
                },
                onPageFinished: (_) {
                  if (mounted) setState(() => _loading = false);
                },
                onWebResourceError: (error) {
                  // Only the document itself failing means the page is
                  // unusable; a missing image must not blank the screen.
                  if (error.isForMainFrame == false) return;
                  if (mounted) setState(() => _failed = true);
                },
              ),
            );
      final asset = widget.assetPath;
      final url = widget.url;
      if (asset != null && asset.trim().isNotEmpty) {
        controller.loadFlutterAsset(asset.trim());
      } else if (url != null && url.trim().isNotEmpty) {
        controller.loadRequest(Uri.parse(url.trim()));
      } else {
        setState(() {
          _loading = false;
          _failed = true;
        });
        return;
      }
      setState(() {
        _controller = controller;
        _failed = false;
      });
    } catch (error) {
      // A build without a WebView platform lands here; the escape hatch is the
      // whole point, so this must never be a crash.
      debugPrint('Policy page could not open in-app: $error');
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _openInBrowser() async {
    final uri = _browserUri;
    if (uri == null) return;
    final launcher = widget.openInBrowser;
    final opened =
        launcher == null
            ? await launchUrl(uri, mode: LaunchMode.externalApplication)
            : await launcher(uri);
    if (opened || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.of(context).navigateUnavailable)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final tokens = CissThemeTokens.of(context);
    final controller = _controller;

    return ScreenScaffold(
      title: widget.title,
      children: <Widget>[
        if (_failed || controller == null)
          StateBlock(
            icon: Icons.menu_book_rounded,
            title: strings.policyUnavailableTitle,
            message: strings.policyUnavailableBody,
            action: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                FilledButton(
                  onPressed: _load,
                  style: _fullWidth,
                  child: Text(
                    strings.readinessRecheck,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (_browserUri != null) ...<Widget>[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _openInBrowser,
                    style: _fullWidth,
                    // A label-only button: an icon plus a long translated
                    // label overflows a narrow screen at large text scales.
                    child: Text(
                      strings.policyOpenInBrowser,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          )
        else ...<Widget>[
          if (_loading)
            LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: tokens.surfaceMuted,
            ),
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.62,
            child: WebViewWidget(controller: controller),
          ),
        ],
      ],
    );
  }

  static final ButtonStyle _fullWidth = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll<Size>(Size.fromHeight(48)),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
    ),
  );
}
