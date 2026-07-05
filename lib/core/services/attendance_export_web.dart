// ignore: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;

/// Web implementation: builds an in-memory blob and clicks a temporary
/// anchor to download the CSV. No external packages required.
void downloadCsv({required String filename, required String content}) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
