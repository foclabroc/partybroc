import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app_mode.dart';
import 'play/play_screen.dart';
import 'theme.dart';
import 'tv/tv_screen.dart';

/// PartyBroc : une seule appli web, deux écrans.
///   /tv          → l'écran de la TV (salon, QR, jeu)
///   /play?code=  → le téléphone d'un joueur
///   /            → accueil (choisir TV ou téléphone)
/// Applis Android : PartyBroc TV (--flavor tv, écran de la TV) et PartyBroc
/// (--flavor phone, téléphone du joueur, ouverte aussi par les liens /play?code=).
void main() {
  usePathUrlStrategy();
  runApp(const PartyBrocApp());
  // Retour sur la page/l'appli (après le choix d'une photo, la veille…) : Android a pu
  // jeter le dessin. On redessine tout l'écran, plusieurs fois le temps que le
  // navigateur rende la main, au lieu d'attendre le prochain changement à l'écran.
  AppLifecycleListener(
    onShow: _repaint,
    onResume: _repaint,
  );
}

void _repaint() {
  for (final ms in const [0, 300, 1000, 2500]) {
    Timer(Duration(milliseconds: ms), () {
      SchedulerBinding.instance.scheduleForcedFrame();
      for (final v in WidgetsBinding.instance.renderViews) {
        v.markNeedsPaint();
      }
    });
  }
}

class PartyBrocApp extends StatelessWidget {
  const PartyBrocApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Appli Android téléphone : directement l'écran du joueur
    if (isPhoneApp) return const PhoneApp();
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

/// Appli Android du téléphone. Un lien …/play?code=ABCD (QR de la TV scanné avec
/// l'appareil photo, invitation) l'ouvre directement sur ce salon, au démarrage comme
/// quand elle est déjà ouverte.
class PhoneApp extends StatefulWidget {
  const PhoneApp({super.key});

  @override
  State<PhoneApp> createState() => _PhoneAppState();
}

class _PhoneAppState extends State<PhoneApp> with WidgetsBindingObserver {
  final _nav = GlobalKey<NavigatorState>();
  // Code du salon demandé par un lien, et un numéro qui change à chaque nouveau lien
  final _link = ValueNotifier<(String?, int)>((null, 0));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _link.value = (codeFromLink(WidgetsBinding.instance.platformDispatcher.defaultRouteName), 0);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Lien reçu pendant que l'appli tourne : on rejoint ce salon (sauf si on y est déjà)
  @override
  Future<bool> didPushRouteInformation(RouteInformation info) {
    final code = codeFromLink(info.uri.toString());
    if (code != null && code != _link.value.$1) {
      _nav.currentState?.popUntil((r) => r.isFirst);
      _link.value = (code, _link.value.$2 + 1);
    }
    return SynchronousFuture(true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PartyBroc',
      navigatorKey: _nav,
      debugShowCheckedModeBanner: false,
      theme: Pb.theme(),
      // La route de départ peut être « /play?code=… » : on ouvre toujours l'écran du joueur
      onGenerateRoute: (_) => null,
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute(
          builder: (_) => ValueListenableBuilder(
            valueListenable: _link,
            builder: (_, l, _) => PlayScreen(key: ValueKey(l.$2), initialCode: l.$1),
          ),
        ),
      ],
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
