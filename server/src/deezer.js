// Extraits de 30 s de Deezer pour le Blind test (API publique, sans compte ni clé).
// - Les playlists sont gardées 6 h en mémoire (titres, artistes, pochettes).
// - L'adresse d'un extrait est signée et n'est valable qu'environ 15 min : on la redemande
//   (/track/<id>) juste avant de jouer chaque musique.
// - Les tests remplacent l'accès réseau par setDeezerFetch().
const API = 'https://api.deezer.com';
const TTL = 6 * 3600_000;
const cache = new Map(); // clé (playlist ou chart) -> { at, tracks }

let getJson = async (path) => {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), 6000);
  try {
    const r = await fetch(API + path, { signal: ctl.signal, headers: { 'accept-language': 'fr' } });
    if (!r.ok) throw new Error(`Deezer ${r.status}`);
    const j = await r.json();
    if (j?.error) throw new Error(`Deezer : ${j.error.message || 'erreur'}`);
    return j;
  } finally {
    clearTimeout(t);
  }
};

export function setDeezerFetch(fn) { getJson = fn; cache.clear(); }

// « Chocolat (feat. Awa Imani) » → « Chocolat » ; « Goldorak (Générique original…) » → « Goldorak » ;
// « Creep - Remastered 2009 » → « Creep »
export function cleanTitle(s) {
  let t = String(s || '').replace(/\s*[([][^)\]]*(feat|ft\.|with |remaster|version|edit|mix|live|générique|generique|bande originale|from |b\.o|o\.s\.t|instrumental|mono|stereo|radio)[^)\]]*[)\]]/gi, '');
  t = t.replace(/\s*\(\d{4}\)/g, '');
  t = t.replace(/\s+-\s+(.*(remaster|version|edit|mix|live|mono|stereo|radio|bande originale|from |theme|générique|generique|main title).*)$/i, '');
  t = t.replace(/\s+/g, ' ').trim();
  return t || String(s || '').trim();
}

function toTrack(t, group) {
  if (!t || !t.readable || !t.preview || !t.id || !t.artist?.name) return null;
  // Tout public : pas de paroles explicites
  if (t.explicit_lyrics) return null;
  const title = cleanTitle(t.title_short || t.title);
  if (!title || title.length > 60 || t.artist.name.length > 40) return null;
  return {
    id: t.id,
    title,
    artist: t.artist.name.trim(),
    album: (t.album?.title || '').trim(),
    cover: t.album?.cover_big || t.album?.cover_medium || '',
    group,
  };
}

// Toutes les musiques jouables d'une source : { playlist: id } ou { chart: true }
async function loadSource(src, group) {
  const key = src.chart ? 'chart' : `p${src.playlist}`;
  const hit = cache.get(key);
  if (hit && Date.now() - hit.at < TTL) return hit.tracks.map((t) => ({ ...t, group }));
  const j = await getJson(src.chart ? '/chart/0/tracks?limit=100' : `/playlist/${src.playlist}/tracks?limit=400`);
  const tracks = (j?.data || []).map((t) => toTrack(t, group)).filter(Boolean);
  cache.set(key, { at: Date.now(), tracks });
  return tracks;
}

// Charge plusieurs sources ; une source en panne est ignorée si les autres répondent
export async function loadTracks(sources, allow = () => true) {
  const lists = await Promise.allSettled(sources.map(async (s) => (await loadSource(s, s.group)).filter((t) => allow(t, s))));
  const ok = lists.filter((r) => r.status === 'fulfilled').map((r) => r.value);
  if (!ok.length) throw new Error('Deezer ne répond pas, réessaie dans un instant');
  // Une même chanson peut être dans deux playlists : une seule fois
  const seen = new Set();
  const out = [];
  for (const t of ok.flat()) {
    const k = `${fold(t.artist)}|${fold(t.title)}`;
    if (seen.has(t.id) || seen.has(k)) continue;
    seen.add(t.id);
    seen.add(k);
    out.push(t);
  }
  return out;
}

// Adresse fraîche de l'extrait (ou null si la musique n'est plus disponible)
export async function freshPreview(id) {
  try {
    const t = await getJson(`/track/${id}`);
    return t?.readable !== false && typeof t?.preview === 'string' && t.preview.startsWith('https://') ? t.preview : null;
  } catch {
    return null;
  }
}

// Nom du film d'après l'album : « Vaiana - La Légende… (Bande originale…) » → « Vaiana »,
// « The Lion King: Special Edition… » → « The Lion King »
export function cleanAlbum(s) {
  let t = String(s || '').replace(/\s*[([][^)\]]*[)\]]/g, '');
  t = t.split(/\s+-\s+|:\s/)[0];
  t = t.replace(/\b(bande originale|original (motion picture )?soundtrack|soundtrack|b\.?o\.?f?)\b.*$/i, '');
  return t.replace(/\s+/g, ' ').trim();
}

export function fold(s) {
  return String(s).normalize('NFKD').replace(/\p{M}/gu, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
}
