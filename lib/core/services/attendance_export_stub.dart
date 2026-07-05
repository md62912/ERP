/// Native (non-web) stub. Mobile CSV export is deferred to avoid adding a
/// native file/share plugin; on web the real implementation in
/// attendance_export_web.dart is used instead via conditional import.
void downloadCsv({required String filename, required String content}) {
  throw UnsupportedError('CSV export is currently available on the web app only.');
}
