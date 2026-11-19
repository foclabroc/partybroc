import 'package:flutter/services.dart';

/// Appli Android : une petite secousse si c'est juste, une forte si c'est faux
Future<void> mngBuzz(bool ok) async {
  try {
    if (ok) {
      await HapticFeedback.lightImpact();
    } else {
      await HapticFeedback.heavyImpact();
    }
  } catch (_) {}
}
