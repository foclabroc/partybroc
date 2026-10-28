import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme.dart';

/// Compte à rebours calé sur le serveur : il envoie « il reste X ms »,
/// on en déduit une échéance locale et on anime jusqu'à zéro.
class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.endsIn, required this.duration, required this.builder});

  final int endsIn; // ms restantes au moment de la réception
  final int duration; // durée totale de la phase (ms)
  final Widget Function(BuildContext context, double fraction, int secondsLeft) builder;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> with SingleTickerProviderStateMixin {
  late DateTime _deadline;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _deadline = DateTime.now().add(Duration(milliseconds: widget.endsIn));
    _ticker = createTicker((_) => setState(() {}))..start();
  }

  @override
  void didUpdateWidget(Countdown old) {
    super.didUpdateWidget(old);
    // Nouvelle info du serveur : on recale seulement si l'écart est notable
    final fresh = DateTime.now().add(Duration(milliseconds: widget.endsIn));
    if (fresh.difference(_deadline).inMilliseconds.abs() > 400) _deadline = fresh;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = _deadline.difference(DateTime.now()).inMilliseconds.clamp(0, widget.duration);
    final frac = widget.duration == 0 ? 0.0 : left / widget.duration;
    // RepaintBoundary : seul le chrono est redessiné 60 fois par seconde, pas tout l'écran
    return RepaintBoundary(child: widget.builder(context, frac, (left / 1000).ceil()));
  }
}

/// Barre de temps qui se vide, rouge à la fin
class TimeBar extends StatelessWidget {
  const TimeBar({super.key, required this.endsIn, required this.duration, this.height = 14});
  final int endsIn;
  final int duration;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Countdown(
      endsIn: endsIn,
      duration: duration,
      builder: (_, f, _) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Stack(children: [
          Container(height: height, color: Pb.card),
          FractionallySizedBox(
            widthFactor: f,
            child: Container(height: height, color: f > .25 ? Pb.cyan : Pb.red),
          ),
        ]),
      ),
    );
  }
}

/// Rond avec les secondes restantes
class TimeCircle extends StatelessWidget {
  const TimeCircle({super.key, required this.endsIn, required this.duration, this.size = 120});
  final int endsIn;
  final int duration;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Countdown(
      endsIn: endsIn,
      duration: duration,
      builder: (_, f, s) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: f,
              strokeWidth: size * .09,
              backgroundColor: Pb.card,
              color: f > .25 ? Pb.cyan : Pb.red,
              strokeCap: StrokeCap.round,
            ),
          ),
          Text('$s', style: Pb.t(size * .42, weight: 700)),
        ]),
      ),
    );
  }
}
