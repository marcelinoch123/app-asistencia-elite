// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<String?> saveAndLaunchFile(List<int> bytes, String fileName) async {
  final blob = html.Blob(
    [bytes],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
  return null;
}
