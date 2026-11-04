import 'package:flutter/material.dart';

import '../app_mode.dart';
import '../theme.dart';
import '../tv/update/update.dart';

/// Appli téléphone : bandeau « Nouvelle version » en haut du formulaire et du salon.
/// Rien sur le web ni sur la TV.
class PhoneUpdateBanner extends StatefulWidget {
  const PhoneUpdateBanner({super.key});

  @override
  State<PhoneUpdateBanner> createState() => _PhoneUpdateBannerState();
}

// Vérifié une fois par lancement de l'appli (le bandeau apparaît sur plusieurs écrans)
Future<TvUpdate?>? _check;

class _PhoneUpdateBannerState extends State<PhoneUpdateBanner> {
  TvUpdate? _update;

  @override
  void initState() {
    super.initState();
    if (!isPhoneApp) return;
    _check ??= checkTvUpdate();
    _check!.then((u) {
      if (mounted && u != null) setState(() => _update = u);
    });
  }

  @override
  Widget build(BuildContext context) {
    final u = _update;
    if (u == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Pb.pink,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showDialog<void>(context: context, barrierDismissible: false, builder: (_) => _UpdateDialog(update: u)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              const Icon(Icons.system_update_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text('Nouvelle version ${u.versionName} : touche pour l’installer', style: Pb.t(16, weight: 600))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Télécharger la nouvelle version et ouvrir l'installateur Android
class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.update});
  final TvUpdate update;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> with WidgetsBindingObserver {
  double? _progress; // null = pas encore lancé
  String? _error;
  bool _needPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Retour des réglages « Sources inconnues » : on relance tout seul
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _needPermission) _go();
  }

  Future<void> _go() async {
    setState(() {
      _progress = 0;
      _error = null;
      _needPermission = false;
    });
    try {
      await installTvUpdate(widget.update, (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (mounted) Navigator.pop(context);
    } on NeedInstallPermission {
      if (mounted) setState(() { _progress = null; _needPermission = true; });
    } catch (e) {
      if (mounted) setState(() { _progress = null; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.update;
    final busy = _progress != null;
    return AlertDialog(
      backgroundColor: Pb.bg2,
      title: Text('Nouvelle version ${u.versionName} 🎉', style: Pb.t(22, weight: 700)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (u.notes.isNotEmpty) Text(u.notes, style: Pb.t(16, color: Pb.muted)),
        if (_needPermission) ...[
          const SizedBox(height: 12),
          Text('Une seule fois : autorise « PartyBroc » à installer des applications, puis reviens ici.',
              style: Pb.t(16, color: Pb.yellow)),
        ],
        if (busy) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _progress == 0 ? null : _progress, minHeight: 8, color: Pb.pink, backgroundColor: Pb.card),
          const SizedBox(height: 8),
          Text('Téléchargement… ${((_progress ?? 0) * 100).round()} %', style: Pb.t(15, color: Pb.muted)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: Pb.t(15, color: Pb.red)),
        ],
      ]),
      actions: busy
          ? const []
          : [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Plus tard')),
              if (_needPermission)
                FilledButton(onPressed: openInstallSettings, child: const Text('Ouvrir les réglages'))
              else
                FilledButton(onPressed: _go, child: Text(_error == null ? 'Mettre à jour' : 'Réessayer')),
            ],
    );
  }
}
