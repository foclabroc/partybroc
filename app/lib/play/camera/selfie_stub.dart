import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Hors navigateur, pas de caméra intégrée : l'appelant utilise image_picker.
class SelfieUnavailable implements Exception {}

Future<Uint8List?> takeSelfie(BuildContext context) async => throw SelfieUnavailable();
