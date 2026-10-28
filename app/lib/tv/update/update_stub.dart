/// Sur le web, pas de mise à jour d'appli : le site se met à jour tout seul.
class TvUpdate {
  TvUpdate(this.versionCode, this.versionName, this.notes);
  final int versionCode;
  final String versionName;
  final String notes;
}

class NeedInstallPermission implements Exception {}

Future<TvUpdate?> checkTvUpdate() async => null;

Future<void> installTvUpdate(TvUpdate u, void Function(double progress) onProgress) async {}

Future<bool> openInstallSettings() async => false;
