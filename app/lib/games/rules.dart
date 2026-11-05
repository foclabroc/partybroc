import 'package:flutter/material.dart';

import '../theme.dart';

/// Règles détaillées des jeux de société, ouvertes par le petit bouton « 📖 Règles »
/// en haut à gauche du téléphone pendant la partie. Garder à jour avec le serveur.
const gameRules = <String, (String, List<(String, List<String>)>)>{
  'pioche': (
    '🃏 Broc-Pioche',
    [
      ('But', ['Être le premier à poser toutes ses cartes.']),
      ('À ton tour', [
        'Pose une carte de la même couleur ou du même chiffre (ou du même symbole) que la carte du dessus.',
        'Les jokers se posent sur tout et tu choisis la nouvelle couleur.',
        'Tu ne peux pas jouer ? Pioche une carte. Si elle est jouable, tu peux la poser tout de suite, sinon « Passer ».',
        '25 secondes par tour.',
      ]),
      ('Cartes spéciales', [
        '⛔ Passe : le joueur suivant passe son tour.',
        '🔁 Sens inverse : on repart dans l’autre sens.',
        '+2 : le suivant pioche 2 cartes… sauf s’il pose lui aussi un +2 : ça s’additionne !',
        '+4 (joker) : le suivant pioche 4 cartes, et tu choisis la couleur. Les +2 et +4 se cumulent.',
      ]),
      ('« Dernière carte ! »', [
        'Quand il ne te reste qu’une carte, appuie sur « Dernière carte ! ».',
        'Si tu oublies, n’importe qui peut te dénoncer avant que le joueur suivant joue : tu pioches 2 cartes.',
      ]),
      ('Points', ['Classement dans l’ordre où on finit : 1000 pour le premier, puis 150 de moins à chaque place (100 au minimum).']),
    ],
  ),
  'oie': (
    '🪿 Jeu de l’oie',
    [
      ('But', ['Arriver le premier pile sur la case 63.']),
      ('À ton tour', [
        'Lance les 2 dés (20 secondes, sinon ils sont lancés pour toi) et avance de leur total.',
        'Si tu dépasses 63, tu recules du surplus.',
        'Premier lancer : 6 + 3 → case 26 ; 5 + 4 → case 53.',
      ]),
      ('Cases spéciales', [
        '🪿 Oie : tu avances encore du même nombre (les oies s’enchaînent).',
        '🌉 Pont (6) : tu vas directement en 12.',
        '🏨 Hôtel (19) : tu passes 2 tours.',
        '🕳️ Puits (31) et 🔒 Prison (52) : bloqué jusqu’à ce qu’un autre joueur y tombe et te délivre.',
        '🌀 Labyrinthe (42) : retour en 30.',
        '💀 Tête de mort (58) : retour au départ.',
        '❓ Défi (10, 26, 37, 48) : une question de quiz. Bonne réponse : +3 cases, mauvaise : -3.',
      ]),
      ('Points', ['Le gagnant marque 1000, les autres 12 points par case atteinte.']),
    ],
  ),
  'serpents': (
    '🐍 Serpents et échelles',
    [
      ('But', ['Arriver le premier sur la case 100.']),
      ('À ton tour', [
        'Lance le dé (20 secondes, sinon il est lancé pour toi) et avance case par case.',
        'Un 6 : tu rejoues !',
        'Option « Pile sur 100 » : il faut tomber exactement sur 100, sinon tu recules du surplus. Option « Dès 100 » : il suffit d’y arriver.',
      ]),
      ('Échelles et serpents', [
        '🪜 Tu t’arrêtes au pied d’une échelle : tu montes en haut.',
        '🐍 Tu t’arrêtes sur la tête d’un serpent : tu glisses jusqu’à sa queue.',
      ]),
      ('Points', ['Le gagnant marque 1000, les autres 8 points par case atteinte.']),
    ],
  ),
  'yams': (
    '🎲 Yams',
    [
      ('But', ['Faire le plus gros total en remplissant les 13 cases de sa feuille, en 13 tours.']),
      ('À ton tour', [
        'Lance les 5 dés. Tu as 3 lancers au maximum.',
        'Entre deux lancers, touche les dés que tu veux garder : seuls les autres sont relancés.',
        'Puis choisis une case libre de ta feuille. Elle vaut 0 si ta combinaison n’y est pas (tu « rayes » la case).',
        'Temps écoulé : les dés sont lancés si besoin et la meilleure case est remplie pour toi.',
      ]),
      ('Haut de la feuille', [
        'As, Deux… Six : le total des dés de ce chiffre (trois 5 = 15).',
        'Bonus de 35 points si le haut fait 63 ou plus (en gros, trois dés de chaque chiffre).',
      ]),
      ('Bas de la feuille', [
        'Brelan : 3 dés pareils, vaut le total des 5 dés.',
        'Carré : 4 dés pareils, vaut le total des 5 dés.',
        'Full : un brelan + une paire, 25 points.',
        'Petite suite : 4 chiffres qui se suivent, 30 points.',
        'Grande suite : 5 chiffres qui se suivent, 40 points.',
        'Yams : 5 dés pareils, 50 points.',
        'Chance : le total des 5 dés, n’importe quelle combinaison.',
      ]),
      ('Points', ['Ta note de la partie = le total de ta feuille.']),
    ],
  ),
  'skipbroc': (
    '🪜 Skip-Broc',
    [
      ('But', ['Vider son talon le premier.']),
      ('Les cartes', [
        'Des cartes de 1 à 12, et des ★ qui remplacent n’importe quel chiffre.',
        'Chacun a un talon caché (seule la carte du dessus est visible), une main de 5 cartes et 4 défausses à lui.',
        'Au milieu, 4 piles communes qu’on monte dans l’ordre de 1 à 12.',
      ]),
      ('À ton tour', [
        'Ta main est complétée à 5 cartes.',
        'Pose autant de cartes que tu veux sur les piles communes : une carte de ta main, le dessus de ton talon ou le dessus d’une de tes défausses. Il faut toujours le chiffre suivant (ou un ★).',
        'Tu as posé tes 5 cartes de main ? Tu en repioches 5 et tu continues.',
        'Pour finir ton tour, pose une carte de ta main sur une de tes 4 défausses (jamais une carte du talon).',
        '35 secondes par tour, plus 6 secondes à chaque carte posée. Temps écoulé : ta plus haute carte est défaussée pour toi.',
      ]),
      ('Piles complètes', ['Une pile qui arrive à 12 est retirée et ses cartes retournent dans la pioche.']),
      ('Astuces', [
        'Joue d’abord les cartes de ton talon : c’est lui qu’il faut vider.',
        'Range tes défausses en ordre descendant (9, 8, 7…) pour pouvoir les enchaîner.',
        'Garde tes ★ pour débloquer ton talon.',
      ]),
      ('Points', ['Le gagnant marque 1000, les autres 30 points par carte sortie de leur talon.']),
    ],
  ),
  'scrabroc': (
    '🔤 Scrabroc',
    [
      ('But', ['Marquer le plus de points en posant des mots sur le plateau.']),
      ('À ton tour', [
        'Touche une lettre de ton chevalet, puis une case du plateau. Touche une lettre posée pour la reprendre.',
        'Toutes les lettres d’un tour vont sur une même ligne ou une même colonne, sans trou.',
        'Le premier mot passe par l’étoile du centre. Ensuite, chaque mot touche un mot déjà posé.',
        'Le téléphone t’affiche les mots formés et les points avant de valider. Un mot inconnu est refusé : tu réessaies.',
        'Tu peux aussi échanger des lettres (s’il en reste au moins 7 dans le sac) ou passer.',
      ]),
      ('Points', [
        'Chaque lettre a sa valeur, écrite sur le jeton. Les jokers (sans lettre) valent 0.',
        'L×2 / L×3 : la lettre posée dessus compte double / triple.',
        'M×2 / M×3 (et l’étoile) : tout le mot compte double / triple.',
        'Les cases bonus ne comptent qu’au tour où on les recouvre.',
        'Tous les mots formés par ton coup comptent, y compris ceux en travers.',
        'Tes 7 lettres posées d’un coup : +50 !',
      ]),
      ('Fin de partie', [
        'Quand le sac est vide et qu’un joueur a posé toutes ses lettres : il gagne la valeur des lettres restantes des autres, qui la perdent.',
        'La partie s’arrête aussi si tout le monde passe plusieurs fois d’affilée.',
      ]),
    ],
  ),
  'pouilleux': (
    '🤡 Le Pouilleux',
    [
      ('But', ['Se débarrasser de toutes ses cartes et surtout ne pas garder le valet de pique : le Pouilleux !']),
      ('Le jeu', [
        '32 cartes jusqu’à 5 joueurs (du 7 à l’as), 52 au-delà. Le valet de trèfle est retiré : le valet de pique n’a plus de paire.',
        'Une paire = deux cartes de même valeur et de même couleur (rouge ou noire) : deux rois rouges, deux 8 noirs…',
        'Toutes les cartes sont distribuées et les paires déjà en main sont posées d’office au milieu.',
      ]),
      ('À ton tour', [
        'Touche une carte cachée chez ton voisin : tout le monde voit sur laquelle tu hésites. Change d’avis autant que tu veux, puis « Prendre cette carte ».',
        'Si elle forme une paire avec une de tes cartes, la paire part au milieu.',
        'Ensuite, c’est à ton voisin de piocher chez le sien.',
        'Sans réponse avant la fin du temps, une carte est prise au hasard.',
      ]),
      ('Ta main', [
        'Glisse tes cartes pour les ranger comme tu veux. Les autres les voient de dos, en miroir (comme assis en face).',
        'Quelqu’un hésite sur ta carte ? Elle se soulève en rouge sur ton téléphone : range-la ailleurs ou « Mélanger » pour brouiller les pistes !',
      ]),
      ('Fin de partie', [
        'Plus de cartes = sauvé ! Le premier sauvé gagne 1000 points, puis 150 de moins à chaque place.',
        'Le dernier, qui garde le valet de pique, est le Pouilleux : 0 point… et un gage si l’option est choisie.',
      ]),
    ],
  ),
  'loto': (
    '🎱 Loto',
    [
      ('But', ['Remplir des lignes de ses cartons avant les autres.']),
      ('Les cartons', [
        'Chaque carton a 3 lignes de 5 numéros (de 1 à 90).',
        'Au début, chacun choisit ses cartons dans sa liste (1 ou 2 selon l’hôte), puis appuie sur « Commencer ».',
      ]),
      ('Le tirage', [
        'La TV tire les boules une à une.',
        'Marquage « À la main » : touche les numéros sortis sur tes cartons, puis appuie sur le gros bouton pour annoncer ta ligne ou ton carton plein. Une fausse annonce te bloque 5 secondes.',
        'Marquage « Automatique » : tout se coche tout seul.',
        'Mode « Cartons papier » : on joue avec de vrais cartons, l’hôte vérifie quand quelqu’un crie.',
      ]),
      ('Prix', [
        'Une ligne : 300 points. Deux lignes : 500. Carton plein : 1000.',
        'Deux gagnants sur la même boule se partagent le prix.',
      ]),
    ],
  ),
  'photoroulette': (
    '📸 Photo roulette',
    [
      ('But', ['Deviner à qui appartient chaque photo.']),
      ('Comment ça marche', [
        'Au début, chacun choisit 3 à 5 photos dans la galerie de son téléphone.',
        'La TV les montre une par une : touche le joueur à qui elle est.',
        'Le propriétaire de la photo ne vote pas.',
      ]),
      ('Points', [
        'Bonne réponse : 500 points, plus un bonus de rapidité.',
        'Le propriétaire gagne 50 points par joueur trompé.',
        'Les photos sont effacées à la fin de la partie.',
      ]),
    ],
  ),
};

/// Le petit bouton « 📖 Règles » par-dessus le jeu en cours, en haut à gauche du téléphone
Widget withRules(String? gameId, Widget child) {
  final rules = gameId == null ? null : gameRules[gameId];
  if (rules == null) return child;
  return Stack(children: [
    child,
    Positioned(
      top: 0,
      left: 8,
      child: SafeArea(
        child: Builder(
          builder: (context) => TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.black26,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
            ),
            onPressed: () => showRules(context, gameId!),
            child: Text('📖 Règles', style: Pb.t(13, weight: 600, color: Pb.muted)),
          ),
        ),
      ),
    ),
  ]);
}

void showRules(BuildContext context, String gameId) {
  final (title, sections) = gameRules[gameId]!;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Pb.bg2,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .82,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 44, height: 5, decoration: BoxDecoration(color: Pb.muted.withValues(alpha: .4), borderRadius: BorderRadius.circular(9))),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 10, 4),
            child: Row(children: [
              Expanded(child: Text(title, style: Pb.t(24, weight: 700))),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, color: Pb.muted)),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
              children: [
                for (final (head, lines) in sections) ...[
                  const SizedBox(height: 12),
                  Text(head, style: Pb.t(18, weight: 700, color: Pb.yellow)),
                  const SizedBox(height: 6),
                  for (final l in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('•  ', style: Pb.t(16, color: Pb.muted)),
                        Expanded(child: Text(l, style: Pb.t(16, color: Pb.text).copyWith(height: 1.35))),
                      ]),
                    ),
                ],
              ],
            ),
          ),
        ]),
      ),
    ),
  );
}
