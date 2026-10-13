import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/config/app_config.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';

/// Runs a provider OAuth flow in the system browser sheet. The API validates
/// `return_to` against its allowlist and redirects to
/// `nexus://oauth/<provider>?connected=1` when done. Returns true on success.
Future<bool> connectWithOAuth(
  BuildContext context, {
  required String provider,
  required Future<String> Function(String returnTo) authorizationUrl,
}) async {
  final returnTo = '${AppConfig.urlScheme}://oauth/$provider';
  try {
    final url = await authorizationUrl(returnTo);
    final result = await FlutterWebAuth2.authenticate(url: url, callbackUrlScheme: AppConfig.urlScheme);
    final query = Uri.parse(result).queryParameters;
    if (query['connected'] == '1') return true;
    if (context.mounted) {
      showNxToast(
        context,
        query['error'] == 'access_denied' ? 'Connection cancelled.' : 'Could not connect. Try again.',
        error: true,
      );
    }
  } on PlatformException catch (e) {
    if (e.code != 'CANCELED' && context.mounted) showNxToast(context, 'Could not open the sign-in page.', error: true);
  } on Object catch (e) {
    if (context.mounted) showApiError(context, e, 'Could not start the connection.');
  }
  return false;
}
