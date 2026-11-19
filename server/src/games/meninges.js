// Bataille de méninges : 7 catégories × 5 épreuves. Chaque manche = une épreuve de 30 s,
// tout le monde en même temps, chacun à son rythme : dès qu'on répond, la question suivante
// arrive (message direct `mng_q`). Mêmes questions dans le même ordre pour tous (à niveau égal) ;
// le niveau monte si on enchaîne, baisse si on se trompe. Les bonnes réponses font grossir le
// cerveau (grammes). La TV montre la course en direct et l'animateur commente.
// Messages : `mng_answer {r, i, v}` (r = manche, i = numéro de la question).
// Les réponses ne quittent jamais le serveur (sauf la bonne, après coup, pour la question finie).
import crypto from 'node:crypto';
import { BaseGame, botMs, fastTimings, fold, shuffle } from './common.js';
import { makeCalc } from './calcul.js';
import { ALL_EMOJIS } from './emojis.js';
import { dict } from './scrabroc.js';
import { AGREEMENTS, ANIMALS, ASYM, COLORS, FAMILIES, LOOKALIKE, MEMO, OPPOSITES, PLURALS, RHYMES, SHAPES, SYLLABLES, WORDS } from './meninges_data.js';

export const MNG = fastTimings({
  rounds: [5, 7, 10],
  defaultRounds: 7,
  without: ['Aucune', 'Mots', 'Réflexe', 'Mots et Réflexe'],
  introMs: 7000,
  announceMs: 5000,
  goMs: 30000,
  resultMs: 8000,
  podiumMs: 32000,
  wrongMs: 1000,       // bloqué après une erreur
  newsGapMs: 4000,     // pas plus d'une annonce toutes les 4 s
  changedMs: 250,      // état public rediffusé au plus 4 fois par seconde
  baseGrams: 500,      // poids de départ du cerveau
});

export const CATS = [
  { id: 'rep', name: 'Repérer', emoji: '🔍', color: 0xFFFF4FA3 },
  { id: 'ret', name: 'Retenir', emoji: '🧠', color: 0xFF3F8CFF },
  { id: 'ref', name: 'Réfléchir', emoji: '🧩', color: 0xFF22B36B },
  { id: 'cal', name: 'Calculer', emoji: '➗', color: 0xFFFF9A1F },
  { id: 'voi', name: 'Voir', emoji: '👁', color: 0xFF9B5CFF },
  { id: 'rfx', name: 'Réflexe', emoji: '⚡', color: 0xFFE5484D },
  { id: 'mot', name: 'Mots', emoji: '🔤', color: 0xFF16A3B8 },
];

// ---------- hasard à graine (mêmes questions pour tous) ----------
function rngFrom(seed) {
  let h = crypto.createHash('sha256').update(seed).digest();
  let i = 0;
  return () => {
    if (i + 4 > h.length) { h = crypto.createHash('sha256').update(h).digest(); i = 0; }
    const v = h.readUInt32BE(i); i += 4;
    return v / 2 ** 32;
  };
}
function tools(rng) {
  const int = (a, b) => a + Math.floor(rng() * (b - a + 1));
  const pick = (l) => l[Math.floor(rng() * l.length)];
  const mix = (l) => { const a = [...l]; for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(rng() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
  const some = (l, n) => mix(l).slice(0, n);
  // 4 choix : la bonne réponse + des fausses, mélangés → { choices, ans }
  const choices = (good, wrongs) => {
    const list = mix([good, ...wrongs]);
    return { choices: list, ans: list.indexOf(good) };
  };
  return { int, pick, mix, some, choices };
}
const numChoices = (t, good, spread) => {
  const set = new Set([good]);
  let guard = 0;
  while (set.size < 4 && guard++ < 50) {
    const d = t.int(1, spread) * (t.rng() < 0.5 ? -1 : 1);
    if (good + d >= 0) set.add(good + d);
  }
  for (let k = 1; set.size < 4; k++) set.add(good + spread + k);
  const r = t.choices(good, [...set].slice(1));
  return { choices: r.choices.map((n) => ({ t: String(n) })), ans: r.ans };
};
const pad2 = (n) => String(n).padStart(2, '0');
const euro = (c) => `${Math.floor(c / 100)}${c % 100 ? `,${pad2(c % 100)}` : ''} €`;
// couleur (teinte 0-360, saturation et luminosité 0-1) → 0xAARRGGBB
const hsl = (h, s, l) => {
  const f = (n) => { const k = (n + h / 30) % 12; return l - s * Math.min(l, 1 - l) * Math.max(-1, Math.min(k - 3, 9 - k, 1)); };
  return (0xFF000000 + (Math.round(f(0) * 255) << 16) + (Math.round(f(8) * 255) << 8) + Math.round(f(4) * 255)) >>> 0;
};
const DAYS = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const NAMES = ['Léa', 'Tom', 'Zoé', 'Hugo', 'Emma', 'Noah', 'Jade', 'Louis', 'Lina', 'Paul'];
const ODD_CHARS = [['8', '3'], ['O', 'Q'], ['E', 'F'], ['M', 'N'], ['b', 'd'], ['6', '9'], ['P', 'R'], ['5', 'S'], ['1', '7'], ['u', 'v']];
const hhmm = (min) => { const m = ((min % 720) + 720) % 720; return `${Math.floor(m / 60) || 12}:${pad2(m % 60)}`; };

// ---------- les 60 épreuves : gen(L, t) → question (avec `ans`, gardé par le serveur) ----------
// Formes de question (`k`) : pick (un choix), num (pavé de chiffres), seq (toucher dans l'ordre),
// coins (pièces), multi (en toucher n), whack (toutes les taupes), cups (gobelets).
export const EPREUVES = [
  // ---- Repérer ----
  { id: 'intrus', cat: 'rep', title: 'L’intrus', emoji: '👀', desc: 'Un seul dessin n’est pas comme les autres : touche-le !',
    gen(L, t) {
      const [a, b] = LOOKALIKE[Math.min(LOOKALIKE.length - 1, t.int(0, 5) + (L - 1) * 4)];
      const n = L <= 2 ? 9 : L <= 4 ? 12 : 16;
      const ans = t.int(0, n - 1);
      return { k: 'pick', prompt: 'Trouve l’intrus !', cols: n === 9 ? 3 : 4, choices: Array.from({ length: n }, (_, i) => ({ e: i === ans ? b : a })), ans };
    } },
  { id: 'ombre', cat: 'rep', title: 'La bonne ombre', emoji: '🌑', desc: 'Quelle ombre noire correspond au dessin ?',
    gen(L, t) {
      const fam = t.pick(SHAPES);
      const [good, ...wr] = t.some(fam, 4);
      const r = t.choices(good, wr);
      return { k: 'pick', prompt: 'Quelle est son ombre ?', pic: { type: 'big', e: good }, cols: 2, choices: r.choices.map((e) => ({ e, sil: true })), ans: r.ans };
    } },
  { id: 'paires', cat: 'rep', title: 'Les jumeaux', emoji: '👯', desc: 'Deux dessins sont identiques : touche les deux !',
    gen(L, t) {
      const n = L <= 2 ? 9 : L <= 4 ? 12 : 16;
      const pool = t.some([...MEMO, ...ANIMALS], n - 1);
      const items = [...pool, pool[0]];
      const mixed = t.mix(items);
      const ans = mixed.map((e, i) => (e === pool[0] ? i : -1)).filter((i) => i >= 0);
      return { k: 'multi', n: 2, prompt: 'Touche les 2 dessins identiques', cols: n === 9 ? 3 : 4, items: mixed.map((e) => ({ e })), ans };
    } },
  { id: 'miroir', cat: 'rep', title: 'Le miroir', emoji: '🪞', desc: 'Quel dessin est le reflet du modèle dans un miroir ?',
    gen(L, t) {
      const e = t.pick(ASYM);
      const wrong = L <= 2 ? [{ e, rot: 180 }, { e, rot: 90 }, { e, fx: true, rot: 180 }] : [{ e }, { e, rot: 180 }, { e, fx: true, rot: 180 }];
      const r = t.choices({ e, fx: true }, wrong);
      return { k: 'pick', prompt: 'Le reflet dans le miroir ?', pic: { type: 'mirror', e }, cols: 2, choices: r.choices, ans: r.ans };
    } },
  { id: 'manque', cat: 'rep', title: 'Il en manque un', emoji: '🔎', desc: 'Deux images presque pareilles : qu’est-ce qui manque dans la 2e ?',
    gen(L, t) {
      const n = 3 + L;
      const items = t.some(MEMO, n);
      const gone = t.int(0, n - 1);
      const others = t.some(MEMO.filter((e) => !items.includes(e)), 1);
      const r = t.choices(items[gone], [...t.some(items.filter((_, i) => i !== gone), 2), ...others]);
      return { k: 'pick', prompt: 'Qu’est-ce qui manque à droite ?', pic: { type: 'two', a: items, b: items.map((e, i) => (i === gone ? null : e)) }, cols: 4, choices: r.choices.map((e) => ({ e })), ans: r.ans };
    } },

  // ---- Retenir ----
  { id: 'disparu', cat: 'ret', title: 'Qui a disparu ?', emoji: '🎈', desc: 'Retiens les objets… l’un d’eux va disparaître !',
    gen(L, t) {
      const n = 2 + L;
      const items = t.some(MEMO, n);
      const gone = t.int(0, n - 1);
      const r = t.choices(items[gone], t.some(MEMO.filter((e) => !items.includes(e)), 3));
      return { k: 'pick', prompt: 'Lequel a disparu ?', show: { type: 'grid', cols: n <= 4 ? 2 : 3, items }, showMs: 1800 + n * 250,
        pic: { type: 'grid', cols: n <= 4 ? 2 : 3, items: items.map((e, i) => (i === gone ? null : e)) }, cols: 4, choices: r.choices.map((e) => ({ e })), ans: r.ans };
    } },
  { id: 'cases', cat: 'ret', title: 'Les cases', emoji: '🟦', desc: 'Des cases s’allument : refais la même suite !',
    gen(L, t) {
      const size = L <= 3 ? 9 : 16;
      const len = 2 + L;
      const flash = [];
      while (flash.length < len) { const c = t.int(0, size - 1); if (c !== flash[flash.length - 1]) flash.push(c); }
      return { k: 'seq', prompt: 'Refais la suite', cols: size === 9 ? 3 : 4, items: Array.from({ length: size }, () => ({ c: 0xFF3F8CFF })), flash, flashMs: Math.max(380, 650 - L * 50), n: len, ans: flash };
    } },
  { id: 'chiffres', cat: 'ret', title: 'Les chiffres', emoji: '🔢', desc: 'Un nombre s’affiche un instant : tape-le !',
    gen(L, t) {
      const len = 2 + L;
      let s = String(t.int(1, 9));
      while (s.length < len) s += String(t.int(0, 9));
      return { k: 'num', prompt: 'Tape le nombre', show: { type: 'text', t: s }, showMs: 1000 + len * 250, maxLen: len, ans: Number(s) };
    } },
  { id: 'gobelets', cat: 'ret', title: 'Les gobelets', emoji: '🥤', desc: 'La balle est sous un gobelet… ils se mélangent. Où est-elle ?',
    gen(L, t) {
      const n = L <= 3 ? 3 : 4;
      let ball = t.int(0, n - 1);
      const start = ball;
      const swaps = [];
      for (let s = 0; s < 2 + L; s++) {
        const a = t.int(0, n - 1); let b = t.int(0, n - 2); if (b >= a) b++;
        swaps.push([a, b]);
        if (ball === a) ball = b; else if (ball === b) ball = a;
      }
      return { k: 'cups', prompt: 'Où est la balle ?', n, start, swaps, swapMs: Math.max(330, 620 - L * 60), ans: ball };
    } },
  { id: 'ouetait', cat: 'ret', title: 'Qui était où ?', emoji: '🐾', desc: 'Retiens la place de chaque animal !',
    gen(L, t) {
      const n = L <= 2 ? 4 : L <= 4 ? 6 : 9;
      const cols = n === 4 ? 2 : 3;
      const items = t.some(ANIMALS, n);
      const ans = t.int(0, n - 1);
      return { k: 'pick', prompt: `Où était ${items[ans]} ?`, ask: items[ans], show: { type: 'grid', cols, items }, showMs: 1500 + n * 300, cols, choices: items.map(() => ({ t: '?' })), ans };
    } },

  // ---- Réfléchir ----
  { id: 'balance', cat: 'ref', title: 'La balance', emoji: '⚖️', desc: 'Regarde ce qui s’équilibre : qui est le plus lourd ?',
    gen(L, t) {
      const [x, y, z] = t.some(['🍎', '🍐', '🍋', '🍊', '🍇', '🍓', '🥝', '🍌'], 3);
      if (L <= 2) {
        const a = t.int(2, 3);
        const r = t.choices(y, [x]);
        return { k: 'pick', prompt: 'Lequel est le plus lourd ?', pic: { type: 'lines', lines: [`${x.repeat(a)} = ${y}`] }, cols: 2, choices: r.choices.map((e) => ({ e })), ans: r.ans };
      }
      // x × a = y ; y = z × b → x = z × b / a
      let a = t.int(2, 4), b = t.int(2, 4);
      if (a === b) b = a + 1;
      const heavier = b > a ? x : z;
      const r = t.choices(heavier, [heavier === x ? z : x]);
      return { k: 'pick', prompt: `Qui pèse le plus : ${x} ou ${z} ?`, pic: { type: 'lines', lines: [`${x.repeat(a)} = ${y}`, `${y} = ${z.repeat(b)}`] }, cols: 2, choices: r.choices.map((e) => ({ e })), ans: r.ans };
    } },
  { id: 'suite', cat: 'ref', title: 'La suite', emoji: '🔁', desc: 'Trouve ce qui vient ensuite dans la suite !',
    gen(L, t) {
      if (L <= 2) {
        const sym = t.some(['🔺', '🔵', '🟩', '⭐', '❤️', '🌙'], L + 1);
        const seq = Array.from({ length: 5 }, (_, i) => sym[i % sym.length]);
        const good = sym[5 % sym.length];
        const r = t.choices(good, t.some(['🔺', '🔵', '🟩', '⭐', '❤️', '🌙'].filter((s) => s !== good), 3));
        return { k: 'pick', prompt: 'Qu’est-ce qui vient ensuite ?', pic: { type: 'text', t: `${seq.join(' ')} ❓` }, cols: 4, choices: r.choices.map((e) => ({ e })), ans: r.ans };
      }
      let seq, good;
      if (L === 3) { const a = t.int(1, 9), d = t.int(2, 6); seq = [0, 1, 2, 3].map((i) => a + i * d); good = a + 4 * d; }
      else if (L === 4) { const a = t.int(1, 4), m = t.pick([2, 3]); seq = [0, 1, 2, 3].map((i) => a * m ** i); good = a * m ** 4; }
      else { const a = t.int(1, 5), d = t.int(1, 3); seq = [a]; for (let i = 1; i < 5; i++) seq.push(seq[i - 1] + d * i); good = seq.pop() ; }
      const r = numChoices(t, good, Math.max(3, Math.round(good / 6)));
      return { k: 'pick', prompt: 'Quel nombre vient ensuite ?', pic: { type: 'text', t: `${seq.join(', ')}, ❓` }, cols: 2, ...r };
    } },
  { id: 'chemin', cat: 'ref', title: 'Le chemin', emoji: '🐭', desc: 'Combien de pas pour que la souris arrive au fromage ?',
    gen(L, t) {
      const W = L <= 2 ? 4 : L <= 4 ? 5 : 6;
      for (let tries = 0; tries < 60; tries++) {
        const walls = new Set();
        const nWalls = Math.round(W * W * (0.18 + L * 0.03));
        while (walls.size < nWalls) walls.add(t.int(0, W * W - 1));
        const free = [...Array(W * W).keys()].filter((c) => !walls.has(c));
        if (free.length < 4) continue;
        const s = t.pick(free); const g = t.pick(free.filter((c) => c !== s));
        // plus court chemin (cases voisines haut / bas / gauche / droite)
        const dist = new Map([[s, 0]]); const q = [s];
        while (q.length) {
          const c = q.shift();
          const [r, col] = [Math.floor(c / W), c % W];
          for (const [dr, dc] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
            const nr = r + dr, nc = col + dc;
            if (nr < 0 || nc < 0 || nr >= W || nc >= W) continue;
            const n = nr * W + nc;
            if (walls.has(n) || dist.has(n)) continue;
            dist.set(n, dist.get(c) + 1); q.push(n);
          }
        }
        const d = dist.get(g);
        if (!d || d < 2 + L) continue;
        const items = Array.from({ length: W * W }, (_, i) => (i === s ? '🐭' : i === g ? '🧀' : walls.has(i) ? '🧱' : ''));
        const r = numChoices(t, d, 2);
        return { k: 'pick', prompt: 'Combien de pas jusqu’au fromage ?', pic: { type: 'grid', cols: W, items, small: true }, cols: 4, ...r };
      }
      return EPREUVES.find((e) => e.id === 'balance').gen(L, t);
    } },
  { id: 'heure', cat: 'ref', title: 'L’heure', emoji: '🕒', desc: 'Lis l’horloge… et calcule l’heure qu’il sera !',
    gen(L, t) {
      const h = t.int(1, 12), m = t.int(0, 11) * 5;
      const now = h * 60 + m;
      const deltas = [0, 60, 30, t.pick([15, 45]), t.pick([20, 40, 50]), t.pick([85, 95, 135])];
      const d = deltas[Math.min(L, 5)] * (L === 1 ? 0 : 1);
      const good = hhmm(now + d);
      const set = new Set([good]);
      for (const off of t.mix([5, -5, 10, -10, 60, -60, 30, -30])) { if (set.size >= 4) break; set.add(hhmm(now + d + off)); }
      const r = t.choices(good, [...set].slice(1, 4));
      const say = d === 0 ? 'Quelle heure est-il ?' : `Quelle heure sera-t-il dans ${d >= 60 ? `${Math.floor(d / 60)} h${d % 60 ? ` ${d % 60}` : ''}` : `${d} min`} ?`;
      return { k: 'pick', prompt: say, pic: { type: 'clock', h, m }, cols: 2, choices: r.choices.map((x) => ({ t: x })), ans: r.ans };
    } },
  { id: 'rapide', cat: 'ref', title: 'Le plus rapide', emoji: '🐇', desc: 'Qui va le plus vite ? Compare les distances et les temps !',
    gen(L, t) {
      const [x, y] = t.some(['🐢', '🐇', '🐌', '🐎', '🐕', '🐈', '🦆', '🐿️'], 2);
      for (let k = 0; k < 40; k++) {
        const ta = t.int(2, 5 + L), tb = t.int(2, 5 + L);
        const va = t.int(1, 3 + L), vb = t.int(1, 3 + L);
        if (L <= 2 && Math.abs(va - vb) < 1) continue;
        const good = va > vb ? x : vb > va ? y : '🟰 Pareil';
        const opts = [{ e: x }, { e: y }, { t: '🟰 Pareil' }];
        const ans = good === x ? 0 : good === y ? 1 : 2;
        return { k: 'pick', prompt: 'Qui va le plus vite ?', pic: { type: 'lines', lines: [`${x} ${va * ta} m en ${ta} s`, `${y} ${vb * tb} m en ${tb} s`] }, cols: 3, choices: opts, ans };
      }
      return EPREUVES.find((e) => e.id === 'balance').gen(L, t);
    } },

  // ---- Calculer ----
  { id: 'eclair', cat: 'cal', title: 'Calcul éclair', emoji: '⚡', desc: 'Tape le résultat, le plus vite possible !',
    gen(L) {
      const c = makeCalc(L <= 2 ? 'Facile' : L <= 4 ? 'Moyen' : 'Difficile', L % 2 ? 0 : 1);
      return { k: 'num', prompt: 'Combien ?', pic: { type: 'text', t: c.text, big: true }, maxLen: 5, ans: c.value };
    } },
  { id: 'monnaie', cat: 'cal', title: 'La monnaie', emoji: '🪙', desc: 'Touche les pièces pour faire exactement la somme demandée !',
    gen(L, t) {
      const values = L <= 2 ? [10, 20, 50, 100, 200] : [5, 10, 20, 50, 100, 200];
      const coins = Array.from({ length: 6 + Math.min(L, 3) }, () => t.pick(values));
      const take = t.some([...coins.keys()], 2 + Math.min(L, 3));
      const target = take.reduce((s, i) => s + coins[i], 0);
      return { k: 'coins', prompt: `Fais ${(target / 100).toFixed(2).replace('.', ',')} €`, target, coins, ans: take };
    } },
  { id: 'grand', cat: 'cal', title: 'Le plus grand', emoji: '📈', desc: 'Deux calculs : touche celui qui donne le plus grand résultat !',
    gen(L, t) {
      const lvl = L <= 2 ? 'Facile' : L <= 4 ? 'Moyen' : 'Difficile';
      let a, b, k = 0;
      do { a = makeCalc(lvl, 0); b = makeCalc(lvl, 0); } while ((a.value === b.value || Math.abs(a.value - b.value) > 30 - L * 4) && k++ < 30);
      if (a.value === b.value) b = { text: `${b.text} + 1`, value: b.value + 1 };
      return { k: 'pick', prompt: 'Le plus grand ?', cols: 1, choices: [{ t: a.text }, { t: b.text }], ans: a.value > b.value ? 0 : 1 };
    } },
  { id: 'signe', cat: 'cal', title: 'Le signe manquant', emoji: '❔', desc: 'Quel signe manque : + − × ou ÷ ?',
    gen(L, t) {
      const ops = ['+', '−', '×', ':'];
      for (let k = 0; k < 60; k++) {
        const op = t.int(0, 3);
        const max = 5 + L * 4;
        let a = t.int(2, max), b = t.int(2, Math.max(3, Math.round(max / 2)));
        if (op === 3) a = b * t.int(2, 4 + L);
        const res = [a + b, a - b, a * b, b ? a / b : NaN];
        const c = res[op];
        if (!Number.isInteger(c) || c < 0) continue;
        if (res.filter((v) => v === c).length > 1) continue;
        return { k: 'pick', prompt: 'Quel signe manque ?', pic: { type: 'text', t: `${a} ❓ ${b} = ${c}`, big: true }, cols: 4, choices: ops.map((o) => ({ t: o })), ans: op };
      }
      return EPREUVES.find((e) => e.id === 'eclair').gen(L, t);
    } },
  { id: 'fruits', cat: 'cal', title: 'Les fruits', emoji: '🍌', desc: 'Chaque fruit vaut un nombre : trouve combien vaut le dernier !',
    gen(L, t) {
      const [x, y, z] = t.some(['🍌', '🍒', '🍎', '🍇', '🍓', '🍋', '🥝', '🍑'], 3);
      const vx = t.int(1, 3 + L * 2), vy = t.int(1, 3 + L * 2), vz = t.int(1, 3 + L * 2);
      const lines = [`${x} + ${x} = ${2 * vx}`, `${x} + ${y} = ${vx + vy}`];
      let good = vy, ask = y;
      if (L >= 3) { lines.push(`${y} + ${z} = ${vy + vz}`); good = vz; ask = z; }
      if (L >= 5) { lines[0] = `${x} + ${x} + ${x} = ${3 * vx}`; }
      const r = numChoices(t, good, 3);
      return { k: 'pick', prompt: `Combien vaut ${ask} ?`, pic: { type: 'lines', lines }, cols: 2, ...r };
    } },

  // ---- Voir ----
  { id: 'cubes', cat: 'voi', title: 'Les cubes', emoji: '🧊', desc: 'Compte tous les cubes, même ceux cachés en dessous !',
    gen(L, t) {
      const cols = Math.min(4, 2 + Math.floor(L / 2));
      const rows = L <= 2 ? 1 : 2;
      const cubes = [];
      const front = Array.from({ length: cols }, () => t.int(1, Math.min(3, 1 + L)));
      for (let x = 0; x < cols; x++) for (let z = 0; z < front[x]; z++) cubes.push([x, 0, z]);
      if (rows === 2) {
        // la rangée du fond est au moins aussi haute que celle de devant : on la voit toujours
        for (let x = 0; x < cols; x++) { const h = t.int(front[x], Math.min(4, front[x] + 1)); for (let z = 0; z < h; z++) cubes.push([x, 1, z]); }
      }
      const r = numChoices(t, cubes.length, 2);
      return { k: 'pick', prompt: 'Combien de cubes ?', pic: { type: 'cubes', cubes }, cols: 2, ...r };
    } },
  { id: 'devoile', cat: 'voi', title: 'Ça se dévoile', emoji: '🫣', desc: 'Un dessin apparaît petit à petit : trouve-le le plus tôt possible !',
    gen(L, t) {
      const fam = t.pick(['animaux', 'nourriture', 'objets']);
      const list = ALL_EMOJIS.filter((x) => x.family === fam);
      const [good, ...wr] = t.some(list, 4);
      const r = t.choices(good.name, wr.map((x) => x.name));
      return { k: 'pick', prompt: 'Qu’est-ce que c’est ?', pic: { type: 'reveal', e: good.e, ms: Math.max(2500, 6000 - L * 700) }, cols: 2, choices: r.choices.map((x) => ({ t: x })), ans: r.ans };
    } },
  { id: 'points', cat: 'voi', title: 'Combien ?', emoji: '⚫', desc: 'Des points s’affichent une demi-seconde : combien y en avait-il ?',
    gen(L, t) {
      const n = t.int(3 + L, 6 + L * 2);
      const pts = [];
      while (pts.length < n) {
        const p = [t.int(8, 92), t.int(8, 92)];
        if (pts.every((q) => (q[0] - p[0]) ** 2 + (q[1] - p[1]) ** 2 > 140)) pts.push(p);
      }
      const r = numChoices(t, n, 2);
      return { k: 'pick', prompt: 'Combien de points ?', show: { type: 'dots', pts }, showMs: Math.max(450, 900 - L * 90), cols: 2, ...r };
    } },
  { id: 'taille', cat: 'voi', title: 'La plus grande', emoji: '🔵', desc: 'Touche la forme la plus grande !',
    gen(L, t) {
      const e = t.pick(['🔵', '🟢', '🟣', '🟠', '⭐', '❤️', '🟦']);
      const n = L <= 2 ? 4 : 6;
      const big = 1;
      const gap = Math.max(0.05, 0.3 - L * 0.05);
      const sizes = Array.from({ length: n - 1 }, () => 0.45 + t.rngRaw() * (0.55 - gap));
      const r = t.choices(big, sizes);
      return { k: 'pick', prompt: 'La plus grande ?', cols: n === 4 ? 2 : 3, choices: r.choices.map((s) => ({ e, s: Math.round(s * 100) / 100 })), ans: r.ans };
    } },
  { id: 'de', cat: 'voi', title: 'Le dé déplié', emoji: '🎲', desc: 'On replie le patron en dé : quelle face sera en face ?',
    gen(L, t) {
      // patrons : place de chaque face (colonne, rangée) et faces opposées
      const nets = [
        { cells: [[1, 0], [0, 1], [1, 1], [2, 1], [3, 1], [1, 2]], opp: [5, 3, 4, 1, 2, 0] },
        { cells: [[0, 0], [1, 0], [2, 0], [1, 1], [1, 2], [1, 3]], opp: [2, 4, 0, 5, 1, 3] },
        { cells: [[0, 0], [0, 1], [1, 1], [2, 1], [3, 1], [3, 2]], opp: [5, 3, 4, 1, 2, 0] },
      ];
      const net = t.pick(nets);
      const faces = t.some(['⭐', '❤️', '🌙', '☀️', '🍀', '💎', '🔺', '🔵'], 6);
      const a = t.int(0, 5);
      const good = faces[net.opp[a]];
      const r = t.choices(good, t.some(faces.filter((f, i) => i !== a && f !== good), 3));
      return { k: 'pick', prompt: `En face de ${faces[a]} ?`, pic: { type: 'net', cells: net.cells, faces }, cols: 4, choices: r.choices.map((e) => ({ e })), ans: r.ans };
    } },

  // ---- Réflexe ----
  { id: 'stroop', cat: 'rfx', title: 'Couleur ou mot', emoji: '🎨', desc: 'Touche la COULEUR de l’écriture, pas ce qui est écrit !',
    gen(L, t) {
      const pal = t.some(COLORS, 4);
      const ink = t.int(0, 3);
      let word = t.int(0, 3); if (word === ink) word = (word + 1) % 4;
      return { k: 'pick', prompt: 'La couleur de l’écriture ?', pic: { type: 'stroop', w: pal[word][0], c: pal[ink][1] }, cols: 2,
        choices: pal.map(([name, c], i) => (L >= 4 ? { t: pal[(i + 1) % 4][0], c } : { c })), ans: ink };
    } },
  { id: 'ordre', cat: 'rfx', title: 'Dans l’ordre', emoji: '🔢', desc: 'Touche les nombres dans l’ordre, du plus petit au plus grand !',
    gen(L, t) {
      const n = 4 + L;
      const nums = L <= 2 ? Array.from({ length: n }, (_, i) => i + 1) : t.some([...Array(40).keys()].map((x) => x + 1), n);
      const placed = t.mix(nums);
      const ans = [...placed.keys()].sort((a, b) => placed[a] - placed[b]);
      return { k: 'seq', prompt: 'Du plus petit au plus grand', cols: n <= 6 ? 3 : 4, items: placed.map((v) => ({ t: String(v) })), n, ans, ordered: true };
    } },
  { id: 'fleche', cat: 'rfx', title: 'La flèche du milieu', emoji: '➡️', desc: 'De quel côté pointe la flèche du MILIEU ? Les autres te trompent !',
    gen(L, t) {
      const dirs = L >= 3 ? ['⬅️', '➡️', '⬆️', '⬇️'] : ['⬅️', '➡️'];
      const mid = t.int(0, dirs.length - 1);
      let other = t.int(0, dirs.length - 1);
      if (t.rngRaw() < 0.7 && other === mid) other = (mid + 1) % dirs.length;
      const n = L >= 4 ? 7 : 5;
      const arrows = Array.from({ length: n }, (_, i) => dirs[i === (n - 1) / 2 ? mid : other]);
      return { k: 'pick', prompt: 'La flèche du milieu ?', pic: { type: 'text', t: arrows.join(''), big: true }, cols: dirs.length, choices: dirs.map((e) => ({ e })), ans: mid };
    } },
  { id: 'pareil', cat: 'rfx', title: 'Pareil ou pas ?', emoji: '🟰', desc: 'Les deux sont-ils exactement pareils ?',
    gen(L, t) {
      const same = t.rngRaw() < 0.5;
      let a, b;
      if (L <= 1) { const [x, y] = t.pick(LOOKALIKE.slice(0, 8)); a = x; b = same ? x : y; }
      else if (L <= 3) { const w = t.pick(Object.values(WORDS).flat()); a = w; b = same ? w : (w.length > 3 ? w.slice(0, -2) + w.slice(-1) + w.slice(-2, -1) : `${w}S`); if (b === a) b = `${w}S`; }
      else { const n = String(t.int(1000, 9999) * (L >= 5 ? 10 : 1)); a = n; b = same ? n : n.slice(0, 1) + n.slice(2, 3) + n.slice(1, 2) + n.slice(3); if (b === a) b = String(Number(n) + 1); }
      return { k: 'pick', prompt: 'Pareil ?', pic: { type: 'pair', a, b }, cols: 2, choices: [{ t: '✅ Pareil' }, { t: '❌ Différent' }], ans: same ? 0 : 1 };
    } },
  { id: 'taupe', cat: 'rfx', title: 'Tape la taupe', emoji: '🐹', desc: 'Touche toutes les taupes… mais jamais les lapins !',
    gen(L, t) {
      const n = L <= 3 ? 9 : 12;
      const moles = 1 + Math.min(3, Math.floor(L / 2) + t.int(0, 1));
      const rabbits = Math.min(4, t.int(1, 1 + L));
      const cells = t.some([...Array(n).keys()], moles + rabbits);
      const items = Array.from({ length: n }, () => ({ e: '' }));
      cells.slice(0, moles).forEach((c) => (items[c] = { e: '🐹' }));
      cells.slice(moles).forEach((c) => (items[c] = { e: '🐰' }));
      return { k: 'whack', prompt: 'Les taupes, pas les lapins !', target: '🐹', cols: n === 9 ? 3 : 4, items, ans: cells.slice(0, moles).sort((a, b) => a - b) };
    } },

  // ---- Mots ----
  { id: 'melange', cat: 'mot', title: 'Le mot mélangé', emoji: '🔀', desc: 'Remets les lettres dans l’ordre pour former un mot !',
    gen(L, t) {
      const lens = [4, 4, 5, 6, 7, 8];
      const list = WORDS[lens[Math.min(L, 5)]].length ? WORDS[lens[Math.min(L, 5)]] : WORDS[5];
      const w = t.pick(list);
      let letters = t.mix(w.split(''));
      for (let k = 0; k < 5 && letters.join('') === w; k++) letters = t.mix(w.split(''));
      return { k: 'seq', prompt: 'Remets le mot dans l’ordre', items: letters.map((l) => ({ t: l })), n: w.length, word: w, ans: w, tiles: true };
    } },
  { id: 'lettre', cat: 'mot', title: 'La lettre manquante', emoji: '🔡', desc: 'Quelle lettre manque dans le mot ?',
    gen(L, t) {
      const lens = [4, 4, 5, 6, 7, 8];
      const w = t.pick(WORDS[lens[Math.min(L, 5)]].length ? WORDS[lens[Math.min(L, 5)]] : WORDS[5]);
      const at = t.int(0, w.length - 1);
      const good = w[at];
      const words = dict();
      const wrongs = t.mix('ABCDEFGHIJLMNOPRSTUV'.split('')).filter((l) => l !== good && !words.has(w.slice(0, at) + l + w.slice(at + 1))).slice(0, 3);
      const r = t.choices(good, wrongs);
      return { k: 'pick', prompt: 'Quelle lettre manque ?', pic: { type: 'text', t: w.slice(0, at) + '_' + w.slice(at + 1), big: true, spaced: true }, cols: 4, choices: r.choices.map((l) => ({ t: l })), ans: r.ans };
    } },
  { id: 'contraire', cat: 'mot', title: 'Le contraire', emoji: '↔️', desc: 'Trouve le contraire du mot !',
    gen(L, t) {
      const pair = t.pick(OPPOSITES);
      const flip = t.rngRaw() < 0.5;
      const [w, good] = flip ? [pair[1], pair[0]] : pair;
      const wrongs = t.some(OPPOSITES.filter((p) => p !== pair), 3).map((p) => p[t.int(0, 1)]);
      const r = t.choices(good, wrongs);
      return { k: 'pick', prompt: `Le contraire de ${w} ?`, pic: { type: 'text', t: w, big: true }, cols: 1, choices: r.choices.map((x) => ({ t: x })), ans: r.ans };
    } },
  { id: 'intrusmot', cat: 'mot', title: 'Le mot intrus', emoji: '🧐', desc: 'Trois mots vont ensemble… lequel est l’intrus ?',
    gen(L, t) {
      const [fa, fb] = t.some(FAMILIES, 2);
      const three = t.some(fa[1], 3);
      const odd = t.pick(fb[1].filter((w) => !fa[1].includes(w)));
      const r = t.choices(odd, three);
      return { k: 'pick', prompt: 'Lequel est l’intrus ?', cols: 1, choices: r.choices.map((x) => ({ t: x })), ans: r.ans, family: fa[0] };
    } },
  { id: 'syllabes', cat: 'mot', title: 'Les syllabes', emoji: '🧱', desc: 'Touche les morceaux dans l’ordre pour former le mot !',
    gen(L, t) {
      const want = L <= 2 ? 2 : L <= 4 ? 3 : 4;
      const list = SYLLABLES.filter((s) => s.length === want);
      const syl = t.pick(list.length ? list : SYLLABLES);
      let order = t.mix(syl);
      for (let k = 0; k < 5 && order.join('') === syl.join(''); k++) order = t.mix(syl);
      return { k: 'seq', prompt: 'Forme le mot', items: order.map((s) => ({ t: s })), n: syl.length, word: syl.join(''), ans: syl.join(''), tiles: true };
    } },
  // ---- Repérer (suite) ----
  { id: 'compte', cat: 'rep', title: 'Compte les intrus', emoji: '🍏', desc: 'Combien de dessins ne sont pas comme les autres ?',
    gen(L, t) {
      const [a, b] = LOOKALIKE[Math.min(LOOKALIKE.length - 1, t.int(0, 3) + (L - 1) * 3)];
      const n = L <= 2 ? 12 : L <= 4 ? 16 : 20;
      const m = t.int(2, 3 + L);
      const odd = new Set(t.some([...Array(n).keys()], m));
      const r = numChoices(t, m, 2);
      return { k: 'pick', prompt: `Combien de ${b} ?`, picBig: true, pic: { type: 'grid', cols: n === 20 ? 5 : 4, items: Array.from({ length: n }, (_, i) => (odd.has(i) ? b : a)) }, cols: 4, ...r };
    } },
  { id: 'teinte', cat: 'rep', title: 'La bonne couleur', emoji: '🎨', desc: 'Une case est un tout petit peu plus claire : trouve-la !',
    gen(L, t) {
      const n = L <= 2 ? 9 : L <= 4 ? 16 : 20;
      const h = t.int(0, 359), s = 0.55 + t.rngRaw() * 0.3, l = 0.38 + t.rngRaw() * 0.12;
      const d = [0, 0.16, 0.12, 0.09, 0.07, 0.055][L];
      const ans = t.int(0, n - 1);
      return { k: 'pick', prompt: 'Touche la case plus claire !', cols: n === 9 ? 3 : n === 16 ? 4 : 5, choices: Array.from({ length: n }, (_, i) => ({ c: hsl(h, s, i === ans ? l + d : l) })), ans };
    } },
  { id: 'cache', cat: 'rep', title: 'Le caractère caché', emoji: '🔣', desc: 'Un seul caractère est différent : touche-le !',
    gen(L, t) {
      const [a, b] = t.pick(ODD_CHARS.slice(0, 5 + L));
      const n = L <= 2 ? 12 : L <= 4 ? 16 : 20;
      const ans = t.int(0, n - 1);
      return { k: 'pick', prompt: `Trouve le ${b} !`, cols: n === 12 ? 4 : n === 16 ? 4 : 5, choices: Array.from({ length: n }, (_, i) => ({ t: i === ans ? b : a, c: 0xFF3A2F6B })), ans };
    } },

  // ---- Retenir (suite) ----
  { id: 'apparition', cat: 'ret', title: 'L’ordre d’apparition', emoji: '🎬', desc: 'Des dessins passent un par un : retrouve leur ordre !',
    gen(L, t) {
      const n = 2 + L;
      const items = t.some(MEMO, n);
      const ms = Math.max(600, 1000 - L * 80);
      const mixed = t.mix(items);
      return { k: 'seq', prompt: 'Touche-les dans l’ordre où ils sont passés', show: { type: 'steps', items, ms }, showMs: n * ms + 500,
        items: mixed.map((e) => ({ t: e })), n, tiles: true, ans: items.map((e) => mixed.indexOf(e)) };
    } },
  { id: 'simon', cat: 'ret', title: 'Les 4 couleurs', emoji: '🚦', desc: 'Les couleurs s’allument : refais la même suite !',
    gen(L, t) {
      const len = 2 + L;
      const flash = [];
      while (flash.length < len) { const c = t.int(0, 3); if (L >= 4 || c !== flash[flash.length - 1]) flash.push(c); }
      const pal = [0xFFE5484D, 0xFF22B36B, 0xFF3F8CFF, 0xFFFFC21A];
      return { k: 'seq', prompt: 'Refais la suite', cols: 2, simon: true, items: pal.map((c) => ({ c })), flash, flashMs: Math.max(380, 650 - L * 50), n: len, ans: flash };
    } },
  { id: 'prix', cat: 'ret', title: 'Les prix', emoji: '🏷️', desc: 'Retiens le prix de chaque article !',
    gen(L, t) {
      const n = 1 + L;
      const items = t.some(['🧀', '🍞', '🥛', '🍫', '🍕', '🍌', '🥚', '🍪', '🧃', '🥕', '🍗', '🍦'], n);
      const cents = L >= 4;
      const prices = [];
      while (prices.length < n) { const p = t.int(1, 9) * 100 + (cents ? t.pick([0, 50, 20, 80]) : 0); if (!prices.includes(p)) prices.push(p); }
      const k = t.int(0, n - 1);
      const set = new Set([prices[k], ...prices]);
      for (let g = 0; set.size < 4 && g < 40; g++) set.add(Math.max(50, prices[k] + t.pick([-100, 100, -50, 50, 200])));
      const r = t.choices(prices[k], [...set].slice(1, 4));
      return { k: 'pick', prompt: `Combien coûte ${items[k]} ?`, show: { type: 'lines', lines: items.map((e, i) => `${e}  ${euro(prices[i])}`) }, showMs: 1400 + n * 700,
        cols: 2, choices: r.choices.map((c) => ({ t: euro(c) })), ans: r.ans };
    } },

  // ---- Réfléchir (suite) ----
  { id: 'calendrier', cat: 'ref', title: 'Le calendrier', emoji: '📅', desc: 'Quel jour serons-nous ? Compte bien les jours !',
    gen(L, t) {
      const today = t.int(0, 6);
      const ranges = [null, [1, 2], [3, 6], [8, 13], [10, 30], [9, 40]];
      let d = t.int(...ranges[L]);
      if (d % 7 === 0) d++;
      const past = L >= 5 && t.rngRaw() < 0.5;
      const good = DAYS[(((today + (past ? -d : d)) % 7) + 7) % 7];
      const r = t.choices(good, t.some(DAYS.filter((x) => x !== good), 3));
      const when = d === 1 ? 'Demain ?' : d === 2 && !past ? 'Après-demain ?' : past ? `Il y a ${d} jours ?` : `Dans ${d} jours ?`;
      return { k: 'pick', prompt: 'Quel jour ?', pic: { type: 'lines', lines: [`Aujourd’hui : ${DAYS[today]}`, when] }, cols: 2, choices: r.choices.map((x) => ({ t: x })), ans: r.ans };
    } },
  { id: 'age', cat: 'ref', title: 'Quel âge ?', emoji: '🎂', desc: 'Lis bien l’histoire et trouve l’âge demandé !',
    gen(L, t) {
      const [a, b] = t.some(NAMES, 2);
      const x = t.int(4, 12), y = t.int(2, 9);
      let lines, good;
      if (L <= 1) { lines = [`${a} a ${x} ans.`, `${b} a ${y} ans de plus.`, `Quel âge a ${b} ?`]; good = x + y; }
      else if (L === 2) { lines = [`${a} a ${x + y} ans.`, `${b} a ${y} ans de moins.`, `Quel âge a ${b} ?`]; good = x; }
      else if (L === 3) { lines = [`Dans ${y} ans,`, `${a} aura ${x + y} ans.`, `Quel âge a ${a} ?`]; good = x; }
      else if (L === 4) { lines = [`${b} a ${x} ans.`, `${a} a le double.`, `Et dans ${y} ans ?`]; good = 2 * x + y; }
      else { const z = t.int(2, 5); lines = [`Quand ${a} avait ${x} ans,`, `${b} avait ${x + y} ans.`, `${a} a ${x + z} ans.`, `Quel âge a ${b} ?`]; good = x + y + z; }
      const r = numChoices(t, good, 3);
      return { k: 'pick', prompt: 'Quel âge ?', pic: { type: 'lines', lines }, cols: 2, ...r };
    } },
  { id: 'plusmoins', cat: 'ref', title: 'Petit et grand', emoji: '↕️', desc: 'Touche le plus PETIT nombre, puis le plus GRAND !',
    gen(L, t) {
      const n = L <= 2 ? 6 : 9;
      const vals = new Set();
      while (vals.size < n) {
        if (L <= 2) vals.add(t.int(1, 99));
        else if (L <= 4) vals.add(t.int(100, 140 + L * 20));
        else vals.add(t.int(10, 60) * 10 + t.pick([0, 5])); // centièmes : 2,35
      }
      const list = [...vals];
      const fmt = (v) => (L <= 4 ? String(v) : String(v / 100).replace('.', ','));
      const lo = list.indexOf(Math.min(...list)), hi = list.indexOf(Math.max(...list));
      return { k: 'seq', prompt: 'Le plus petit, puis le plus grand', cols: 3, mark: true, items: list.map((v) => ({ t: fmt(v) })), n: 2, ans: [lo, hi] };
    } },

  // ---- Calculer (suite) ----
  { id: 'rendu', cat: 'cal', title: 'Le rendu de monnaie', emoji: '💶', desc: 'Tu paies avec un billet : combien te rend-on ?',
    gen(L, t) {
      const bill = L <= 2 ? t.pick([500, 1000]) : t.pick([1000, 2000, 5000]);
      const step = L <= 1 ? 100 : L <= 3 ? 50 : 10;
      const price = t.int(1, Math.floor((bill - step) / step)) * step;
      const good = bill - price;
      const set = new Set([good]);
      for (const off of t.mix([100, -100, 50, -50, 10, -10, 200, 1000])) { if (set.size >= 4) break; if (good + off > 0 && off % step === 0) set.add(good + off); }
      const r = t.choices(good, [...set].slice(1, 4));
      return { k: 'pick', prompt: 'On te rend combien ?', pic: { type: 'lines', lines: [`🛒 ${euro(price)}`, `💶 Tu donnes ${euro(bill)}`] }, cols: 2, choices: r.choices.map((c) => ({ t: euro(c) })), ans: r.ans };
    } },
  { id: 'moitie', cat: 'cal', title: 'Moitié ou double', emoji: '✌️', desc: 'Calcule la moitié, le double, le triple… et tape-le !',
    gen(L, t) {
      const kinds = L <= 2 ? ['moitie', 'double'] : L <= 4 ? ['moitie', 'double', 'triple'] : ['moitie', 'double', 'triple', 'quart'];
      const k = t.pick(kinds);
      const max = [0, 20, 50, 100, 150, 250][L];
      let text, ans;
      if (k === 'moitie') { ans = t.int(2, max); text = `La moitié de ${ans * 2}`; }
      else if (k === 'double') { const n = t.int(3, max); text = `Le double de ${n}`; ans = n * 2; }
      else if (k === 'triple') { const n = t.int(3, Math.round(max / 3)); text = `Le triple de ${n}`; ans = n * 3; }
      else { ans = t.int(3, Math.round(max / 4)); text = `Le quart de ${ans * 4}`; }
      return { k: 'num', prompt: 'Combien ?', pic: { type: 'text', t: text }, maxLen: 4, ans };
    } },
  { id: 'domino', cat: 'cal', title: 'Les dominos', emoji: '🁫', desc: 'Compte tous les points des dominos !',
    gen(L, t) {
      const n = L <= 2 ? 1 : L <= 4 ? 2 : 3;
      const d = Array.from({ length: n }, () => [t.int(L <= 1 ? 0 : 1, 6), t.int(L <= 1 ? 0 : 1, 6)]);
      const good = d.flat().reduce((s, v) => s + v, 0);
      const r = numChoices(t, good, 3);
      return { k: 'pick', prompt: 'Combien de points en tout ?', pic: { type: 'domino', d }, cols: 2, ...r };
    } },
  { id: 'chaine', cat: 'cal', title: 'Le calcul en chaîne', emoji: '⛓️', desc: 'Les calculs passent un par un : garde le résultat en tête !',
    gen(L, t) {
      let v = t.int(2, 9);
      const steps = [String(v)];
      const n = 1 + L;
      while (steps.length <= n) {
        const op = t.int(0, L <= 2 ? 1 : 3);
        if (op === 0) { const x = t.int(1, 5 + L * 2); v += x; steps.push(`+ ${x}`); }
        else if (op === 1) { const x = t.int(1, Math.max(1, Math.min(v - 1, 5 + L * 2))); if (v - x < 0) continue; v -= x; steps.push(`− ${x}`); }
        else if (op === 2) { const x = v <= 12 ? t.pick([2, 3]) : 2; if (v * x > 60) continue; v *= x; steps.push(`× ${x}`); }
        else { if (v % 2 || v < 4) continue; v /= 2; steps.push(': 2'); }
      }
      const ms = Math.max(800, 1300 - L * 100);
      return { k: 'num', prompt: 'Le résultat ?', show: { type: 'steps', items: steps, ms, text: true }, showMs: steps.length * ms + 400, maxLen: 4, ans: v };
    } },

  // ---- Voir (suite) ----
  { id: 'des', cat: 'voi', title: 'Les dés', emoji: '🎲', desc: 'Compte vite les points des dés !',
    gen(L, t) {
      const n = L <= 1 ? 2 : L <= 3 ? 3 : 4;
      const d = Array.from({ length: n }, () => t.int(1, 6));
      const good = d.reduce((s, v) => s + v, 0);
      const r = numChoices(t, good, 2);
      return { k: 'pick', prompt: 'Combien en tout ?', pic: { type: 'dice', d }, cols: 2, ...r };
    } },
  { id: 'tourne', cat: 'voi', title: 'La flèche qui tourne', emoji: '🔄', desc: 'Fais tourner la flèche dans ta tête : où pointe-t-elle ?',
    gen(L, t) {
      const A = ['⬆️', '➡️', '⬇️', '⬅️'];
      const start = t.int(0, 3);
      const moves = [[1, '¼ de tour à droite'], [3, '¼ de tour à gauche'], [2, 'un demi-tour']];
      const n = L <= 3 ? 1 : L === 4 ? 2 : 3;
      const pool = L <= 1 ? [moves[0]] : L === 2 ? moves.slice(0, 2) : moves;
      const seq = Array.from({ length: n }, () => t.pick(pool));
      const end = (start + seq.reduce((s, m) => s + m[0], 0)) % 4;
      return { k: 'pick', prompt: seq.map((m) => m[1]).join(', puis '), pic: { type: 'big', e: A[start] }, cols: 4, choices: A.map((e) => ({ e })), ans: end };
    } },
  { id: 'triangles', cat: 'voi', title: 'Les triangles', emoji: '🔺', desc: 'Combien de triangles en tout ? Même les grands !',
    gen(L, t) {
      const opts = [null, [[1, false]], [[2, false], [1, true]], [[3, false], [1, true]], [[2, true], [4, false]], [[3, true], [4, true]]][L];
      const [n, h] = t.pick(opts);
      const good = ((n + 2) * (n + 1) / 2) * (h ? 2 : 1);
      const r = numChoices(t, good, 3);
      return { k: 'pick', prompt: 'Combien de triangles ?', picBig: true, pic: { type: 'tri', n, h }, cols: 2, ...r };
    } },

  // ---- Réflexe (suite) ----
  { id: 'pairimpair', cat: 'rfx', title: 'Pair ou impair', emoji: '2️⃣', desc: 'Le nombre est-il pair ou impair ? Vite !',
    gen(L, t) {
      let text, v;
      if (L <= 4) { v = t.int(1, [0, 20, 99, 999, 9999][L]); text = String(v); }
      else { const a = t.int(2, 19), b = t.int(2, 19); v = a + b; text = `${a} + ${b}`; }
      return { k: 'pick', prompt: 'Pair ou impair ?', pic: { type: 'text', t: text, big: true }, cols: 2, choices: [{ t: 'Pair', c: 0xFF3F8CFF }, { t: 'Impair', c: 0xFFFF9A1F }], ans: v % 2 };
    } },
  { id: 'plusque', cat: 'rfx', title: 'Plus grand que…', emoji: '📏', desc: 'Le nombre est-il plus grand que le nombre demandé ?',
    gen(L, t) {
      const ref = t.int(2, 9) * 10;
      const gap = [0, 25, 15, 8, 4, 2][L];
      let v; do { v = ref + t.int(-gap, gap); } while (v === ref);
      return { k: 'pick', prompt: `Plus grand que ${ref} ?`, pic: { type: 'text', t: String(v), big: true }, cols: 2, choices: [{ t: '✅ Oui', c: 0xFF22B36B }, { t: '❌ Non', c: 0xFFE5484D }], ans: v > ref ? 0 : 1 };
    } },
  { id: 'inverse', cat: 'rfx', title: 'Le contraire', emoji: '🙃', desc: 'Touche la flèche qui va dans le sens CONTRAIRE !',
    gen(L, t) {
      const A = ['⬅️', '⬆️', '⬇️', '➡️'];
      const W = ['GAUCHE', 'HAUT', 'BAS', 'DROITE'];
      const OPP = [3, 2, 1, 0];
      const d = t.int(0, 3);
      const word = L <= 2 || t.rngRaw() < 0.5;
      return { k: 'pick', prompt: 'Le sens CONTRAIRE !', pic: word ? { type: 'text', t: W[d], big: true } : { type: 'big', e: A[d] }, cols: 4, choices: A.map((e) => ({ e })), ans: OPP[d] };
    } },
  { id: 'forme', cat: 'rfx', title: 'La bonne forme', emoji: '⭐', desc: 'Touche toutes les bonnes formes… mais pas les autres !',
    gen(L, t) {
      const pairs = [['⭐', '🔺'], ['🔵', '🟥'], ['❤️', '💙'], ['🟢', '🟩'], ['🌙', '☀️'], ['🍎', '🍅']];
      const [target, trap] = t.pick(pairs.slice(0, 3 + Math.min(3, L)));
      const n = L <= 3 ? 9 : 12;
      const good = 2 + Math.min(3, Math.floor(L / 2) + t.int(0, 1));
      const bad = Math.min(n - good - 1, t.int(2, 2 + L));
      const cells = t.some([...Array(n).keys()], good + bad);
      const items = Array.from({ length: n }, () => ({ e: '' }));
      cells.slice(0, good).forEach((c) => (items[c] = { e: target }));
      cells.slice(good).forEach((c) => (items[c] = { e: trap }));
      return { k: 'whack', prompt: `Tous les ${target}, pas les ${trap} !`, target, cols: n === 9 ? 3 : 4, items, ans: cells.slice(0, good).sort((a, b) => a - b) };
    } },

  // ---- Mots (suite) ----
  { id: 'pluriel', cat: 'mot', title: 'Le pluriel', emoji: '👥', desc: 'Comment s’écrit le mot au pluriel ?',
    gen(L, t) {
      const [sing, good, ...wr] = t.pick(PLURALS);
      const r = t.choices(good, wr);
      return { k: 'pick', prompt: 'Au pluriel ?', pic: { type: 'text', t: sing, big: true }, cols: 2, choices: r.choices.map((x) => ({ t: x })), ans: r.ans };
    } },
  { id: 'accord', cat: 'mot', title: 'Le bon accord', emoji: '✍️', desc: 'Quel mot complète bien la phrase ?',
    gen(L, t) {
      const [phrase, good, ...wr] = t.pick(AGREEMENTS);
      const r = t.choices(good, wr);
      return { k: 'pick', prompt: 'Complète la phrase', pic: { type: 'text', t: phrase }, cols: 2, choices: r.choices.map((x) => ({ t: x })), ans: r.ans };
    } },
  { id: 'long', cat: 'mot', title: 'Le plus long', emoji: '📏', desc: 'Quel mot a le plus de lettres ?',
    gen(L, t) {
      const lens = L <= 2 ? t.some([4, 5, 6, 7, 8], 4).sort() : L <= 4 ? (() => { const a = t.int(4, 5); return [a, a + 1, a + 2, a + 3]; })() : (() => { const a = t.int(5, 6); return [a, a, a + 1, a + 2]; })();
      const longest = Math.max(...lens);
      const words = [];
      for (const n of lens) { const w = t.pick(WORDS[n].filter((x) => !words.includes(x))); words.push(w); }
      // jamais deux mots de la plus grande longueur
      const good = words.find((w) => w.length === longest);
      const r = t.choices(good, words.filter((w) => w !== good));
      return { k: 'pick', prompt: 'Le mot le plus long ?', cols: 1, choices: r.choices.map((x) => ({ t: x })), ans: r.ans };
    } },
  { id: 'alpha', cat: 'mot', title: 'L’ordre alphabétique', emoji: '🔤', desc: 'Touche les mots dans l’ordre du dictionnaire !',
    gen(L, t) {
      const n = L <= 2 ? 3 : L <= 4 ? 4 : 5;
      const all = Object.values(WORDS).flat();
      let words;
      for (let g = 0; g < 50; g++) {
        if (L >= 4) { const first = t.pick(all)[0]; words = t.some(all.filter((w) => w[0] === first), n); }
        else words = t.some(all, n);
        const firsts = new Set(words.map((w) => w[0]));
        if (words.length === n && (L >= 4 || firsts.size === n) && new Set(words).size === n) break;
      }
      if (!words || words.length < n || new Set(words).size < n) words = t.some(all, n);
      const sorted = [...words].sort((a, b) => (fold(a) < fold(b) ? -1 : 1));
      return { k: 'seq', prompt: 'De A à Z', items: words.map((w) => ({ t: w })), n, tiles: true, reveal: sorted.join(' · '), ans: sorted.map((w) => words.indexOf(w)) };
    } },
  { id: 'rime', cat: 'mot', title: 'La rime', emoji: '🎵', desc: 'Quel mot rime avec le mot affiché ?',
    gen(L, t) {
      const [w, good, ...wr] = t.pick(RHYMES);
      const r = t.choices(good, wr);
      return { k: 'pick', prompt: 'Ça rime avec… ?', pic: { type: 'text', t: w, big: true }, cols: 2, choices: r.choices.map((x) => ({ t: x })), ans: r.ans };
    } },
];
const BY_ID = new Map(EPREUVES.map((e) => [e.id, e]));

// Fabrique la question n°i de niveau L (même graine = même question pour tous)
export function makeQuestion(epr, seed, i, L) {
  const rng = rngFrom(`${seed}:${epr.id}:${i}:${L}`);
  const t = { ...tools(rng), rngRaw: rng, rng };
  const q = epr.gen(L, t);
  return { ...q, i, L };
}

// La réponse est-elle juste ?
export function checkAnswer(q, v) {
  switch (q.k) {
    case 'pick':
    case 'cups':
      return Number.isInteger(v) && v === q.ans;
    case 'num':
      return (typeof v === 'number' || typeof v === 'string') && String(v).length <= 8 && Number(v) === q.ans;
    case 'seq': {
      if (!Array.isArray(v) || v.length !== q.n || !v.every((x) => Number.isInteger(x) && x >= 0 && x < q.items.length)) return false;
      if (q.word) {
        if (new Set(v).size !== v.length) return false;
        const s = v.map((x) => q.items[x].t).join('');
        if (s === q.word) return true;
        // mot mélangé : une autre vraie anagramme compte aussi (CHIEN / NICHE)
        return q.items.length === q.word.length && q.items.every((it) => it.t.length === 1) && dict().has(fold(s).toUpperCase().replace(/ /g, ''));
      }
      return v.length === q.ans.length && v.every((x, k) => x === q.ans[k] || (q.ordered && q.items[x].t === q.items[q.ans[k]].t));
    }
    case 'coins': {
      if (!Array.isArray(v) || !v.length || v.length > q.coins.length) return false;
      if (new Set(v).size !== v.length || !v.every((x) => Number.isInteger(x) && x >= 0 && x < q.coins.length)) return false;
      return v.reduce((s, x) => s + q.coins[x], 0) === q.target;
    }
    case 'multi':
    case 'whack': {
      if (!Array.isArray(v) || v.length > q.items.length) return false;
      const a = [...new Set(v)].sort((x, y) => x - y);
      return a.length === q.ans.length && a.every((x, k) => x === q.ans[k]);
    }
  }
  return false;
}

// Ce que le téléphone reçoit de la question (sans la réponse)
function publicQ(q) {
  const { ans, word, reveal, ...rest } = q;
  return rest;
}
// La bonne réponse, montrée après coup sur le téléphone (pour comprendre son erreur)
function answerOf(q) {
  if (q.reveal) return { text: q.reveal };
  if (q.k === 'pick') { const c = q.choices[q.ans]; return c?.t && c.t !== '?' ? { pick: q.ans, text: c.t } : { pick: q.ans }; }
  if (q.k === 'cups') return { pick: q.ans };
  if (q.k === 'num') return { num: q.ans };
  if (q.k === 'seq') return q.word ? { text: q.word } : { seq: q.ans };
  if (q.k === 'coins') return { seq: q.ans };
  return { seq: q.ans };
}

export class MeningesGame extends BaseGame {
  static id = 'meninges';

  static async create(room, opts, hooks) {
    return new MeningesGame(room, hooks, opts || {});
  }

  constructor(room, hooks, opts) {
    super(room, hooks);
    const count = MNG.rounds.includes(opts.rounds) ? opts.rounds : MNG.defaultRounds;
    const without = opts.without === 'Mots' ? ['mot'] : opts.without === 'Réflexe' ? ['rfx'] : opts.without === 'Mots et Réflexe' ? ['mot', 'rfx'] : [];
    const cats = CATS.filter((c) => !without.includes(c.id));
    // Catégories dans le désordre, puis on recommence ; une épreuve jamais deux fois dans la partie
    const order = [];
    while (order.length < count) order.push(...shuffle([...cats]));
    const used = new Set();
    this.plan = order.slice(0, count).map((c) => {
      const free = EPREUVES.filter((e) => e.cat === c.id && !used.has(e.id));
      const e = free[crypto.randomInt(free.length)];
      used.add(e.id);
      return e;
    });
    this.cats = cats;
    this.count = count;
    this.index = -1;
    this.epr = null;
    this.seed = '';
    this.st = new Map();        // pid -> état du joueur dans la partie
    this.news = null;           // { seq, text, kind, pid }
    this.newsSeq = 0;
    this.lastNewsAt = 0;
    this.pendingNews = null;
    this.newsTimer = null;
    this.changeTimer = null;
    this.lastLeader = null;
    this.everLed = new Set();
    this.medals = {};
    this.correctSeq = 0;
    this.roundStart = 0;
    for (const p of room.players.values()) this.stateOf(p.pid);
  }

  stateOf(pid) {
    let s = this.st.get(pid);
    if (!s) {
      s = { total: 0, cat: {}, level: 2, q: null, done: 0, ok: 0, ko: 0, streak: 0, best: 0, g: 0, until: 0, last: null };
      this.st.set(pid, s);
      if (!this.scores.has(pid)) this.scores.set(pid, 0);
    }
    return s;
  }

  onPlayerJoin(p) {
    super.onPlayerJoin(p);
    const s = this.stateOf(p.pid);
    if (this.phase === 'go' && !s.q) this.nextQuestion(p.pid, s, 0);
  }

  onPlayerGone() {}

  start() { this.schedule(MNG.introMs, () => this.announce()); }

  stop() {
    super.stop();
    clearTimeout(this.newsTimer);
    clearTimeout(this.changeTimer);
    clearTimeout(this.tenTimer);
  }

  announce() {
    this.index++;
    if (this.index >= this.count) return this.finish();
    this.epr = this.plan[this.index];
    this.seed = crypto.randomBytes(8).toString('hex');
    this.phase = 'announce';
    this.news = null;
    this.schedule(MNG.announceMs, () => this.go());
    this.changed();
  }

  go() {
    this.phase = 'go';
    this.roundStart = Date.now();
    this.saidClose = false;
    for (const [pid, s] of this.st) {
      Object.assign(s, { q: null, done: 0, ok: 0, ko: 0, streak: 0, g: 0, until: 0, last: null });
      if (this.room.players.has(pid)) this.nextQuestion(pid, s, 0);
    }
    clearTimeout(this.tenTimer);
    this.tenTimer = setTimeout(() => { if (!this.over && this.phase === 'go') this.say('Plus que 10 secondes !', 'ten', null, 1); }, Math.max(0, MNG.goMs - 10000));
    this.schedule(MNG.goMs, () => this.result());
    this.changed();
  }

  nextQuestion(pid, s, wait) {
    s.q = makeQuestion(this.epr, this.seed, s.done, s.level);
    s.until = Date.now() + wait;
    this.hooks.sendTo(pid, { t: 'mng_q', r: this.index, q: publicQ(s.q), wait, last: s.last, ok: s.ok, ko: s.ko, streak: s.streak, g: s.g });
  }

  onMessage(p, m) {
    if (m.t === 'mng_answer') {
      if (this.phase !== 'go' || m.r !== this.index) return;
      const s = this.stateOf(p.pid);
      if (!s.q || m.i !== s.q.i || Date.now() < s.until - 50) return;
      this.answer(p.pid, s, m.v);
      return;
    }
    // Hôte : étape suivante (manche suivante, ou retour au salon depuis le podium) / fin
    if (p.pid !== this.room.hostPid) return;
    if (m.t === 'game_end') { if (this.phase !== 'podium') this.finish(); return; }
    if (m.t === 'game_skip') {
      if (this.phase === 'intro' || this.phase === 'result') this.announce();
      else if (this.phase === 'announce') this.go();
      else if (this.phase === 'go') this.result();
      else if (this.phase === 'podium') this.hooks.finished(this.results());
    }
  }

  answer(pid, s, v) {
    const q = s.q;
    const ok = checkAnswer(q, v);
    s.done++;
    if (ok) {
      s.ok++; s.streak++; s.best = Math.max(s.best, s.streak);
      const grams = 8 + 3 * q.L + Math.min(s.streak, 8);
      s.g += grams; s.total += grams;
      s.cat[this.epr.cat] = (s.cat[this.epr.cat] || 0) + grams;
      this.scores.set(pid, s.total);
      if (s.streak % 3 === 0) s.level = Math.min(5, s.level + 1);
      this.correctSeq++;
      s.last = { i: q.i, ok: true, g: grams };
    } else {
      s.ko++; s.streak = 0;
      s.level = Math.max(1, s.level - 1);
      s.last = { i: q.i, ok: false, ...answerOf(q) };
    }
    this.nextQuestion(pid, s, ok ? 0 : MNG.wrongMs);
    this.commentate(pid, s, ok);
    this.soon();
  }

  // État public rediffusé au plus toutes les 250 ms (sinon 15 joueurs = 60 envois par seconde)
  soon() {
    if (this.changeTimer) return;
    this.changeTimer = setTimeout(() => { this.changeTimer = null; if (!this.over) this.changed(); }, MNG.changedMs);
  }

  // ---- l'animateur ----
  leaderboard() {
    return [...this.st.entries()].filter(([pid]) => this.room.players.has(pid)).sort((a, b) => b[1].total - a[1].total);
  }

  nameOf(pid) { return this.room.players.get(pid)?.name ?? '?'; }

  commentate(pid, s, ok) {
    const lb = this.leaderboard();
    const leader = lb[0];
    if (leader && leader[1].total > 0 && (!lb[1] || leader[1].total > lb[1][1].total) && leader[0] !== this.lastLeader) {
      const back = this.everLed.has(leader[0]) && this.lastLeader !== null;
      if (this.lastLeader !== null || leader[1].total > 40) {
        this.say(`${this.nameOf(leader[0])} ${back ? 'reprend' : 'passe en'} la tête !`, 'lead', leader[0], 3);
      }
      this.lastLeader = leader[0];
      this.everLed.add(leader[0]);
    }
    if (ok && (s.streak === 5 || s.streak === 10 || s.streak === 15)) {
      this.say(s.streak === 5 ? `${this.nameOf(pid)} est en feu : 5 d’affilée !` : `${s.streak} d’affilée pour ${this.nameOf(pid)}, incroyable !`, 'streak', pid, 2);
    }
    if (!this.saidClose && lb.length >= 2 && lb[0][1].g > 40 && Math.abs(lb[0][1].total - lb[1][1].total) <= 12 && Date.now() - this.roundStart > 8000) {
      this.saidClose = true;
      this.say(`${this.nameOf(lb[0][0])} et ${this.nameOf(lb[1][0])} sont au coude à coude !`, 'close', null, 1);
    }
  }

  // Une annonce (bandeau TV + animateur) ; au plus une toutes les 4 s, la plus importante d'abord
  say(text, kind, pid, prio) {
    const n = { text, kind, pid, prio };
    if (this.news && this.news.kind === kind && this.news.pid === pid && pid) return;
    const now = Date.now();
    if (now - this.lastNewsAt >= MNG.newsGapMs && !this.pendingNews) return this.emitNews(n);
    if (!this.pendingNews || prio >= this.pendingNews.prio) this.pendingNews = n;
    if (!this.newsTimer) {
      this.newsTimer = setTimeout(() => {
        this.newsTimer = null;
        const p = this.pendingNews; this.pendingNews = null;
        if (p && !this.over) this.emitNews(p);
      }, Math.max(50, MNG.newsGapMs - (now - this.lastNewsAt)));
    }
  }

  emitNews(n) {
    this.lastNewsAt = Date.now();
    this.news = { seq: ++this.newsSeq, text: n.text, kind: n.kind, pid: n.pid ?? null };
    this.soon();
  }

  result() {
    if (this.phase !== 'go') return;
    this.phase = 'result';
    clearTimeout(this.tenTimer);
    for (const s of this.st.values()) s.q = null;
    const lb = [...this.st.entries()].filter(([pid]) => this.room.players.has(pid)).sort((a, b) => b[1].g - a[1].g);
    const cat = CATS.find((c) => c.id === this.epr.cat);
    const parts = [];
    if (lb[0] && lb[0][1].g > 0) parts.push(`${this.nameOf(lb[0][0])} remporte la manche ${cat.name} !`);
    const gl = this.leaderboard();
    if (this.index === this.count - 2 && gl[1] && gl[0][1].total > 0) parts.push(`Dernière manche ! ${this.nameOf(gl[0][0])} n’a que ${gl[0][1].total - gl[1][1].total} grammes d’avance, tout peut basculer !`);
    else if (gl[0] && gl[0][1].total > 0) parts.push(`Au général, ${this.nameOf(gl[0][0])} est en tête.`);
    this.pendingNews = null; clearTimeout(this.newsTimer); this.newsTimer = null;
    this.news = parts.length ? { seq: ++this.newsSeq, text: parts.join(' '), kind: 'result', pid: lb[0]?.[0] ?? null } : null;
    this.schedule(MNG.resultMs, () => this.announce());
    this.changed();
  }

  finish() {
    if (this.phase === 'podium') return;
    clearTimeout(this.tenTimer);
    for (const s of this.st.values()) s.q = null;
    // Médaille de chaque catégorie jouée : le plus de grammes dans cette catégorie
    this.medals = {};
    for (const c of new Set(this.plan.slice(0, Math.max(0, this.index + 1)).map((e) => e.cat))) {
      let best = null;
      for (const [pid, s] of this.st) if (this.room.players.has(pid) && (s.cat[c] || 0) > 0 && (!best || s.cat[c] > best[1])) best = [pid, s.cat[c]];
      if (best) this.medals[c] = best[0];
    }
    this.news = null;
    this.podium(MNG.podiumMs);
  }

  // Points du jeu : 1000 au plus lourd cerveau, puis −100 par place (100 minimum), 0 sans bonne réponse
  results() {
    return super.results().map((r) => ({ ...r, grams: r.score, score: r.score > 0 ? Math.max(100, 1000 - 100 * (r.rank - 1)) : 0 }));
  }

  publicState() {
    const players = {};
    for (const [pid, s] of this.st) {
      if (!this.room.players.has(pid)) continue;
      players[pid] = { done: s.done, ok: s.ok, ko: s.ko, streak: s.streak, g: s.g, total: s.total, w: MNG.baseGrams + s.total, ...(this.phase === 'podium' ? { cat: s.cat, best: s.best } : {}) };
    }
    const e = this.epr;
    return {
      ...this.base('meninges'),
      index: this.index,
      count: this.count,
      turn: this.newsSeq,          // pour l'animateur vocal : une annonce de plus = une phrase de plus
      cats: this.cats,
      plan: this.plan.map((x) => x.cat),
      epr: e ? { id: e.id, cat: e.cat, title: e.title, emoji: e.emoji, desc: e.desc } : null,
      players,
      news: this.news,
      correctSeq: this.correctSeq,
      medals: this.phase === 'podium' ? this.medals : null,
      base: MNG.baseGrams,
    };
  }

  playerState(pid) {
    const s = this.st.get(pid);
    if (!s) return null;
    const rk = this.ranking().find((r) => r.pid === pid);
    return {
      r: this.index,
      q: this.phase === 'go' && s.q ? publicQ(s.q) : null,
      wait: Math.max(0, s.until - Date.now()),
      last: s.last,
      ok: s.ok, ko: s.ko, streak: s.streak, g: s.g, total: s.total, w: MNG.baseGrams + s.total,
      cat: s.cat, best: s.best,
      rank: rk?.rank, score: s.total, players: this.ranking().length,
    };
  }

  // Robots : répondent après un temps de réflexion, se trompent parfois (Malin moins souvent)
  botAction(pid, level) {
    if (this.phase !== 'go') return null;
    const s = this.stateOf(pid);
    if (!s.q) return null;
    const q = s.q;
    const malin = level === 'malin';
    const plan = this.botMemo(`${pid}-${this.index}-${q.i}`, () => ({
      ok: Math.random() < (malin ? 0.85 : 0.65),
      ms: malin ? botMs(1300, 2600) : botMs(2000, 4200),
    }));
    const wrong = q.k === 'num' ? q.ans + 1 : q.k === 'pick' || q.k === 'cups' ? (q.ans + 1) % Math.max(2, q.choices?.length ?? q.n ?? 2) : [];
    const v = plan.ok ? (q.k === 'seq' && q.word ? wordIndices(q) : q.ans) : wrong;
    return { m: { t: 'mng_answer', r: this.index, i: q.i, v }, ms: Math.max(plan.ms, s.until - Date.now() + 50) };
  }
}

// Robot : les indices des tuiles qui écrivent le mot dans l'ordre
function wordIndices(q) {
  const used = new Set();
  const out = [];
  let pos = 0;
  while (pos < q.word.length) {
    const k = q.items.findIndex((it, j) => !used.has(j) && q.word.startsWith(it.t, pos));
    if (k < 0) return [];
    used.add(k); out.push(k); pos += q.items[k].t.length;
  }
  return out;
}

export { BY_ID as MNG_EPREUVES };
