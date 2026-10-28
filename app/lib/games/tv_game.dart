import 'package:flutter/material.dart';

import '../models.dart';
import 'calcul_ui.dart';
import 'dessin_ui.dart';
import 'justeprix_ui.dart';
import 'memoire_ui.dart';
import 'petitbac_ui.dart';
import 'quiadit_ui.dart';
import 'photoroulette_ui.dart';
import 'survie_ui.dart';
import 'zoom_ui.dart';
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
    'justeprix' => JpTv(room: room, live: live),
    'quiadit' => QadTv(room: room, live: live),
    'photoroulette' => PhrTv(room: room, live: live),
    'calcul' => CalcTv(room: room, live: live),
    'memoire' => MemTv(room: room, live: live),
    'petitbac' => BacTv(room: room, live: live),
    'zoom' => ZoomTv(room: room, live: live),
    'survie' => SurvTv(room: room, live: live),
    _ => const SizedBox.shrink(),
  };
}
