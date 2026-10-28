// Emojis avec leur nom en français, par famille (Zoom mystère, Mémoire).
// Les « choix » d'une question viennent de la même famille : plus difficile.
export const EMOJI_FAMILIES = {
  animaux: [
    ['🐶', 'Chien'], ['🐱', 'Chat'], ['🐭', 'Souris'], ['🐰', 'Lapin'], ['🦊', 'Renard'], ['🐻', 'Ours'],
    ['🐼', 'Panda'], ['🐨', 'Koala'], ['🐯', 'Tigre'], ['🦁', 'Lion'], ['🐮', 'Vache'], ['🐷', 'Cochon'],
    ['🐸', 'Grenouille'], ['🐵', 'Singe'], ['🐔', 'Poule'], ['🐧', 'Pingouin'], ['🦉', 'Hibou'], ['🦄', 'Licorne'],
    ['🐝', 'Abeille'], ['🦋', 'Papillon'], ['🐌', 'Escargot'], ['🐢', 'Tortue'], ['🐍', 'Serpent'], ['🐙', 'Pieuvre'],
    ['🦀', 'Crabe'], ['🐬', 'Dauphin'], ['🐳', 'Baleine'], ['🦈', 'Requin'], ['🐘', 'Éléphant'], ['🦒', 'Girafe'],
    ['🦓', 'Zèbre'], ['🦘', 'Kangourou'], ['🐫', 'Chameau'], ['🦔', 'Hérisson'], ['🦩', 'Flamant rose'], ['🦜', 'Perroquet'],
  ],
  nourriture: [
    ['🍎', 'Pomme'], ['🍌', 'Banane'], ['🍇', 'Raisin'], ['🍓', 'Fraise'], ['🍉', 'Pastèque'], ['🍍', 'Ananas'],
    ['🥝', 'Kiwi'], ['🍒', 'Cerises'], ['🍋', 'Citron'], ['🥕', 'Carotte'], ['🌽', 'Maïs'], ['🥦', 'Brocoli'],
    ['🍄', 'Champignon'], ['🥐', 'Croissant'], ['🥖', 'Baguette'], ['🧀', 'Fromage'], ['🍕', 'Pizza'], ['🍔', 'Hamburger'],
    ['🍟', 'Frites'], ['🌭', 'Hot-dog'], ['🥚', 'Œuf'], ['🍩', 'Donut'], ['🍪', 'Cookie'], ['🎂', 'Gâteau d’anniversaire'],
    ['🍦', 'Glace'], ['🍫', 'Chocolat'], ['🍿', 'Pop-corn'], ['🥨', 'Bretzel'], ['🍣', 'Sushi'], ['🥥', 'Noix de coco'],
  ],
  objets: [
    ['⚽', 'Ballon de foot'], ['🏀', 'Ballon de basket'], ['🎸', 'Guitare'], ['🎺', 'Trompette'], ['🥁', 'Tambour'], ['🎹', 'Piano'],
    ['📱', 'Téléphone'], ['💻', 'Ordinateur portable'], ['⌚', 'Montre'], ['📷', 'Appareil photo'], ['🔑', 'Clé'], ['🔨', 'Marteau'],
    ['✂️', 'Ciseaux'], ['📚', 'Livres'], ['✏️', 'Crayon'], ['🎈', 'Ballon de baudruche'], ['🎁', 'Cadeau'], ['🕯️', 'Bougie'],
    ['💡', 'Ampoule'], ['🔦', 'Lampe de poche'], ['☂️', 'Parapluie'], ['👓', 'Lunettes'], ['👑', 'Couronne'], ['🎩', 'Chapeau haut-de-forme'],
    ['👟', 'Basket'], ['🧦', 'Chaussettes'], ['🪑', 'Chaise'], ['🛁', 'Baignoire'], ['⏰', 'Réveil'], ['🧸', 'Ours en peluche'],
  ],
  nature: [
    ['🌵', 'Cactus'], ['🌲', 'Sapin'], ['🌴', 'Palmier'], ['🌻', 'Tournesol'], ['🌹', 'Rose'], ['🍀', 'Trèfle à quatre feuilles'],
    ['🍁', 'Feuille d’érable'], ['🌈', 'Arc-en-ciel'], ['⛄', 'Bonhomme de neige'], ['🌋', 'Volcan'], ['🌙', 'Lune'], ['⭐', 'Étoile'],
    ['☀️', 'Soleil'], ['⚡', 'Éclair'], ['🔥', 'Feu'], ['💧', 'Goutte d’eau'], ['🌊', 'Vague'], ['❄️', 'Flocon de neige'],
  ],
  transports: [
    ['🚗', 'Voiture'], ['🚕', 'Taxi'], ['🚌', 'Bus'], ['🚓', 'Voiture de police'], ['🚑', 'Ambulance'], ['🚒', 'Camion de pompiers'],
    ['🚜', 'Tracteur'], ['🚲', 'Vélo'], ['🛵', 'Scooter'], ['🚂', 'Locomotive'], ['🚁', 'Hélicoptère'], ['✈️', 'Avion'],
    ['🚀', 'Fusée'], ['⛵', 'Voilier'], ['🚢', 'Paquebot'], ['🛸', 'Soucoupe volante'], ['🚃', 'Wagon'], ['🛴', 'Trottinette'],
  ],
};

export const ALL_EMOJIS = Object.entries(EMOJI_FAMILIES).flatMap(([family, list]) => list.map(([e, name]) => ({ e, name, family })));
