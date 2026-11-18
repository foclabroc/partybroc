import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../net.dart';
import '../theme.dart';

/// Chargement à l'ouverture de l'écran TV, avec barre de progression : tout ce qui peut
/// l'être est mis en mémoire avant la première partie, pour ne rien attendre pendant le jeu.
///  1. sons et musiques (copiés une fois par audioplayers, sinon au premier son) ;
///  2. images des cartes (décodées) ;
///  3. photos des jeux (Zoom mystère, Mémoire, Le juste prix), gardées en mémoire ;
///  4. dessins courants passés une fois au processeur graphique (dégradés, ombres, textes…),
///     sinon la TV les prépare au premier affichage et l'écran saccade.
/// Rien n'est bloquant : ce qui échoue ou tarde est simplement sauté.
class Preload {
  Preload._();
  static final instance = Preload._();

  final progress = ValueNotifier<double>(0);
  final step = ValueNotifier<String>('');
  final done = ValueNotifier<bool>(false);
  final _photos = <String, MemoryImage>{};
  bool _started = false;

  /// Photo d'un jeu : depuis la mémoire si elle a été chargée, sinon par le réseau
  ImageProvider photo(String id) => _photos[id] ?? NetworkImage(photoUrl('/img/$id'));

  Future<void> run(BuildContext context) async {
    if (_started) return;
    _started = true;
    final bundle = DefaultAssetBundle.of(context);
    final config = createLocalImageConfiguration(context);
    try {
      final assets = (await AssetManifest.loadFromAssetBundle(bundle)).listAssets();
      final sounds = [for (final a in assets) if (a.startsWith('assets/sfx/') || a.startsWith('assets/music/')) a.substring('assets/'.length)];
      final cards = [for (final a in assets) if (a.startsWith('assets/cards/')) a];

      // 1. Sons et musiques (30 %)
      step.value = 'Sons et musiques';
      for (var i = 0; i < sounds.length; i++) {
        try {
          await AudioCache.instance.load(sounds[i]).timeout(const Duration(seconds: 8));
        } catch (_) {}
        progress.value = .30 * (i + 1) / sounds.length;
      }

      // 2. Cartes (20 %)
      step.value = 'Cartes';
      for (var i = 0; i < cards.length; i++) {
        try {
          await _decode(AssetImage(cards[i]), config).timeout(const Duration(seconds: 5));
        } catch (_) {}
        progress.value = .30 + .20 * (i + 1) / cards.length;
      }

      // 3. Photos des jeux (40 %)
      step.value = 'Photos des jeux';
      await _photosStep();

      // 4. Préparation de l'affichage (10 %)
      step.value = 'Préparation de l’affichage';
      await _warmUp();
      progress.value = 1;
    } catch (_) {
      // au pire on démarre sans tout avoir en mémoire
    }
    done.value = true;
  }

  Future<void> _photosStep() async {
    final net = NetworkAssetBundle(serverBase());
    List<String> ids;
    try {
      final data = await net.load('/img-list').timeout(const Duration(seconds: 6));
      ids = [for (final x in (jsonDecode(utf8.decode(data.buffer.asUint8List())) as Map)['ids'] as List) x as String];
    } catch (_) {
      progress.value = .90;
      return;
    }
    if (ids.isEmpty) {
      progress.value = .90;
      return;
    }
    // 6 téléchargements à la fois, 45 s au plus pour l'ensemble
    var next = 0, count = 0;
    final until = DateTime.now().add(const Duration(seconds: 45));
    Future<void> worker() async {
      while (next < ids.length && DateTime.now().isBefore(until)) {
        final id = ids[next++];
        try {
          final b = await net.load('/img/$id').timeout(const Duration(seconds: 8));
          _photos[id] = MemoryImage(Uint8List.fromList(b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes)));
        } catch (_) {}
        count++;
        progress.value = .50 + .40 * count / ids.length;
      }
    }

    await Future.wait([for (var i = 0; i < 6; i++) worker()]);
    progress.value = .90;
  }

  Future<void> _decode(ImageProvider p, ImageConfiguration config) {
    final c = Completer<void>();
    final stream = p.resolve(config);
    late final ImageStreamListener l;
    l = ImageStreamListener((_, _) {
      stream.removeListener(l);
      if (!c.isCompleted) c.complete();
    }, onError: (_, _) {
      stream.removeListener(l);
      if (!c.isCompleted) c.complete();
    });
    stream.addListener(l);
    return c.future;
  }

  // Les dessins les plus courants des jeux, une fois hors écran
  Future<void> _warmUp() async {
    try {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      const size = Size(512, 512);
      final rect = Offset.zero & size;
      canvas.drawRect(rect, Paint()..shader = const LinearGradient(colors: [Pb.pink, Pb.cyan]).createShader(rect));
      canvas.drawCircle(const Offset(256, 256), 200, Paint()..shader = const RadialGradient(colors: [Pb.yellow, Pb.bg]).createShader(rect));
      canvas.drawCircle(const Offset(256, 256), 180, Paint()..shader = const SweepGradient(colors: [Pb.pink, Pb.yellow, Pb.cyan, Pb.pink]).createShader(rect));
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(40, 40, 300, 160), const Radius.circular(30)),
          Paint()..color = Colors.black54..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(60, 60, 380, 380), const Radius.circular(40)));
      canvas.rotate(.3);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 300, 300), Paint()..color = Pb.card);
      canvas.restore();
      canvas.drawPath(Path()..addOval(const Rect.fromLTWH(100, 100, 200, 120)), Paint()..style = PaintingStyle.stroke..strokeWidth = 6..color = Pb.green);
      final tp = TextPainter(
        text: TextSpan(text: 'PartyBroc 0123456789 ÀÉÈ !?', style: Pb.t(40, weight: 700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, const Offset(20, 400));
      final pic = rec.endRecording();
      final img = await pic.toImage(512, 512);
      // et l'image elle-même dessinée avec un filtre (cartes, photos)
      final rec2 = ui.PictureRecorder();
      Canvas(rec2).drawImageRect(img, rect, const Rect.fromLTWH(0, 0, 256, 256), Paint()..filterQuality = FilterQuality.medium);
      (await rec2.endRecording().toImage(256, 256)).dispose();
      img.dispose();
      pic.dispose();
    } catch (_) {}
  }
}

/// Écran de chargement de la TV (par-dessus tout, jusqu'à la fin du chargement)
class PreloadView extends StatelessWidget {
  const PreloadView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Preload.instance;
    // Material : hors du Scaffold, sinon les textes seraient soulignés en jaune
    return Material(
      color: Pb.bg,
      child: Center(
        child: SizedBox(
          width: 900,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('🎉', style: const TextStyle(fontSize: 120)),
            Text('PartyBroc', style: Pb.t(110, weight: 700)),
            const SizedBox(height: 50),
            ValueListenableBuilder<double>(
              valueListenable: p.progress,
              builder: (_, v, _) => Column(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(value: v, minHeight: 26, color: Pb.pink, backgroundColor: Pb.card),
                ),
                const SizedBox(height: 18),
                ValueListenableBuilder<String>(
                  valueListenable: p.step,
                  builder: (_, s, _) => Text('Chargement… ${(v * 100).round()} %${s.isEmpty ? '' : ' · $s'}', style: Pb.t(40, color: Pb.muted)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
