// Salons permanents : nom du salon, mot de passe, empreintes, protection contre les essais en série.
import crypto from 'node:crypto';
import { promisify } from 'node:util';

const scrypt = promisify(crypto.scrypt);

// « Famille Dupont » → FAMILLEDUPONT (lettres seulement, sans accents). 5 à 12 lettres :
// jamais confondu avec un code de salon normal (4 lettres).
export function permCode(raw) {
  if (typeof raw !== 'string') return '';
  return raw.normalize('NFKD').replace(/\p{M}/gu, '').toUpperCase().replace(/[^A-Z]/g, '');
}
export const isPermCode = (c) => /^[A-Z]{5,12}$/.test(c);

export function checkPassword(pw) {
  if (typeof pw !== 'string' || [...pw].length < 4) throw new Error('Mot de passe : 4 caractères minimum');
  if ([...pw].length > 64) throw new Error('Mot de passe trop long');
  return pw;
}

export async function hashPassword(pw) {
  const salt = crypto.randomBytes(16);
  const h = await scrypt(pw.normalize('NFC'), salt, 32);
  return `scrypt$${salt.toString('base64')}$${h.toString('base64')}`;
}

export async function passwordOk(pw, stored) {
  if (typeof pw !== 'string' || typeof stored !== 'string') return false;
  const [kind, salt, hash] = stored.split('$');
  if (kind !== 'scrypt' || !salt || !hash) return false;
  const h = await scrypt(pw.normalize('NFC'), Buffer.from(salt, 'base64'), 32);
  const want = Buffer.from(hash, 'base64');
  return want.length === h.length && crypto.timingSafeEqual(want, h);
}

// Jetons (téléphone d'un membre, écran autorisé) : seule leur empreinte va en base
export const newToken = () => crypto.randomBytes(18).toString('base64url');
export const sha = (t) => crypto.createHash('sha256').update(String(t)).digest('hex');

// Essais de mot de passe ratés : 8 par quart d'heure et par adresse, ensuite on refuse
const fails = new Map();
const WINDOW = 15 * 60 * 1000;
const MAX_FAILS = 8;

export function blocked(ip) {
  const f = fails.get(ip);
  if (!f) return false;
  if (Date.now() - f.since > WINDOW) { fails.delete(ip); return false; }
  return f.n >= MAX_FAILS;
}

export function failed(ip) {
  const f = fails.get(ip);
  if (!f || Date.now() - f.since > WINDOW) fails.set(ip, { n: 1, since: Date.now() });
  else f.n++;
}

// Créations de salons permanents : 3 par heure et par adresse
const creates = new Map();
export function mayCreate(ip) {
  const now = Date.now();
  const list = (creates.get(ip) || []).filter((t) => now - t < 3600_000);
  if (list.length >= 3) return false;
  list.push(now);
  creates.set(ip, list);
  return true;
}
