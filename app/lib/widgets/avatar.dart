import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../net.dart';
import '../theme.dart';

/// Rond de profil : la photo si le joueur en a mis une, sinon son emoji sur sa couleur.
class PbAvatar extends StatelessWidget {
  const PbAvatar({
    super.key,
    required this.size,
    required this.emoji,
    required this.color,
    this.photoPath,
    this.photoBytes,
    this.dimmed = false,
  });

  final double size;
  final String emoji;
  final int color;
  final String? photoPath; // chemin servi par le serveur (/a/…)
  final Uint8List? photoBytes; // photo locale (avant envoi)
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final c = Pb.playerColor(color);
    Widget inner;
    if (photoBytes != null) {
      inner = Image.memory(photoBytes!, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (photoPath != null) {
      inner = Image.network(
        photoUrl(photoPath!),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _emoji(c),
      );
    } else {
      inner = _emoji(c);
    }
    final ring = size * .06;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: dimmed ? .35 : 1,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(ring),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c,
          boxShadow: [BoxShadow(color: c.withValues(alpha: .45), blurRadius: size * .18)],
        ),
        child: ClipOval(child: inner),
      ),
    );
  }

  Widget _emoji(Color c) => Container(
        color: Color.lerp(c, Pb.bg, .55),
        alignment: Alignment.center,
        child: Text(emoji, style: TextStyle(fontSize: size * .48, height: 1)),
      );
}
