import 'package:flutter/material.dart';

import '../../theme.dart';
import 'install_stub.dart' if (dart.library.js_interop) 'install_web.dart';

/// Bouton « Mettre PartyBroc sur mon écran d'accueil » : l'icône ouvre ensuite
/// l'appli en plein écran, comme une vraie appli (sans barre du navigateur).
class HomeIconButton extends StatefulWidget {
  const HomeIconButton({super.key});

  @override
  State<HomeIconButton> createState() => _HomeIconButtonState();
}

class _HomeIconButtonState extends State<HomeIconButton> {
  bool _done = false;

  Future<void> _tap() async {
    final kind = installKind();
    if (kind == 'prompt') {
      final ok = await install();
      if (ok) setState(() => _done = true);
      return;
    }
    if (!mounted) return;
    final ios = kind == 'ios';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Pb.bg2,
        title: Text('📲 Sur l’écran d’accueil', style: Pb.t(22, weight: 700)),
        content: Text(
          ios
              ? '1. Touche le bouton Partager ⬆️ en bas de Safari.\n2. Choisis « Sur l’écran d’accueil ».\n\nL’icône PartyBroc ouvrira le jeu en plein écran.'
              : '1. Ouvre le menu ⋮ du navigateur (en haut à droite).\n2. Choisis « Ajouter à l’écran d’accueil » ou « Installer l’appli ».\n\nL’icône PartyBroc ouvrira le jeu en plein écran.',
          style: Pb.t(17, height: 1.35),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_done || installKind() == 'done') return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: _tap,
      icon: const Text('📲', style: TextStyle(fontSize: 20)),
      label: Text('Mettre PartyBroc sur mon écran d’accueil', style: Pb.t(15, color: Pb.cyan)),
    );
  }
}
