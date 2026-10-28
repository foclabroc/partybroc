import 'package:flutter/material.dart';

/// Couleurs et styles de PartyBroc : fond nuit violette, accents néon chauds.
class Pb {
  static const bg = Color(0xFF17102B);
  static const bg2 = Color(0xFF231944);
  static const card = Color(0xFF2E2257);
  static const cardHi = Color(0xFF3B2D6E);
  static const text = Color(0xFFF7F2FF);
  static const muted = Color(0xFFB3A6D9);
  static const pink = Color(0xFFFF4FA3);
  static const yellow = Color(0xFFFFD23F);
  static const cyan = Color(0xFF3FE0FF);
  static const green = Color(0xFF4CE38A);
  static const red = Color(0xFFFF5A5A);

  /// Couleurs de profil (même ordre que côté serveur : 12 couleurs)
  static const playerColors = <Color>[
    Color(0xFFFF4FA3), Color(0xFFFF8A3D), Color(0xFFFFD23F), Color(0xFF9BE15D),
    Color(0xFF4CE38A), Color(0xFF3FE0FF), Color(0xFF4F8BFF), Color(0xFF8E6BFF),
    Color(0xFFC86BFF), Color(0xFFFF6B6B), Color(0xFF2EC4B6), Color(0xFFE0C3A0),
  ];

  static Color playerColor(int i) => playerColors[i % playerColors.length];

  /// Les 4 réponses du quiz : une couleur et une forme chacune (lisible même en daltonien)
  static const answerColors = <Color>[Color(0xFFFF4F7B), Color(0xFF3FA9FF), Color(0xFFFFC23F), Color(0xFF3FD07A)];
  static const answerIcons = <IconData>[
    Icons.change_history_rounded, Icons.square_rounded, Icons.circle, Icons.star_rounded,
  ];

  /// Emoji de chaque catégorie du quiz
  static String categoryEmoji(String? c) => switch (c) {
        'Géographie' => '🌍',
        'Histoire' => '🏰',
        'Sciences' => '🔬',
        'Cinéma & séries' => '🎬',
        'Musique' => '🎵',
        'Sport' => '⚽',
        'Nature & animaux' => '🦁',
        'Cuisine' => '🍳',
        'Technologie' => '💻',
        _ => '💡',
      };

  /// 1 234 au lieu de 1234
  static String pts(num n) {
    final s = n.round().abs().toString();
    final b = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('\u00A0');
      b.write(s[i]);
    }
    return b.toString();
  }

  /// Emojis proposés quand on ne met pas de photo
  static const emojis = <String>[
    '🦊', '🐸', '🐼', '🐯', '🦁', '🐵', '🐙', '🦄', '🐲', '🐧', '🦉', '🐻',
    '🐱', '🐶', '🐷', '🐔', '🦖', '🐝', '🍕', '🌮', '🍩', '🍔', '🎸', '🚀',
    '👽', '🤖', '👻', '🤠', '😎', '🥳', '🤡', '💀',
  ];

  static TextStyle t(double size, {double weight = 500, Color color = text, double? height}) => TextStyle(
        fontFamily: 'Fredoka',
        fontSize: size,
        color: color,
        height: height,
        fontVariations: [FontVariation('wght', weight)],
      );

  static ThemeData theme() {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'Fredoka',
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: pink,
        secondary: yellow,
        surface: card,
        onPrimary: Colors.white,
        onSurface: text,
        error: red,
      ),
    );
    return base.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: pink, width: 2),
        ),
        hintStyle: t(18, color: muted.withValues(alpha: .6)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: pink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: cardHi,
          minimumSize: const Size.fromHeight(58),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: t(20, weight: 600),
        ).copyWith(side: _focusSide),
      ),
      // Télécommande : le bouton qui a le focus est entouré de blanc
      focusColor: Colors.white24,
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: const BorderSide(color: cardHi, width: 2),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: t(17, weight: 500),
        ).copyWith(side: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.focused)
            ? const BorderSide(color: Colors.white, width: 4)
            : const BorderSide(color: cardHi, width: 2))),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardHi,
        contentTextStyle: t(16),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

const _focusSide = WidgetStateProperty<BorderSide?>.fromMap(<WidgetStatesConstraint, BorderSide?>{
  WidgetState.focused: BorderSide(color: Colors.white, width: 4),
  WidgetState.any: null,
});

/// Fond commun : dégradé nuit avec deux halos de couleur
class PartyBackground extends StatelessWidget {
  const PartyBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF241548), Pb.bg, Color(0xFF0F0A1F)],
        ),
      ),
      child: Stack(children: [
        Positioned(top: -160, right: -120, child: _halo(Pb.pink.withValues(alpha: .22), 420)),
        Positioned(bottom: -200, left: -140, child: _halo(Pb.cyan.withValues(alpha: .14), 480)),
        Positioned.fill(child: RepaintBoundary(child: child)),
      ]),
    );
  }

  static Widget _halo(Color c, double size) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)]),
          ),
        ),
      );
}

/// Logo texte « PartyBroc »
class PbLogo extends StatelessWidget {
  const PbLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'Party', style: Pb.t(size, weight: 700, color: Pb.text)),
        TextSpan(text: 'Broc', style: Pb.t(size, weight: 700, color: Pb.pink)),
        TextSpan(text: ' 🎉', style: TextStyle(fontSize: size * .8)),
      ]),
    );
  }
}
