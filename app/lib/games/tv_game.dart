import 'package:flutter/material.dart';

import '../models.dart';
import 'dessin_ui.dart';
import 'droles_ui.dart';
import 'quidenous_ui.dart';
import 'quiz_state.dart';
import 'quiz_tv.dart';
import 'reflexes_ui.dart';

/// Ce que montre l'écran TV pendant une partie (toile 1920×1080).
/// Servi aussi aux téléphones des joueurs à distance, en petit.
Widget tvGameView(RoomView room) {
  final live = room.live!;
  return switch (live['id']) {
    'quiz' => QuizTv(room: room, q: QuizState.fromJson(live)),
    'quidenous' => QdnTv(room: room, live: live),
    'droles' => DrlTv(room: room, live: live),
    'reflexes' => RfxTv(room: room, live: live),
    'dessin' => DsnTv(room: room, live: live),
    _ => const SizedBox.shrink(),
  };
}
