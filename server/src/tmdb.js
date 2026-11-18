// Films et images de TMDB (themoviedb.org) pour le Quiz cinéma.
// Clé gratuite : variable PB_TMDB_KEY, ou fichier tmdb.key à la racine du dossier (hors dépôt).
// - Listes de films par catégorie (les plus connus d'abord), gardées 24 h en mémoire.
// - Images de scènes « sans texte » (include_image_language=null) : pas de titre écrit dessus.
// - Les tests remplacent l'accès réseau par setTmdbFetch().
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const API = 'https://api.themoviedb.org/3';
export const IMG = 'https://image.tmdb.org/t/p/';
const TTL = 24 * 3600_000;
const cache = new Map();
const here = path.dirname(fileURLToPath(import.meta.url));

export function tmdbKey() {
  if (process.env.PB_TMDB_KEY) return process.env.PB_TMDB_KEY.trim();
  try {
    return fs.readFileSync(path.resolve(here, '../../tmdb.key'), 'utf8').trim();
  } catch {
    return '';
  }
}

let getJson = async (p, params = {}) => {
  const key = tmdbKey();
  if (!key) throw new Error('Clé TMDB manquante sur le serveur (fichier tmdb.key)');
  const u = new URL(API + p);
  u.searchParams.set('api_key', key);
  for (const [k, v] of Object.entries(params)) u.searchParams.set(k, String(v));
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), 7000);
  try {
    const r = await fetch(u, { signal: ctl.signal });
    if (r.status === 401) throw new Error('Clé TMDB refusée');
    if (!r.ok) throw new Error(`TMDB ${r.status}`);
    return await r.json();
  } finally {
    clearTimeout(t);
  }
};

export function setTmdbFetch(fn) { getJson = fn; cache.clear(); }

// Tout public : seulement les films classés G, PG ou PG-13 aux États-Unis (un film sans
// classement est écarté), pas d'horreur
const SAFE = { include_adult: false, certification_country: 'US', certification: 'G|PG|PG-13', without_genres: '27' };
const decade = (a) => ({ ...SAFE, 'primary_release_date.gte': `${a}-01-01`, 'primary_release_date.lte': `${a + 9}-12-31` });

export const CINE_CATEGORIES = [
  { name: 'Dessins animés', params: { ...SAFE, with_genres: '16' } },
  { name: 'Films cultes', params: { ...SAFE, 'vote_average.gte': 7 } },
  // Films français : les classements français de TMDB sont incomplets, on garde comédies,
  // familial, animation et aventure, sans drame, romance, thriller, policier, horreur ni guerre
  { name: 'Films français', params: { include_adult: false, with_original_language: 'fr', with_genres: '35|10751|16|12', without_genres: '18,10749,53,80,27,10752' } },
  { name: 'Années 80', params: decade(1980) },
  { name: 'Années 90', params: decade(1990) },
  { name: 'Années 2000', params: decade(2000) },
  { name: 'Années 2010', params: decade(2010) },
  { name: 'Années 2020', params: decade(2020) },
];

let genres = null;
async function genreNames() {
  if (genres) return genres;
  const j = await getJson('/genre/movie/list', { language: 'fr-FR' });
  genres = Object.fromEntries((j?.genres || []).map((g) => [g.id, g.name]));
  return genres;
}

// Les films les plus connus d'une catégorie (5 pages = 100 films)
export async function loadFilms(cat, pages = 5) {
  const hit = cache.get(cat.name);
  if (hit && Date.now() - hit.at < TTL) return hit.films;
  let failure = null;
  const g = await genreNames().catch(() => ({}));
  const lists = await Promise.all(
    Array.from({ length: pages }, (_, i) =>
      getJson('/discover/movie', { language: 'fr-FR', sort_by: 'vote_count.desc', page: i + 1, ...cat.params }).catch((e) => { failure ??= e; return null; })),
  );
  const seen = new Set();
  const films = [];
  for (const m of lists.flatMap((l) => l?.results || [])) {
    if (!m?.id || seen.has(m.id) || !m.title || !m.backdrop_path || m.adult) continue;
    seen.add(m.id);
    films.push({
      id: m.id,
      title: m.title.trim(),
      year: Number(String(m.release_date || '').slice(0, 4)) || null,
      genres: (m.genre_ids || []).map((x) => g[x]).filter(Boolean).slice(0, 2),
      poster: m.poster_path ? IMG + 'w342' + m.poster_path : '',
      backdrop: m.backdrop_path,
      group: cat.name,
    });
  }
  if (!films.length) throw failure?.message?.startsWith('Clé TMDB') ? failure : new Error('TMDB ne répond pas, réessaie dans un instant');
  cache.set(cat.name, { at: Date.now(), films });
  return films;
}

// Une scène du film (au hasard parmi les mieux notées, sans texte) + le réalisateur
export async function filmScene(film) {
  let img = film.backdrop;
  let director = '';
  try {
    const [im, det] = await Promise.all([
      getJson(`/movie/${film.id}/images`, { include_image_language: 'null' }),
      getJson(`/movie/${film.id}/credits`, { language: 'fr-FR' }).catch(() => null),
    ]);
    const list = (im?.backdrops || []).filter((b) => b.width >= 1000).sort((a, b) => b.vote_count - a.vote_count).slice(0, 8);
    if (list.length) img = list[Math.floor(Math.random() * list.length)].file_path;
    director = (det?.crew || []).filter((c) => c.job === 'Director').map((c) => c.name).slice(0, 2).join(', ');
  } catch {
    // on garde l'image principale du film
  }
  return { image: IMG + 'w1280' + img, director };
}
