import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/theme_context.dart';
import '../data/steam_openid.dart';

/// Сторінка входу Steam усередині застосунку. Пароль вводиться на сайті Steam;
/// коли Steam повертає на [SteamOpenId.returnTo], сторінка закривається
/// з адресою відповіді (її ще треба перевірити через [SteamOpenId.verify]).
class SteamWebLoginPage extends StatefulWidget {
  const SteamWebLoginPage({super.key, required this.openId});

  final SteamOpenId openId;

  @override
  State<SteamWebLoginPage> createState() => _SteamWebLoginPageState();
}

class _SteamWebLoginPageState extends State<SteamWebLoginPage> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (_finish(request.url)) return NavigationDecision.prevent;
            return NavigationDecision.navigate;
          },
          // Запасний шлях: деякі переходи не проходять через onNavigationRequest.
          onPageStarted: _finish,
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
        ),
      )
      ..loadRequest(widget.openId.loginUri);
  }

  bool _finish(String url) {
    if (_done || !widget.openId.isCallback(url)) return false;
    _done = true;
    Navigator.of(context).pop(Uri.parse(url));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вхід через Steam'),
        leading: IconButton(
          tooltip: 'Скасувати',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  minHeight: 2,
                  color: context.colors.dust,
                  backgroundColor: Colors.transparent,
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
