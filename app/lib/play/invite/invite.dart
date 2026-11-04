import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../net.dart';
import '../../theme.dart';
import 'share_stub.dart' if (dart.library.js_interop) 'share_web.dart' if (dart.library.io) 'share_io.dart';

/// Bouton « Inviter des joueurs » : envoie le lien du salon par SMS, Messenger,
/// WhatsApp… (menu de partage du téléphone), ou par nos boutons s'il n'existe pas.
class InviteButton extends StatelessWidget {
  const InviteButton({super.key, required this.code, required this.perm});
  final String code;
  final bool perm; // salon permanent : il faudra aussi le mot de passe

  String get _url => serverBase().replace(path: '/play', queryParameters: {'code': code}).toString();

  String get _text => perm
      ? 'Viens jouer avec nous à PartyBroc 🎉 Salon $code (demande-moi le mot de passe) :'
      : 'Viens jouer avec nous à PartyBroc 🎉 Salon $code :';

  Future<void> _tap(BuildContext context) async {
    HapticFeedback.selectionClick();
    final ok = await shareLink(title: 'PartyBroc', text: _text, url: _url);
    if (ok || !context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Pb.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _InviteSheet(text: _text, url: _url),
    );
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: () => _tap(context),
        icon: const Text('📨'),
        label: const Text('Inviter des joueurs (SMS, Messenger…)'),
      );
}

class _InviteSheet extends StatelessWidget {
  const _InviteSheet({required this.text, required this.url});
  final String text, url;

  @override
  Widget build(BuildContext context) {
    final msg = '$text $url';
    final e = Uri.encodeComponent(msg);
    Widget btn(String emoji, String label, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OutlinedButton.icon(onPressed: onTap, icon: Text(emoji), label: Text(label)),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('📨 Inviter des joueurs', style: Pb.t(22, weight: 700)),
          const SizedBox(height: 6),
          SelectableText(url, style: Pb.t(15, color: Pb.muted)),
          const SizedBox(height: 16),
          btn('💬', 'SMS', () => openLink('sms:?&body=$e')),
          btn('🟢', 'WhatsApp', () => openLink('https://wa.me/?text=$e')),
          btn('🔵', 'Messenger', () => openLink('fb-messenger://share/?link=${Uri.encodeComponent(url)}')),
          btn('📋', 'Copier le lien', () {
            Clipboard.setData(ClipboardData(text: msg));
            Navigator.pop(context);
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Lien copié : colle-le dans ton message')));
          }),
        ]),
      ),
    );
  }
}
