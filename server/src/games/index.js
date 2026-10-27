// Catalogue des jeux de PartyBroc.
// Un jeu prêt a une classe `impl` (create, start, stop, onMessage, publicState, playerState…).
// Tant que `ready` est faux, il s'affiche dans le salon mais ne peut pas être lancé.
import { QuizGame, QUIZ } from './quiz.js';
import { QuiDeNousGame, QDN } from './quidenous.js';
import { DrolesGame, DRL } from './droles.js';
import { ReflexesGame, RFX } from './reflexes.js';
import { DessinGame, DSN } from './dessin.js';

export const GAMES = [
  { id: 'dessin',    title: 'Dessin à deviner', emoji: '🎨', min: 3, ready: true, impl: DessinGame,
    pitch: 'Un joueur dessine sur son tel, les autres devinent.',
    options: { turns: { label: 'Tours chacun', values: DSN.turns, def: DSN.defaultTurns } } },
  { id: 'quiz',      title: 'Quiz culture G',   emoji: '🧠', min: 1, ready: true, impl: QuizGame,
    pitch: 'Le plus rapide à trouver la bonne réponse marque.',
    options: { count: { label: 'Questions', values: QUIZ.counts, def: QUIZ.defaultCount } } },
  { id: 'quidenous', title: 'Qui de nous ?',    emoji: '👀', min: 3, ready: true, impl: QuiDeNousGame,
    pitch: 'Votes anonymes : qui est le plus susceptible de… ?',
    options: { rounds: { label: 'Questions', values: QDN.rounds, def: QDN.defaultRounds } } },
  { id: 'reflexes',  title: 'Course de réflexes', emoji: '⚡', min: 1, ready: true, impl: ReflexesGame,
    pitch: 'Feu vert, marathon de taps, couleurs, emojis : le plus rapide gagne.',
    options: { trials: { label: 'Épreuves', values: RFX.trials, def: RFX.defaultTrials } } },
  { id: 'droles',    title: 'Réponses drôles',  emoji: '😂', min: 3, ready: true, impl: DrolesGame,
    pitch: 'Complète la phrase, tout le monde vote pour la meilleure.',
    options: { rounds: { label: 'Manches', values: DRL.rounds, def: DRL.defaultRounds } } },
];

export const gameById = (id) => GAMES.find((g) => g.id === id) || null;
