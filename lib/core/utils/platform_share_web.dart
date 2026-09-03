// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void openExternalUrl(String url) {
  html.window.open(url, '_blank');
}

Future<bool> tryNativeShare({
  required String title,
  required String text,
  required String url,
}) async {
  try {
    final nav = html.window.navigator;
    if (nav.share != null) {
      await nav.share({
        'title': title,
        'text': text,
        'url': url,
      });
      return true;
    }
  } catch (_) {}
  return false;
}

String getCurrentOrigin() {
  try {
    return html.window.location.origin;
  } catch (_) {
    final base = Uri.base;
    return (base.hasScheme && base.host.isNotEmpty) ? base.origin : '';
  }
}
