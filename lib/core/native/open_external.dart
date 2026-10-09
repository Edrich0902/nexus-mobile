import 'package:url_launcher/url_launcher.dart';

/// Opens an http(s) link in the browser / owning app. Other schemes are
/// ignored so API-supplied URLs can't launch arbitrary intents.
Future<void> openExternal(String? url) async {
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
