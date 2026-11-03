// Expressions à trous : la TV affiche une expression française avec un mot caché
// (« Avoir un poil dans la ___ »), chacun choisit le bon mot parmi 4 sur son téléphone.
// Une manche sur quatre est inversée : « Que veut dire… ? », avec 4 sens au choix
// (les 3 faux sont pris dans d'autres expressions, sans mot important en commun).
// Contenu dans pb_expressions (sql/14_expressions.sql).
import { db } from '../db.js';
import { fastTimings, fold, loadContent, shuffle } from './common.js';
import { RoundGame } from './round.js';

export const EXP = fastTimings({
  rounds: [6, 10, 15],
  defaultRounds: 10,
  introMs: 6000,
  askMs: 20000,
  senseAskMs: 25000,  // il y a plus à lire
  revealMs: 7000,
  podiumMs: 25000,
  minPoints: 200,     // bonne réponse
  speedPoints: 800,   // + rapidité (jusqu'à)
  senseEvery: 4,      // une manche « Que veut dire… ? » sur 4 (la 4e, la 8e…)
});

// Mots qui ne comptent pas pour comparer deux sens (« Être très… », « Avoir… »)
const STOP = new Set(['etre', 'avoir', 'faire', 'tres', 'tout', 'toute', 'tous', 'plus', 'moins', 'bien', 'quelqu',
  'quelque', 'chose', 'choses', 'sans', 'pour', 'avec', 'dans', 'mais', 'quand', 'comme', 'meme', 'leur', 'soi',
  'une', 'des', 'les', 'qui', 'que', 'est', 'pas', 'ses', 'son', 'sur', 'aux', 'cest', 'quon', 'peut', 'vaut', 'mieux']);
// Familles de mots de même sens : deux sens qui en partagent une ne vont jamais ensemble
// (« Être ravi » / « Être fou de joie »)
const FAMILIES = [
  ['heureux', 'joie', 'joyeux', 'ravi', 'content', 'optimiste', 'amuse', 'rire', 'rit'],
  ['surpris', 'stupefait', 'etonne', 'ahuri', 'ebahi'],
  ['colere', 'fache', 'facher', 'emporte', 'emporter', 'rage', 'gronder', 'severement'],
  ['faim', 'manger', 'mangeant'],
  ['evanouir', 'mourir'],
  ['riche', 'luxe', 'richesse', 'enrichit'],
  ['argent', 'ruine', 'radin', 'depenser', 'depense', 'budget', 'payer', 'gratuitement', 'economies', 'cher'],
  ['dormir', 'profondement', 'tard'],
  ['bete', 'naif', 'fou', 'raison'],
  ['peur', 'peureux', 'frissons', 'danger', 'menace', 'risques', 'risquer', 'prudent'],
  ['abandonner', 'renoncer', 'renonce', 'reculer', 'decourage'],
  ['facile', 'difficile', 'difficultes', 'difficulte', 'probleme', 'problemes', 'catastrophe', 'echouer', 'echoue', 'perdu', 'rate'],
  ['inquieter', 'inquiete', 'peine', 'triste'],
  ['mensonges', 'tromper', 'trompeur', 'eblouir', 'faire'],
  ['paresseux', 'rien', 'inutile'],
  ['parler', 'bavard', 'taire', 'secret', 'franchement', 'franc', 'dire', 'cacher', 'cache', 'cacher'],
  ['amoureux', 'amour', 'aime', 'sentimental', 'partenaire'],
  ['evident', 'clair', 'clairement', 'deviner', 'intuition', 'douter', 'lucide'],
  ['jamais', 'rarement', 'temps', 'patience', 'attendre', 'longtemps', 'interminable', 'presse'],
  ['commencer', 'debuter', 'demarrer', 'decider', 'decide', 'hesiter'],
  ['ennemi', 'dispute', 'conflit', 'differend', 'relations', 'entendre', 'tension', 'paix'],
  ['aider', 'entraider', 'proteger', 'ensemble', 'participer'],
  ['ressembler', 'ressemblent', 'meme', 'inseparables', 'proches', 'situation'],
  ['malade', 'sante', 'forme', 'fievre', 'epuise', 'epuiser', 'forces'],
  ['regarder', 'voir', 'vue', 'observateur', 'ecouter', 'entend'],
  ['habille', 'habiller', 'elegamment'],
  ['enfuir', 'partir', 'fermer', 'aller'],
];
const FAMILY = new Map(FAMILIES.flatMap((f, i) => f.map((w) => [w, `#${i}`])));
const words = (s) => new Set(fold(s).split(/[^a-z]+/).filter((w) => w.length > 2 && !STOP.has(w)).map((w) => FAMILY.get(w) ?? w));

export class ExpressionsGame extends RoundGame {
  static id = 'expressions';

  static async create(room, opts, hooks) {
    const n = EXP.rounds.includes(opts?.rounds) ? opts.rounds : EXP.defaultRounds;
    const rows = await loadContent(db, room, 'pb_expressions', 'text, answer, wrong1, wrong2, wrong3, meaning', n,
      'Aucune expression en base (sql/14_expressions.sql)');
    // Réserve de sens pour les fausses réponses des manches « Que veut dire… ? »
    const pool = (await db.randomContent('pb_expressions', 'meaning', 80, [])) || [];
    return new ExpressionsGame(room, hooks, rows, pool.map((r) => r.meaning));
  }

  constructor(room, hooks, rows, meanings = []) {
    super(room, hooks, { id: 'expressions', count: rows.length, answerType: 'exp_pick', ...EXP });
    this.items = rows;
    this.meanings = meanings;
  }

  // 3 sens assez différents de celui de l'expression (et entre eux)
  fakeMeanings(it) {
    const taken = [it.meaning];
    for (const m of shuffle([...this.meanings, ...this.items.map((x) => x.meaning)])) {
      if (taken.length === 4) break;
      if (taken.some((t) => fold(t) === fold(m))) continue;
      const w = words(m);
      if (taken.some((t) => [...words(t)].some((x) => w.has(x)))) continue;
      taken.push(m);
    }
    return taken.length === 4 ? taken.slice(1) : null;
  }

  makeRound(i) {
    const it = this.items[i];
    const full = it.text.replace('___', it.answer);
    const fakes = (i + 1) % EXP.senseEvery === 0 ? this.fakeMeanings(it) : null;
    if (fakes) {
      const choices = shuffle([it.meaning, ...fakes]);
      return { kind: 'sens', text: full, full, answer: it.meaning, meaning: it.meaning, choices, correct: choices.indexOf(it.meaning) };
    }
    const choices = shuffle([it.answer, it.wrong1, it.wrong2, it.wrong3]);
    return { kind: 'trou', text: it.text, full, answer: it.answer, meaning: it.meaning, choices, correct: choices.indexOf(it.answer) };
  }

  ask() {
    // Les manches « Que veut dire… ? » laissent plus de temps (4 phrases à lire)
    this.cfg = { ...EXP, askMs: this.round?.kind === 'sens' ? EXP.senseAskMs : EXP.askMs };
    super.ask();
  }

  accept(p, m) {
    return Number.isInteger(m.choice) && m.choice >= 0 && m.choice < 4 ? m.choice : undefined;
  }

  scoreRound() {
    for (const [pid, a] of this.answers) {
      if (a.v === this.round.correct) this.addPoints(pid, EXP.minPoints + Math.round((EXP.speedPoints * this.speed(a.at)) / 10) * 10);
    }
  }

  publicRound(reveal) {
    // Pendant la question : l'expression (avec son trou) et les 4 choix, rien d'autre
    const s = { kind: this.round.kind, text: this.round.text, choices: this.round.choices };
    if (reveal) {
      s.correct = this.round.correct;
      s.full = this.round.full;
      s.answer = this.round.answer;
      s.meaning = this.round.meaning;
      s.picks = Object.fromEntries([...this.answers].map(([pid, a]) => [pid, a.v]));
    }
    return s;
  }
}
