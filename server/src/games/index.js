// Catalogue des jeux de PartyBroc.
// Un jeu prêt a une classe `impl` (create, start, stop, onMessage, publicState, playerState…).
// Tant que `ready` est faux, il s'affiche dans le salon mais ne peut pas être lancé.
import { QuizGame, QUIZ } from './quiz.js';

export const GAMES = [
  { id: 'dessin',    title: 'Dessin à deviner', emoji: '🎨', min: 3, ready: false,
    pitch: 'Un joueur dessine sur son tel, les autres devinent.' },
  { id: 'quiz',      title: 'Quiz culture G',   emoji: '🧠', min: 1, ready: true, impl: QuizGame,
    pitch: 'Le plus rapide à trouver la bonne réponse marque.',
    options: { count: { label: 'Questions', values: QUIZ.counts, def: QUIZ.defaultCount } } },
  { id: 'quidenous', title: 'Qui de nous ?',    emoji: '👀', min: 3, ready: false,
    pitch: 'Votes anonymes : qui est le plus susceptible de… ?' },
  { id: 'reflexes',  title: 'Course de réflexes', emoji: '⚡', min: 2, ready: false,
    pitch: 'Tape, secoue, réagis : le plus rapide gagne.' },
  { id: 'droles',    title: 'Réponses drôles',  emoji: '😂', min: 3, ready: false,
    pitch: 'Complète la phrase, tout le monde vote pour la meilleure.' },
];

export const gameById = (id) => GAMES.find((g) => g.id === id) || null;
