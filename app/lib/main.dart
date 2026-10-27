import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'play/play_screen.dart';
import 'theme.dart';
import 'tv/tv_screen.dart';

/// PartyBroc : une seule appli web, deux écrans.
///   /tv          → l'écran de la TV (salon, QR, jeu)
///   /play?code=  → le téléphone d'un joueur
///   /            → accueil (choisir TV ou téléphone)
void main() {
  usePathUrlStrategy();
  runApp(const PartyBrocApp());
}

class PartyBrocApp extends StatelessWidget {
  const PartyBrocApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Appli Android TV : directement l'écran de la TV
    if (!kIsWeb) {
      return MaterialApp(
        title: 'PartyBroc TV',
        debugShowCheckedModeBanner: false,
        theme: Pb.theme(),
        home: const TvScreen(),
      );
    }
    final uri = Uri.base;
    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    final code = uri.queryParameters['code'];
    final Widget home = switch (path) {
      '/tv' => const TvScreen(),
      '/play' => PlayScreen(initialCode: code),
      _ => code != null ? PlayScreen(initialCode: code) : const HomeScreen(),
    };
    return MaterialApp(
      title: 'PartyBroc',
      debugShowCheckedModeBanner: false,
      theme: Pb.theme(),
      home: home,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PartyBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Center(child: PbLogo(size: 46)),
                  const SizedBox(height: 10),
                  Text('Jeux de soirée : la TV affiche, les téléphones jouent.',
                      textAlign: TextAlign.center, style: Pb.t(17, color: Pb.muted)),
                  const SizedBox(height: 40),
                  FilledButton.icon(
                    onPressed: () => _go(context, const PlayScreen()),
                    icon: const Icon(Icons.smartphone_rounded),
                    label: const Text('Rejoindre une partie'),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => _go(context, const TvScreen()),
                    icon: const Icon(Icons.tv_rounded),
                    label: const Text('Afficher sur cet écran (TV)'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context, Widget w) =>
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => w));
}
