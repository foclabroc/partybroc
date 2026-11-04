import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app_mode.dart';
import '../theme.dart';

/// Appli téléphone : scanner le QR affiché sur la TV. Renvoie le code du salon.
Future<String?> scanRoomCode(BuildContext context) =>
    Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _ScanScreen()));

class _ScanScreen extends StatefulWidget {
  const _ScanScreen();

  @override
  State<_ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<_ScanScreen> {
  final _ctrl = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;

  void _onDetect(BarcodeCapture c) {
    if (_done) return;
    for (final b in c.barcodes) {
      final code = codeFromLink(b.rawValue);
      if (code != null) {
        _done = true;
        HapticFeedback.mediumImpact();
        Navigator.pop(context, code);
        return;
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Scanne le QR de la TV', style: Pb.t(20, weight: 600)),
      ),
      body: Stack(fit: StackFit.expand, children: [
        MobileScanner(
          controller: _ctrl,
          onDetect: _onDetect,
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                error.errorCode == MobileScannerErrorCode.permissionDenied
                    ? 'PartyBroc n’a pas le droit d’utiliser la caméra.\nAutorise-la dans les réglages d’Android, ou tape le code à la main.'
                    : 'Caméra indisponible : tape le code à la main.',
                textAlign: TextAlign.center,
                style: Pb.t(18, height: 1.35),
              ),
            ),
          ),
        ),
        // Cadre de visée
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Pb.yellow, width: 4),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ]),
    );
  }
}
