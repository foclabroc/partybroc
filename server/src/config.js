// Réglages du serveur, tous modifiables par variables d'environnement
// (sous Windows : dans la config NSSM du service, onglet Environment).
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));

export const config = {
  // Port local (Caddy fait le HTTPS devant)
  port: Number(process.env.PB_PORT || 4100),
  host: process.env.PB_HOST || '127.0.0.1',
  // Dossier du site Flutter compilé (flutter build web)
  webDir: process.env.PB_WEB_DIR || path.resolve(here, '../../app/build/web'),
  // Connexion PostgreSQL ; vide = le serveur tourne sans enregistrer l'historique
  dbUrl: process.env.PB_DB_URL || '',

  maxRooms: 50,
  // Par adresse IP (tous les appareils d'une maison partagent la même)
  maxRoomsPerIp: Number(process.env.PB_ROOMS_PER_IP || 5),
  maxConnsPerIp: 40,
  // Salons permanents (en base) et joueurs gardés par salon
  maxPermRooms: 30,
  maxMembers: 60,
  maxPlayers: 15,
  // Un joueur déconnecté garde sa place ce temps-là (téléphone en veille, etc.)
  playerGraceMs: 3 * 60 * 1000,
  // Un salon sans TV ni joueur connecté est fermé au bout de ce temps
  roomIdleMs: 15 * 60 * 1000,
  // Taille max d'une photo de profil (déjà réduite par l'appli)
  maxAvatarBytes: 60 * 1024,
  // Taille max d'un message WebSocket
  maxPayload: 400 * 1024, // une photo de Photo roulette (≤ 220 Ko, en base64)
};
