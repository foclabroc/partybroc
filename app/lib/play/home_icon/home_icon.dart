import 'package:flutter/material.dart';

import '../../app_mode.dart';
import '../../theme.dart';
import 'install_stub.dart' if (dart.library.js_interop) 'install_web.dart';

/// Sur un téléphone Android (navigateur) : « Installer la version Android » (l'appli
/// PartyBroc, APK). Sur iPhone : « Mettre PartyBroc sur mon écran d'accueil » (l'icône
/// ouvre la page en plein écran). Dans l'appli ou sur un ordinateur : rien.
class HomeIconButton extends StatelessWidget {
  const HomeIconButton({super.key});

  Future<void> _android(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Pb.bg2,
        title: Text('🤖 Version Android', style: Pb.t(22, weight: 700)),
        content: Text(
          'L’appli PartyBroc : plus fluide, plein écran, selfie et sons sans souci.\n\n'
          '1. Touche « Télécharger ».\n'
          '2. Ouvre le fichier partybroc.apk (notification ou Téléchargements).\n'
          '3. Si Android le demande, autorise ton navigateur à installer des applis, puis « Installer ».\n\n'
          'Ensuite, scanner le QR de la TV ouvre directement l’appli.',
          style: Pb.t(17, height: 1.35),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Plus tard')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openApkDownload(kAndroidApkUrl);
            },
            child: const Text('Télécharger'),
          ),
        ],
      ),
    );
  }

  Future<void> _ios(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Pb.bg2,
        title: Text('📲 Sur l’écran d’accueil', style: Pb.t(22, weight: 700)),
        content: Text(
          '1. Touche le bouton Partager ⬆️ en bas de Safari.\n2. Choisis « Sur l’écran d’accueil ».\n\nL’icône PartyBroc ouvrira le jeu en plein écran.',
          style: Pb.t(17, height: 1.35),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isAndroidBrowser()) {
      return TextButton.icon(
        onPressed: () => _android(context),
        icon: const Text('🤖', style: TextStyle(fontSize: 20)),
        label: Text('Installer la version Android', style: Pb.t(15, color: Pb.cyan)),
      );
    }
    if (installKind() == 'ios') {
      return TextButton.icon(
        onPressed: () => _ios(context),
        icon: const Text('📲', style: TextStyle(fontSize: 20)),
        label: Text('Mettre PartyBroc sur mon écran d’accueil', style: Pb.t(15, color: Pb.cyan)),
      );
    }
    return const SizedBox.shrink();
  }
}
