// Qui préfère… ? : chacun répond en secret à quelques questions perso (couleur préférée,
// plat préféré, année de naissance…) en touchant un choix, puis la TV demande
// « Qui préfère la couleur… Bleu ? » et tout le monde devine. Ceux qui ont fait ce choix
// ne votent pas (ils gagnent des points quand les autres se trompent).
// Les réponses restent dans la mémoire du jeu seulement, jamais en base.
import { fastTimings, shuffle } from './common.js';
import { RoundGame } from './round.js';

export const PRF = fastTimings({
  questions: [3, 4, 5],
  defaultQuestions: 4,
  rounds: [6, 10, 15],
  defaultRounds: 10,
  introMs: 6000,
  fillMs: 90000,
  askMs: 20000,
  revealMs: 7000,
  podiumMs: 25000,
  findPoints: 500,     // bonne personne trouvée
  speedPoints: 300,    // + rapidité (jusqu'à)
  fooledPoints: 50,    // pour chaque personne qui a fait ce choix, par joueur trompé
  minYear: 1920,
});

// Les questions. `ask` précède la réponse sur la TV : « Qui préfère la couleur… » + « 🔵 Bleu ».
// Année de naissance : `year` (saisie d'un nombre au lieu d'une liste).
export const QUESTIONS = [
  { id: 'couleur', q: 'Ta couleur préférée ?', ask: 'Qui préfère la couleur…', options: ['🔴 Rouge', '🔵 Bleu', '🟢 Vert', '🟡 Jaune', '🟠 Orange', '🟣 Violet', '🩷 Rose', '⚫ Noir', '⚪ Blanc', '🟤 Marron'] },
  { id: 'naissance', q: 'Ton année de naissance ?', ask: 'Qui est né en…', year: true },
  { id: 'plat', q: 'Ton plat préféré ?', ask: 'Qui a pour plat préféré…', options: ['🍕 La pizza', '🍔 Le burger', '🍝 Les pâtes', '🥘 Le couscous', '🧀 La raclette', '🍣 Les sushis', '🍗 Le poulet rôti', '🥩 Le steak-frites', '🦪 Les moules-frites', '🥔 La tartiflette', '🌮 Les tacos', '🍲 Le bœuf bourguignon'] },
  { id: 'saison', q: 'Ta saison préférée ?', ask: 'Qui préfère la saison…', options: ['🌸 Le printemps', '☀️ L’été', '🍂 L’automne', '❄️ L’hiver'] },
  { id: 'dessert', q: 'Ton dessert préféré ?', ask: 'Qui a pour dessert préféré…', options: ['🍫 La mousse au chocolat', '🍰 Le fraisier', '🍮 La crème brûlée', '🥧 La tarte aux pommes', '🍨 La glace', '🥞 Les crêpes', '🍩 Les beignets', '🧁 Le tiramisu'] },
  { id: 'animal', q: 'Ton animal préféré ?', ask: 'Qui a pour animal préféré…', options: ['🐶 Le chien', '🐱 Le chat', '🐴 Le cheval', '🐬 Le dauphin', '🦁 Le lion', '🐼 Le panda', '🐰 Le lapin', '🦉 La chouette', '🐢 La tortue', '🦊 Le renard'] },
  { id: 'vacances', q: 'Tes vacances idéales ?', ask: 'Qui préfère passer ses vacances…', options: ['🏖️ À la mer', '🏔️ À la montagne', '🌾 À la campagne', '🏙️ En ville', '🏠 À la maison', '🚐 En camping-car'] },
  { id: 'boisson', q: 'Ta boisson préférée ?', ask: 'Qui a pour boisson préférée…', options: ['💧 L’eau', '🥤 Le soda', '🧃 Le jus de fruits', '☕ Le café', '🍵 Le thé', '🍫 Le chocolat chaud', '🥛 Le lait', '🍋 La limonade'] },
  { id: 'fruit', q: 'Ton fruit préféré ?', ask: 'Qui a pour fruit préféré…', options: ['🍓 La fraise', '🍎 La pomme', '🍌 La banane', '🍊 L’orange', '🍉 La pastèque', '🍒 La cerise', '🍍 L’ananas', '🥭 La mangue', '🍑 La pêche', '🍇 Le raisin'] },
  { id: 'sport', q: 'Le sport que tu préfères (faire ou regarder) ?', ask: 'Qui préfère le sport…', options: ['⚽ Le football', '🏉 Le rugby', '🎾 Le tennis', '🏀 Le basket', '🚴 Le vélo', '🏊 La natation', '🏃 La course à pied', '⛷️ Le ski', '🥋 Le judo', '🛋️ Aucun, le canapé !'] },
  { id: 'film', q: 'Tes films préférés ?', ask: 'Qui préfère les films…', options: ['😂 Comiques', '💥 D’action', '😱 D’horreur', '💕 D’amour', '🚀 De science-fiction', '🧙 Fantastiques', '🎨 D’animation', '🕵️ Policiers'] },
  { id: 'moment', q: 'Ton moment préféré de la journée ?', ask: 'Qui préfère le moment…', options: ['🌅 Le matin', '🍽️ Le midi', '🌇 L’après-midi', '🌆 Le soir', '🌙 La nuit'] },
  { id: 'fete', q: 'Ta fête préférée ?', ask: 'Qui préfère la fête…', options: ['🎄 Noël', '🎂 Son anniversaire', '🎆 Le Nouvel An', '🎃 Halloween', '🐣 Pâques', '🎇 Le 14 Juillet'] },
  { id: 'pouvoir', q: 'Le super-pouvoir de tes rêves ?', ask: 'Qui rêverait du super-pouvoir…', options: ['🕊️ Voler', '👻 Être invisible', '✨ Se téléporter', '🧠 Lire dans les pensées', '⏸️ Arrêter le temps', '💪 Une force géante', '🗣️ Parler aux animaux'] },
  { id: 'musique', q: 'La musique que tu préfères ?', ask: 'Qui préfère écouter…', options: ['🎤 De la pop', '🎸 Du rock', '🎧 Du rap', '🎻 Du classique', '🪩 De l’électro', '🇫🇷 De la chanson française', '🎷 Du jazz', '🤠 De la country'] },
  { id: 'jour', q: 'Ton jour préféré de la semaine ?', ask: 'Qui préfère le…', options: ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'] },
  { id: 'petitdej', q: 'Au petit-déjeuner, tu prends plutôt… ?', ask: 'Au petit-déjeuner, qui prend…', options: ['🥐 Des viennoiseries', '🥖 Des tartines', '🥣 Des céréales', '🍳 Des œufs', '🍎 Un fruit', '☕ Juste un café', '🚫 Rien du tout'] },
  { id: 'transport', q: 'Pour voyager, tu préfères… ?', ask: 'Qui préfère voyager en…', options: ['🚗 Voiture', '🚆 Train', '✈️ Avion', '🚢 Bateau', '🚲 Vélo', '🏍️ Moto', '🚌 Car'] },
  { id: 'pays', q: 'Le pays où tu rêverais d’aller ?', ask: 'Qui rêverait d’aller…', options: ['🇺🇸 Aux États-Unis', '🇯🇵 Au Japon', '🇮🇹 En Italie', '🇪🇸 En Espagne', '🇨🇦 Au Canada', '🇦🇺 En Australie', '🇬🇷 En Grèce', '🇹🇭 En Thaïlande', '🇧🇷 Au Brésil', '🇲🇦 Au Maroc'] },
  { id: 'chiffre', q: 'Ton chiffre porte-bonheur ?', ask: 'Qui a pour chiffre porte-bonheur le…', options: ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'] },
  { id: 'jeu', q: 'Ton jeu de société préféré ?', ask: 'Qui a pour jeu préféré…', options: ['🎩 Le Monopoly', '🔤 Le Scrabble', '🃏 Le Uno', '♟️ Les échecs', '🎲 Les petits chevaux', '🀄 Les dominos', '❓ Le Trivial Pursuit', '🔴 Le Puissance 4'] },
  { id: 'peur', q: 'Ce qui te fait le plus peur ?', ask: 'Qui a le plus peur…', options: ['🕷️ Des araignées', '🐍 Des serpents', '🌑 Du noir', '🏔️ Du vide', '🌊 De l’eau profonde', '🤡 Des clowns', '🩺 Du dentiste', '⛈️ De l’orage'] },
];

const thisYear = () => new Date().getFullYear();

export class PreferencesGame extends RoundGame {
  static id = 'preferences';

  static async create(room, opts, hooks) {
    return new PreferencesGame(room, hooks, opts);
  }

  constructor(room, hooks, opts) {
    super(room, hooks, { id: 'preferences', count: 0, answerType: 'prf_guess', ...PRF });
    const nq = PRF.questions.includes(opts?.questions) ? opts.questions : PRF.defaultQuestions;
    this.wanted = PRF.rounds.includes(opts?.rounds) ? opts.rounds : PRF.defaultRounds;
    // Les mêmes questions pour tout le monde (on compare les réponses entre joueurs)
    this.qs = shuffle([...QUESTIONS]).slice(0, nq);
    this.filled = new Map();    // pid -> [réponse ou null, …]
    for (const p of this.active()) this.filled.set(p.pid, this.qs.map(() => null));
    this.entries = [];
  }

  start() {
    this.schedule(PRF.introMs, () => this.fill());
  }

  fill() {
    this.phase = 'fill';
    this.schedule(PRF.fillMs, () => this.build());
    this.changed();
  }

  doneFilling(pid) { return (this.filled.get(pid) || []).every((v) => v !== null); }

  // Qui a fait ce choix (parmi les joueurs encore là)
  holders(qi, value) {
    return [...this.filled].filter(([pid, list]) => list[qi] === value && this.room.players.has(pid)).map(([pid]) => pid);
  }

  // Les manches : un choix fait par au moins un joueur, mais pas par presque tout le monde
  // (sinon il n'y a rien à deviner). Les choix rares d'abord, puis mélangés.
  build() {
    if (this.phase !== 'fill') return;
    const players = [...this.filled.keys()].filter((pid) => this.room.players.has(pid));
    const seen = new Set();
    const all = [];
    for (const [pid, list] of this.filled) {
      if (!this.room.players.has(pid)) continue;
      list.forEach((value, qi) => {
        const key = `${qi}|${value}`;
        if (value === null || seen.has(key)) return;
        seen.add(key);
        const who = this.holders(qi, value);
        if (players.length - who.length < 1) return; // tout le monde a choisi pareil
        all.push({ qi, value, holders: who });
      });
    }
    // Les choix d'une seule personne sont les plus drôles à deviner
    const pool = shuffle(all).sort((a, b) => a.holders.length - b.holders.length);
    const picked = shuffle(pool.slice(0, this.wanted));
    // Pas deux fois la même question d'affilée si possible
    const ordered = [];
    while (picked.length) {
      const i = picked.findIndex((e) => e.qi !== ordered.at(-1)?.qi);
      ordered.push(...picked.splice(i < 0 ? 0 : i, 1));
    }
    this.entries = ordered;
    this.count = ordered.length;
    if (this.count === 0) return this.podium(PRF.podiumMs);
    this.next();
  }

  makeRound(i) { return this.entries[i]; }

  // Ceux qui ont fait ce choix ne votent pas
  answerers() { return this.active().filter((p) => !this.round?.holders.includes(p.pid)); }

  accept(p, m) {
    return typeof m.pid === 'string' && m.pid !== p.pid && this.room.players.has(m.pid) ? m.pid : undefined;
  }

  scoreRound() {
    const { holders } = this.round;
    let fooled = 0;
    for (const [pid, a] of this.answers) {
      if (holders.includes(a.v)) this.addPoints(pid, PRF.findPoints + Math.round((PRF.speedPoints * this.speed(a.at)) / 10) * 10);
      else fooled++;
    }
    if (fooled) for (const h of holders) this.addPoints(h, fooled * PRF.fooledPoints);
  }

  onOther(p, m) {
    if (m.t !== 'prf_fill') return false;
    if (this.phase !== 'fill' || !this.filled.has(p.pid)) return true;
    const qi = m.q;
    const list = this.filled.get(p.pid);
    if (!Number.isInteger(qi) || qi < 0 || qi >= list.length) return true;
    const q = this.qs[qi];
    let v = null;
    if (q.year) {
      const y = Number(m.v);
      if (Number.isInteger(y) && y >= PRF.minYear && y <= thisYear()) v = String(y);
    } else if (typeof m.v === 'string' && q.options.includes(m.v)) {
      v = m.v;
    }
    if (v === null) return true;
    list[qi] = v;
    if (this.active().every((x) => !this.filled.has(x.pid) || this.doneFilling(x.pid))) this.schedule(800, () => this.build());
    this.changed();
    return true;
  }

  onPlayerGone() {
    if (this.phase === 'fill' && this.active().every((x) => !this.filled.has(x.pid) || this.doneFilling(x.pid))) this.schedule(800, () => this.build());
    else super.onPlayerGone();
  }

  // L'hôte : depuis l'intro on passe aux réponses secrètes, et il peut les couper
  onMessage(p, m) {
    if (m.t === 'game_skip' && p.pid === this.room.hostPid) {
      if (this.phase === 'intro') return this.fill();
      if (this.phase === 'fill') return this.build();
    }
    return super.onMessage(p, m);
  }

  publicRound(reveal) {
    const q = this.qs[this.round.qi];
    // Pendant la question : seulement le nombre de votes (montrer qui vote trahirait qui a fait ce choix)
    const s = { qid: q.id, ask: q.ask, value: this.round.value, votes: this.answers.size };
    if (reveal) {
      s.holders = this.round.holders;
      s.picks = Object.fromEntries([...this.answers].map(([pid, a]) => [pid, a.v]));
    }
    return s;
  }

  publicState() {
    const s = super.publicState();
    if (this.phase === 'fill') {
      s.done = [...this.filled.keys()].filter((pid) => this.doneFilling(pid));
      s.questions = this.qs.map((q) => q.q);
    }
    return s;
  }

  playerRound(pid) {
    const r = { mine: !!this.round?.holders.includes(pid) && ['ask', 'reveal'].includes(this.phase) };
    if (this.phase === 'fill') {
      r.form = this.qs.map((q) => ({ q: q.q, options: q.options ?? null, year: !!q.year }));
      r.filled = this.filled.get(pid) || [];
      r.maxYear = thisYear();
    }
    return r;
  }
}
