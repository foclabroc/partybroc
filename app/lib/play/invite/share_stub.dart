/// Ni navigateur ni Android : pas de partage.
Future<bool> shareLink({required String title, required String text, required String url}) async => false;

void openLink(String url) {}
