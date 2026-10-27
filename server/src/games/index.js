// Catalogue des jeux de PartyBroc.
// Chaque jeu sera un module qui exporte create(room) ; tant que `ready` est faux,
// il s'affiche dans le salon mais ne peut pas être lancé.
export const GAMES = [
  { id: 'dessin',    title: 'Dessin à deviner', emoji: '🎨', min: 3, ready: false,
    pitch: 'Un joueur dessine sur son tel, les autres devinent.' },
  { id: 'quiz',      title: 'Quiz culture G',   emoji: '🧠', min: 2, ready: false,
    pitch: 'Le plus rapide à trouver la bonne réponse marque.' },
  { id: 'quidenous', title: 'Qui de nous ?',    emoji: '👀', min: 3, ready: false,
    pitch: 'Votes anonymes : qui est le plus susceptible de… ?' },
  { id: 'reflexes',  title: 'Course de réflexes', emoji: '⚡', min: 2, ready: false,
    pitch: 'Tape, secoue, réagis : le plus rapide gagne.' },
  { id: 'droles',    title: 'Réponses drôles',  emoji: '😂', min: 3, ready: false,
    pitch: 'Complète la phrase, tout le monde vote pour la meilleure.' },
];

export const gameById = (id) => GAMES.find((g) => g.id === id) || null;
