import 'package:flutter/services.dart';

/// Appli Android : deux secousses fortes
Future<void> turnVibrate() async {
  await HapticFeedback.vibrate();
  await Future<void>.delayed(const Duration(milliseconds: 180));
  await HapticFeedback.heavyImpact();
}
