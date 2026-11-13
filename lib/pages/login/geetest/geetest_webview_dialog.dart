import 'dart:convert' show jsonDecode;
import 'dart:io' show Platform;

import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/main.dart';
import 'package:PiliPlus/pages/login/geetest/login_challenge.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:PiliPlus/plugin/linux_webview.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class GeetestWebviewDialog extends StatefulWidget {
  const GeetestWebviewDialog(this.gt, this.challenge, {super.key});

  final String gt;
  final String challenge;

  @override
  State<GeetestWebviewDialog> createState() => _GeetestWebviewDialogState();

  static Future<Map<String, dynamic>?> geetest(
    String gt,
    String challenge, {
    bool reportFailure = false,
  }) async {
    try {
      final result = await _openWeb(gt, challenge);
      if (result == null) return null;
      if (result
          case {
            'geetest_challenge': String c,
            'geetest_validate': String v,
            'geetest_seccode': String s,
          }
          when c.isNotEmpty && v.isNotEmpty && s.isNotEmpty) {
        return result;
      }
      throw const GeetestFailure();
    } on GeetestFailure catch (error) {
      if (reportFailure) rethrow;
      SmartDialog.showToast(error.message);
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _openWeb(
    String gt,
    String challenge,
  ) async {
    final result = await showDialog<Object>(
      context: Get.context!,
      builder: (context) => GeetestWebviewDialog(gt, challenge),
    );
    if (result is GeetestFailure) throw result;
    return result as Map<String, dynamic>?;
  }
}

class _GeetestWebviewDialogState extends State<GeetestWebviewDialog> {
  static const _geetestJsUri =
      'https://static.geetest.com/static/js/fullpage.0.0.0.js';
  static const _geetestConfigUri = 'https://api.geetest.com/gettype.php';

  static String _buildHtml(String gt, String challenge) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final js =
        'var C,S,T,t;'
        'T=()=>{if(C&&S&&!t){t=Geetest(C).onSuccess(()=>R("success",t.getValidate())).onError(o=>R("error",o)).onClose(o=>R("close",o));t.onReady(()=>t.verify())}};'
        'geetest_$ts=(d)=>{'
        'if(!d||d.status!="success"){R("error",JSON.stringify(d));return};'
        'C=Object.assign({gt:"$gt",challenge:"$challenge",offline:false,new_captcha:true,product:"bind",width:"100%",https:true,protocol:"https://"},d.data);T()'
        '};'
        'G=()=>{S=1;T()};'
        'E=()=>{document.getElementById("E").textContent="验证码加载失败";R("error","geetest script load failed")}';

    return '<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width"></head>'
        '<style>#E{position:fixed;inset:0;display:flex;align-items:center;justify-content:center;color:red}</style>'
        '<body><div id="E"></div>'
        '<script>'
        '${Platform.isLinux ? "R=(n,o)=>window.PiliPlus.postMessage(n+':'+JSON.stringify(o))" : "R=(n,o)=>window.flutter_inappwebview?.callHandler(n,o)"};$js'
        '</script>'
        '<script src="$_geetestJsUri" onload="G()" onerror="E()"></script>'
        '<script src="$_geetestConfigUri?gt=$gt&callback=geetest_$ts" onerror="E()"></script>'
        '</body></html>';
  }

  late final html = _buildHtml(widget.gt, widget.challenge);
  bool _finished = false;

  void _finish([Object? value]) {
    if (_finished || !mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _finished = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isLinux) {
      return AlertDialog(
        title: const Text('验证码'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: LinuxWebview(
            initialHtml: html,
            userAgent: BrowserUa.mob,
            incognito: true,
            onWebMessageReceived: (msg) {
              final msgStr = msg.toString();
              if (msgStr.startsWith("success:")) {
                final dataStr = msgStr.substring("success:".length);
                try {
                  final data = jsonDecode(dataStr);
                  _finish(data);
                } catch (e) {
                  _finish(const GeetestFailure());
                }
              } else if (msgStr.startsWith("error:")) {
                _finish(GeetestFailure.provider(null, msgStr));
              } else if (msgStr.startsWith('close:')) {
                _finish();
              }
            },
          ),
        ),
      );
    }

    return Stack(
      children: [
        InAppWebView(
          webViewEnvironment: webViewEnvironment,
          initialSettings: InAppWebViewSettings(
            clearCache: true,
            javaScriptEnabled: true,
            forceDark: ForceDark.AUTO,
            useHybridComposition: true,
            algorithmicDarkeningAllowed: true,
            useShouldOverrideUrlLoading: false,
            userAgent: BrowserUa.mob,
            mixedContentMode: .MIXED_CONTENT_ALWAYS_ALLOW,

            incognito: true,
            allowFileAccess: false,
            allowsLinkPreview: false,
            allowContentAccess: false,
            useOnDownloadStart: false,
            geolocationEnabled: false,
            thirdPartyCookiesEnabled: false,
            enterpriseAuthenticationAppLinkPolicyEnabled: false,
            saveFormData: false,
            safeBrowsingEnabled: false,
            isFraudulentWebsiteWarningEnabled: false,
            domStorageEnabled: false,
            databaseEnabled: false,
            cacheEnabled: false,
            cacheMode: .LOAD_NO_CACHE,

            horizontalScrollBarEnabled: false,
            verticalScrollBarEnabled: false,
            overScrollMode: .NEVER,
          ),
          onReceivedError: (_, request, _) {
            if (request.isForMainFrame == true) _finish(const GeetestFailure());
          },
          onWebViewCreated: (ctr) async {
            ctr
              ..addJavaScriptHandler(
                handlerName: 'success',
                callback: (args) {
                  if (args.isNotEmpty) {
                    if (args[0] case Map<String, dynamic> data) {
                      _finish(data);
                      return;
                    }
                  }
                  _finish(const GeetestFailure());
                },
              )
              ..addJavaScriptHandler(
                handlerName: 'error',
                callback: (args) {
                  _finish(GeetestFailure.provider(null, args));
                },
              )
              ..addJavaScriptHandler(
                handlerName: 'close',
                callback: (args) => _finish(),
              );
            // Wait until the native view and result handlers exist before
            // starting scripts that can immediately reject the registration.
            try {
              await ctr.loadData(
                data: html,
                baseUrl: WebUri('https://captcha.invalid/'),
              );
            } catch (_) {
              _finish(const GeetestFailure());
            }
          },
        ),
        Positioned(
          left: 8,
          top: 8,
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _finish,
            tooltip: '关闭',
          ),
        ),
      ],
    );
  }
}
