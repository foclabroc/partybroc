/// Hors navigateur (appli TV) : rien à installer.
String installKind() => 'done';
Future<bool> install() async => false;
bool isAndroidBrowser() => false;
void openApkDownload(String url) {}
