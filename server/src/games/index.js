// Catalogue des jeux de PartyBroc.
// Un jeu prêt a une classe `impl` (create, start, stop, onMessage, publicState, playerState…).
// Tant que `ready` est faux, il s'affiche dans le salon mais ne peut pas être lancé.
import { QuizGame, QUIZ } from './quiz.js';
import { QuiDeNousGame, QDN } from './quidenous.js';
import { DrolesGame, DRL } from './droles.js';
import { ReflexesGame, RFX } from './reflexes.js';
import { DessinGame, DSN } from './dessin.js';
import { JustePrixGame, JP } from './justeprix.js';
import { QuiAditGame, QAD } from './quiadit.js';
import { CalculGame, CALC } from './calcul.js';
import { MemoireGame, MEM } from './memoire.js';
import { PetitBacGame, PBAC } from './petitbac.js';
import { ZoomGame, ZOOM } from './zoom.js';
import { SurvieGame, SURV } from './survie.js';
import { PhotoRouletteGame, PHR } from './photoroulette.js';

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
    pitch: '8 épreuves éclair : feu vert, cibles, flèches, chrono… le plus rapide gagne.',
    options: { trials: { label: 'Épreuves', values: RFX.trials, def: RFX.defaultTrials } } },
  { id: 'droles',    title: 'Réponses drôles',  emoji: '😂', min: 3, ready: true, impl: DrolesGame,
    pitch: 'Complète la phrase, tout le monde vote pour la meilleure.',
    options: { rounds: { label: 'Manches', values: DRL.rounds, def: DRL.defaultRounds } } },
  { id: 'justeprix', title: 'Le juste prix',    emoji: '💶', min: 1, ready: true, impl: JustePrixGame,
    pitch: 'Un objet du quotidien : le prix le plus proche gagne.',
    options: { rounds: { label: 'Objets', values: JP.rounds, def: JP.defaultRounds } } },
  { id: 'quiadit',   title: 'Qui a dit ça ?',   emoji: '💬', min: 3, ready: true, impl: QuiAditGame,
    pitch: 'Réponds en secret, puis devine qui a écrit quoi.',
    options: { rounds: { label: 'Réponses', values: QAD.rounds, def: QAD.defaultRounds } } },
  { id: 'calcul',    title: 'Course de calcul', emoji: '➗', min: 1, ready: true, impl: CalculGame,
    pitch: 'Le plus rapide à trouver le bon résultat.',
    options: {
      level: { label: 'Niveau', values: CALC.levels, def: CALC.defaultLevel },
      rounds: { label: 'Calculs', values: CALC.rounds, def: CALC.defaultRounds },
    } },
  { id: 'memoire',   title: 'Mémoire',          emoji: '🧩', min: 1, ready: true, impl: MemoireGame,
    pitch: 'Regarde bien l’image, elle va disparaître…',
    options: { rounds: { label: 'Images', values: MEM.rounds, def: MEM.defaultRounds } } },
  { id: 'petitbac',  title: 'Petit bac',        emoji: '✍️', min: 2, ready: true, impl: PetitBacGame,
    pitch: 'Une lettre, 5 catégories : vite, un mot pour chacune !',
    options: { rounds: { label: 'Lettres', values: PBAC.rounds, def: PBAC.defaultRounds } } },
  { id: 'zoom',      title: 'Zoom mystère',     emoji: '🔍', min: 1, ready: true, impl: ZoomGame,
    pitch: 'Une image très zoomée : trouve ce que c’est avant les autres.',
    options: { rounds: { label: 'Images', values: ZOOM.rounds, def: ZOOM.defaultRounds } } },
  { id: 'survie',    title: 'Le dernier debout', emoji: '🏁', min: 2, ready: true, impl: SurvieGame,
    pitch: 'Vrai ou faux ? Une erreur et tu es éliminé.',
    options: { rounds: { label: 'Questions max', values: SURV.rounds, def: SURV.defaultRounds } } },
  { id: 'photoroulette', title: 'Photo roulette', emoji: '📸', min: 3, ready: true, impl: PhotoRouletteGame,
    pitch: 'Chacun choisit des photos de son tel : à qui est celle-ci ?',
    options: { per: { label: 'Photos chacun', values: PHR.perPlayer, def: PHR.defaultPerPlayer } } },
];

export const gameById = (id) => GAMES.find((g) => g.id === id) || null;
