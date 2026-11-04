// Catalogue des jeux de PartyBroc. cat : onglet « Jeux de société » (societe) ou « Jeux fun » (fun).
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
import { PreferencesGame, PRF } from './preferences.js';
import { ZoomGame, ZOOM } from './zoom.js';
import { SurvieGame, SURV } from './survie.js';
import { PhotoRouletteGame, PHR } from './photoroulette.js';
import { RebusGame, RBS } from './rebus.js';
import { ExpressionsGame, EXP } from './expressions.js';
import { PiocheGame, PCH } from './pioche.js';
import { OieGame } from './oie.js';
import { LotoGame, LOTO } from './loto.js';

export const GAMES = [
  { id: 'dessin',    title: 'Dessin à deviner', emoji: '🎨', min: 3, cat: 'fun', ready: true, impl: DessinGame,
    pitch: 'Un joueur dessine sur son tel, les autres devinent.',
    options: { turns: { label: 'Tours chacun', values: DSN.turns, def: DSN.defaultTurns } } },
  { id: 'quiz',      title: 'Quiz culture G',   emoji: '🧠', min: 1, cat: 'fun', ready: true, impl: QuizGame,
    pitch: 'Le plus rapide à trouver la bonne réponse marque.',
    options: { count: { label: 'Questions', values: QUIZ.counts, def: QUIZ.defaultCount } } },
  { id: 'quidenous', title: 'Qui de nous ?',    emoji: '👀', min: 3, cat: 'fun', ready: true, impl: QuiDeNousGame,
    pitch: 'Votes anonymes : qui est le plus susceptible de… ?',
    options: { rounds: { label: 'Questions', values: QDN.rounds, def: QDN.defaultRounds } } },
  { id: 'reflexes',  title: 'Course de réflexes', emoji: '⚡', min: 1, cat: 'fun', ready: true, impl: ReflexesGame,
    pitch: '8 épreuves éclair : feu vert, cibles, flèches, chrono… le plus rapide gagne.',
    options: { trials: { label: 'Épreuves', values: RFX.trials, def: RFX.defaultTrials } } },
  { id: 'droles',    title: 'Réponses drôles',  emoji: '😂', min: 3, cat: 'fun', ready: true, impl: DrolesGame,
    pitch: 'Complète la phrase, tout le monde vote pour la meilleure.',
    options: { rounds: { label: 'Manches', values: DRL.rounds, def: DRL.defaultRounds } } },
  { id: 'justeprix', title: 'Le juste prix',    emoji: '💶', min: 1, cat: 'fun', ready: true, impl: JustePrixGame,
    pitch: 'Un objet du quotidien : le prix le plus proche gagne.',
    options: { rounds: { label: 'Objets', values: JP.rounds, def: JP.defaultRounds } } },
  { id: 'quiadit',   title: 'Qui a dit ça ?',   emoji: '💬', min: 3, cat: 'fun', ready: true, impl: QuiAditGame,
    pitch: 'Réponds en secret, puis devine qui a écrit quoi.',
    options: { rounds: { label: 'Réponses', values: QAD.rounds, def: QAD.defaultRounds } } },
  { id: 'calcul',    title: 'Course de calcul', emoji: '➗', min: 1, cat: 'fun', ready: true, impl: CalculGame,
    pitch: 'Le plus rapide à trouver le bon résultat.',
    options: {
      level: { label: 'Niveau', values: CALC.levels, def: CALC.defaultLevel },
      rounds: { label: 'Calculs', values: CALC.rounds, def: CALC.defaultRounds },
    } },
  { id: 'memoire',   title: 'Mémoire',          emoji: '🧩', min: 1, cat: 'fun', ready: true, impl: MemoireGame,
    pitch: 'Regarde bien l’image, elle va disparaître…',
    options: { rounds: { label: 'Images', values: MEM.rounds, def: MEM.defaultRounds } } },
  { id: 'preferences', title: 'Qui préfère… ?', emoji: '💖', min: 3, cat: 'fun', ready: true, impl: PreferencesGame,
    pitch: 'Couleur, plat, saison… préférés : devine qui a choisi quoi !',
    options: {
      questions: { label: 'Questions chacun', values: PRF.questions, def: PRF.defaultQuestions },
      rounds: { label: 'Manches', values: PRF.rounds, def: PRF.defaultRounds },
    } },
  { id: 'zoom',      title: 'Zoom mystère',     emoji: '🔍', min: 1, cat: 'fun', ready: true, impl: ZoomGame,
    pitch: 'Une image très zoomée : trouve ce que c’est avant les autres.',
    options: { rounds: { label: 'Images', values: ZOOM.rounds, def: ZOOM.defaultRounds } } },
  { id: 'survie',    title: 'Le dernier debout', emoji: '🏁', min: 2, cat: 'fun', ready: true, impl: SurvieGame,
    pitch: 'Vrai ou faux ? Une erreur et tu es éliminé.',
    options: { rounds: { label: 'Questions max', values: SURV.rounds, def: SURV.defaultRounds } } },
  { id: 'photoroulette', title: 'Photo roulette', emoji: '📸', min: 3, cat: 'societe', ready: true, impl: PhotoRouletteGame,
    pitch: 'Chacun choisit des photos de son tel : à qui est celle-ci ?',
    options: { per: { label: 'Photos chacun', values: PHR.perPlayer, def: PHR.defaultPerPlayer } } },
  { id: 'rebus',     title: 'Emoji rébus',      emoji: '🧐', min: 1, cat: 'fun', ready: true, impl: RebusGame,
    pitch: 'Des emojis sur la TV : quel film, quelle expression, quel métier ?',
    options: { rounds: { label: 'Rébus', values: RBS.rounds, def: RBS.defaultRounds } } },
  { id: 'expressions', title: 'Expressions à trous', emoji: '🗣️', min: 1, cat: 'fun', ready: true, impl: ExpressionsGame,
    pitch: 'Avoir un poil dans la… ? Trouve le mot qui manque !',
    options: { rounds: { label: 'Expressions', values: EXP.rounds, def: EXP.defaultRounds } } },
  { id: 'pioche',    title: 'Broc-Pioche',      emoji: '🃏', min: 2, cat: 'societe', ready: true, impl: PiocheGame,
    pitch: 'Pose la même couleur ou le même symbole, vide ta main le premier !',
    options: { cards: { label: 'Cartes en main', values: PCH.hands, def: PCH.defaultHand } } },
  { id: 'oie',       title: 'Jeu de l’oie',     emoji: '🎲', min: 2, cat: 'societe', ready: true, impl: OieGame,
    pitch: 'Lance les dés, avance sur le plateau, gare au puits !' },
  { id: 'loto',      title: 'Loto',             emoji: '🎱', min: 1, cat: 'societe', ready: true, impl: LotoGame,
    pitch: 'La TV tire les boules : quine, double quine, carton plein !',
    options: {
      mode: { label: 'On joue avec', values: LOTO.modes, def: LOTO.defaultMode },
      cartons: { label: 'Cartons chacun', values: LOTO.cartons, def: LOTO.defaultCartons },
      vitesse: { label: 'Vitesse', values: LOTO.speeds, def: LOTO.defaultSpeed },
      marquage: { label: 'Marquage', values: LOTO.marks, def: LOTO.defaultMarks },
    } },
];

// Onglets du choix des jeux (téléphone de l'hôte et salon TV)
export const CATEGORIES = [
  { id: 'societe', title: 'Jeux de société', emoji: '🎲' },
  { id: 'fun', title: 'Jeux fun', emoji: '🎉' },
];

export const gameById = (id) => GAMES.find((g) => g.id === id) || null;
