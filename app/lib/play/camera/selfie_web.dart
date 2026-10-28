import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../theme.dart';

/// La caméra n'est pas utilisable (refusée, absente, page non sécurisée…)
class SelfieUnavailable implements Exception {
  SelfieUnavailable([this.reason = '']);
  final String reason;
  @override
  String toString() => reason;
}

/// Ouvre la caméra frontale DANS la page (pas d'appli photo externe, donc le
/// navigateur n'est pas tué en arrière-plan), affiche l'aperçu et renvoie un
/// JPEG carré. null = annulé.
Future<Uint8List?> takeSelfie(BuildContext context) async {
  web.MediaStream stream;
  try {
    stream = await web.window.navigator.mediaDevices
        .getUserMedia(web.MediaStreamConstraints(
          audio: false.toJS,
          video: {
            'facingMode': 'user',
            'width': {'ideal': 720},
            'height': {'ideal': 720},
          }.jsify()!,
        ))
        .toDart;
  } catch (e) {
    final s = '$e';
    throw SelfieUnavailable(s.contains('NotAllowed') || s.contains('Permission')
        ? 'Accès à la caméra refusé. Autorise la caméra pour ce site dans les réglages du navigateur (le cadenas à côté de l’adresse), ou prends une photo depuis la Galerie.'
        : s.contains('NotFound') || s.contains('Overconstrained')
            ? 'Pas de caméra trouvée sur ce téléphone. Utilise la Galerie.'
            : s.contains('NotReadable')
                ? 'La caméra est déjà utilisée par une autre appli. Ferme-la puis réessaie.'
                : 'Caméra indisponible dans ce navigateur. Utilise la Galerie.');
  }

  final video = web.HTMLVideoElement()
    ..autoplay = true
    ..muted = true
    ..srcObject = stream;
  video.setAttribute('playsinline', 'true');
  video.style
    ..width = '100%'
    ..height = '100%'
    ..objectFit = 'cover'
    ..transform = 'scaleX(-1)' // effet miroir, comme un vrai selfie
    ..borderRadius = '50%';

  final viewType = 'pb-selfie-${DateTime.now().microsecondsSinceEpoch}';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) => video);

  Uint8List? snap() {
    final w = video.videoWidth, h = video.videoHeight;
    if (w == 0 || h == 0) return null;
    final side = w < h ? w : h;
    const out = 480;
    final canvas = web.HTMLCanvasElement()
      ..width = out
      ..height = out;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    // Même cadrage que l'aperçu : carré centré, en miroir
    ctx.translate(out.toDouble(), 0);
    ctx.scale(-1, 1);
    ctx.drawImage(video, (w - side) / 2, (h - side) / 2, side.toDouble(), side.toDouble(), 0, 0, out.toDouble(), out.toDouble());
    final url = canvas.toDataURL('image/jpeg', 0.9.toJS);
    return base64Decode(url.substring(url.indexOf(',') + 1));
  }

  try {
    if (!context.mounted) return null;
    return await showDialog<Uint8List?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Pb.bg2,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Souris ! 📸', style: Pb.t(24, weight: 700)),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Pb.pink, width: 5)),
                child: ClipOval(child: HtmlElementView(viewType: viewType)),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final bytes = snap();
                    if (bytes != null) Navigator.pop(ctx, bytes);
                  },
                  child: const Text('Prendre'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  } finally {
    // On coupe toujours la caméra (le voyant s'éteint)
    for (final t in stream.getTracks().toDart) {
      t.stop();
    }
    video.srcObject = null;
  }
}
