import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Télécommande : flèches = changer de bouton (même depuis un champ de texte, sinon on
/// y reste coincé), OK = appuyer. Les répétitions automatiques d'une touche sont ignorées :
/// une touche « bloquée » faisait défiler le focus tout seul d'un bouton à l'autre.
const Map<ShortcutActivator, Intent> tvShortcuts = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.arrowLeft, includeRepeats: false):
      DirectionalFocusIntent(TraversalDirection.left, ignoreTextFields: false),
  SingleActivator(LogicalKeyboardKey.arrowRight, includeRepeats: false):
      DirectionalFocusIntent(TraversalDirection.right, ignoreTextFields: false),
  SingleActivator(LogicalKeyboardKey.arrowUp, includeRepeats: false):
      DirectionalFocusIntent(TraversalDirection.up, ignoreTextFields: false),
  SingleActivator(LogicalKeyboardKey.arrowDown, includeRepeats: false):
      DirectionalFocusIntent(TraversalDirection.down, ignoreTextFields: false),
  SingleActivator(LogicalKeyboardKey.select, includeRepeats: false): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.numpadEnter, includeRepeats: false): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.gameButtonA, includeRepeats: false): ActivateIntent(),
};

/// À mettre autour de chaque écran ET de chaque boîte de dialogue : une boîte de dialogue
/// s'ouvre au-dessus de l'écran, hors de ses raccourcis.
class TvKeys extends StatelessWidget {
  const TvKeys({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Shortcuts(shortcuts: tvShortcuts, child: child);
}
