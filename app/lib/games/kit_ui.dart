import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../net.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'common_ui.dart';

/// Briques communes aux jeux « question + 4 choix » et aux saisies sur le téléphone.

/// Couleurs du jeu Mémoire (mêmes noms que le serveur)
const memColors = <String, Color>{
  'rouge': Color(0xFFFF5A5A),
  'bleu': Color(0xFF4F8BFF),
  'vert': Color(0xFF3FCF7A),
  'jaune': Color(0xFFFFD23F),
  'violet': Color(0xFF9B6BFF),
  'orange': Color(0xFFFF8A3D),
};

/// Photo réelle d’un jeu (servie par `/img/<id>`), ou l’emoji si pas de photo ou si elle ne charge pas
class PbPhoto extends StatelessWidget {
  const PbPhoto({super.key, required this.id, required this.emoji, required this.size, this.radius});
  final String? id;
  final String emoji;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => SizedBox(
          width: size,
          height: size,
          child: Center(child: Text(emoji, style: TextStyle(fontSize: size * .72, height: 1.1))),
        );
    final id = this.id;
    if (id == null || id.isEmpty) return fallback();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? size * .12),
      child: Image.network(
        photoUrl('/img/$id'),
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => fallback(),
      ),
    );
  }
}

/// Un choix affiché : texte, emoji en grand (ou sa photo [img]), ou pastille de couleur
Widget choiceLabel(String v, String kind, double size, {Color color = Colors.white, String? img}) => switch (kind) {
      'emoji' when img != null => PbPhoto(id: img, emoji: v, size: size * 2.1),
      'emoji' => Text(v, style: TextStyle(fontSize: size * 1.6, height: 1.1)),
      'color' => Text(v.toUpperCase(),
          style: Pb.t(size, weight: 700, color: color).copyWith(shadows: const [Shadow(color: Colors.black54, blurRadius: 6)])),
      _ => Text(v, maxLines: 1, style: Pb.t(size, weight: 700, color: color, height: 1.1)),
    };

/// 4 choix sur la TV (2×2). À la révélation : la bonne en avant, les autres pâles,
/// et les avatars de ceux qui ont choisi chaque case.
class TvChoices extends StatelessWidget {
  const TvChoices({super.key, required this.room, required this.choices, this.kind = 'text', this.correct, this.picks = const {}, this.height = 150, this.imgs});
  final RoomView room;
  final List<String> choices;
  final List<String?>? imgs; // photos des choix « emoji »
  final String kind;
  final int? correct;
  final Map<String, int> picks;
  final double height;

  @override
  Widget build(BuildContext context) {
    Widget cell(int i) {
      // Mémoire, question de couleur : la case a la couleur qu'elle désigne
      final c = kind == 'color' ? (memColors[choices[i]] ?? Pb.answerColors[i % 4]) : Pb.answerColors[i % 4];
      final reveal = correct != null;
      final good = correct == i;
      final who = [for (final e in picks.entries) if (e.value == i) room.player(e.key)].whereType<PlayerView>().toList();
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: reveal && !good ? .28 : 1,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 400),
          scale: good ? 1.04 : 1,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(32),
              border: good ? Border.all(color: Colors.white, width: 6) : null,
              boxShadow: good ? [BoxShadow(color: c.withValues(alpha: .6), blurRadius: 40)] : null,
            ),
            child: Row(children: [
              Icon(Pb.answerIcons[i % 4], color: Colors.white, size: 54),
              const SizedBox(width: 22),
              // le texte rétrécit plutôt que de passer à la ligne au milieu d'un mot
              Expanded(
                child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: choiceLabel(choices[i], kind, 46, img: imgs != null && i < imgs!.length ? imgs![i] : null)),
              ),
              // qui a choisi : les avatars s'ils sont peu nombreux, sinon leur nombre (le texte garde sa place)
              if (reveal && who.isNotEmpty) ...[
                const SizedBox(width: 10),
                if (who.length <= 2)
                  for (final p in who)
                    Padding(padding: const EdgeInsets.only(left: 4), child: PbAvatar(size: 46, emoji: p.emoji, color: p.color, photoPath: p.photo))
                else
                  TvChip(text: '👥 ${who.length}', size: 30, bg: Colors.black26),
              ],
              if (good) const Padding(padding: EdgeInsets.only(left: 12), child: Text('✅', style: TextStyle(fontSize: 52))),
            ]),
          ),
        ),
      );
    }

    return Column(children: [
      for (var r = 0; r * 2 < choices.length; r++) ...[
        if (r > 0) const SizedBox(height: 22),
        Row(children: [
          for (var i = r * 2; i < r * 2 + 2 && i < choices.length; i++) ...[
            if (i > r * 2) const SizedBox(width: 22),
            Expanded(child: cell(i)),
          ],
        ]),
      ],
    ]);
  }
}

/// 4 gros boutons sur le téléphone. [picked] = le choix déjà envoyé (verrouillé).
class PhoneChoices extends StatelessWidget {
  const PhoneChoices({super.key, required this.choices, required this.picked, required this.onPick, this.kind = 'text', this.imgs});
  final List<String> choices;
  final List<String?>? imgs; // photos des choix « emoji »
  final int? picked;
  final ValueChanged<int> onPick;
  final String kind;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < choices.length; i++) ...[
        if (i > 0) const SizedBox(height: 10),
        Expanded(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: picked != null && picked != i ? .25 : 1,
            child: Material(
              color: kind == 'color' ? (memColors[choices[i]] ?? Pb.answerColors[i % 4]) : Pb.answerColors[i % 4],
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: picked != null
                    ? null
                    : () {
                        HapticFeedback.heavyImpact();
                        onPick(i);
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: picked == i ? Border.all(color: Colors.white, width: 4) : null,
                  ),
                  child: Row(children: [
                    Icon(Pb.answerIcons[i % 4], color: Colors.white, size: 30),
                    const SizedBox(width: 14),
                    Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: choiceLabel(choices[i], kind, kind == 'emoji' ? 30 : 21, img: imgs != null && i < imgs!.length ? imgs![i] : null))),
                    if (picked == i) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// Saisie d'un nombre sur le téléphone (entier, ou prix avec virgule) + bouton Valider.
/// Une fois envoyée, la réponse s'affiche et ne change plus.
class PhoneNumberInput extends StatefulWidget {
  const PhoneNumberInput({super.key, required this.sent, required this.onSubmit, this.decimal = false, this.suffix, this.hint = 'Ta réponse'});
  final num? sent;
  final ValueChanged<num> onSubmit;
  final bool decimal;
  final String? suffix;
  final String hint;

  @override
  State<PhoneNumberInput> createState() => _PhoneNumberInputState();
}

class _PhoneNumberInputState extends State<PhoneNumberInput> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  num? get _value {
    final t = _c.text.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (t.isEmpty) return null;
    return widget.decimal ? double.tryParse(t) : int.tryParse(t);
  }

  void _go() {
    final v = _value;
    if (v == null) return;
    HapticFeedback.heavyImpact();
    FocusScope.of(context).unfocus();
    widget.onSubmit(v);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sent != null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Ta réponse', style: Pb.t(16, color: Pb.muted)),
        Text('${fmtNum(widget.sent!, widget.decimal)}${widget.suffix ?? ''}', style: Pb.t(44, weight: 700, color: Pb.yellow)),
        Text('Envoyée ! Regarde la TV 📺', style: Pb.t(16, weight: 600, color: Pb.green)),
      ]);
    }
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _c,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: widget.decimal, signed: false),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(widget.decimal ? r'[0-9.,]' : r'[0-9]')), LengthLimitingTextInputFormatter(9)],
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _go(),
          onChanged: (_) => setState(() {}),
          style: Pb.t(34, weight: 700, color: Pb.yellow),
          decoration: InputDecoration(hintText: widget.hint, suffixText: widget.suffix, suffixStyle: Pb.t(26, weight: 700, color: Pb.muted)),
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 120,
        child: FilledButton(onPressed: _value == null ? null : _go, child: const Text('Valider')),
      ),
    ]);
  }
}

/// 1 234 ou 12,50
String fmtNum(num v, [bool decimal = false]) {
  if (!decimal || v == v.roundToDouble()) return Pb.pts(v);
  final s = v.toStringAsFixed(2).replaceAll('.', ',');
  final parts = s.split(',');
  return '${Pb.pts(int.parse(parts[0]))},${parts[1]}';
}

/// Prix en euros : 1,20 € / 1 100 €
String euros(num v) => '${fmtNum(v, true)} €';

/// Grille de joueurs à toucher (Qui a dit ça ?) : tous sauf moi
class PhonePlayerPick extends StatelessWidget {
  const PhonePlayerPick({super.key, required this.room, required this.myPid, required this.picked, required this.onPick});
  final RoomView room;
  final String? myPid;
  final String? picked;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final others = room.players.where((p) => p.pid != myPid).toList();
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: others.length > 8 ? 3 : 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: others.length > 8 ? .95 : 1.2,
      children: [
        for (final p in others)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: picked != null && picked != p.pid ? .3 : 1,
            child: Material(
              color: picked == p.pid ? Pb.cardHi : Pb.card,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: picked != null
                    ? null
                    : () {
                        HapticFeedback.heavyImpact();
                        onPick(p.pid);
                      },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: picked == p.pid ? Pb.pink : Colors.transparent, width: 3),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    PbAvatar(size: others.length > 8 ? 52 : 66, emoji: p.emoji, color: p.color, photoPath: p.photo),
                    const SizedBox(height: 6),
                    Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Pb.t(16, weight: 600)),
                  ]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Rangée d'avatars simple (survivants, qui a trouvé…)
class TvAvatarRow extends StatelessWidget {
  const TvAvatarRow({super.key, required this.room, required this.pids, this.dim = const {}, this.badge, this.size});
  final RoomView room;
  final List<String> pids;
  final Set<String> dim;
  final String? badge;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final s = size ?? rowAvatar(pids.length) + 14;
    return Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.center, children: [
      for (final pid in pids)
        if (room.player(pid) case final p?)
          Stack(clipBehavior: Clip.none, children: [
            PbAvatar(size: s, emoji: p.emoji, color: p.color, photoPath: p.photo, dimmed: dim.contains(pid)),
            if (badge != null && !dim.contains(pid)) Positioned(right: -6, bottom: -6, child: Text(badge!, style: TextStyle(fontSize: s * .38))),
          ]),
    ]);
  }
}
