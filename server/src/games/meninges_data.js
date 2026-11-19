// Contenu de la Bataille de méninges (écrit à la main, tout public).

// Paires qui se ressemblent (l'intrus) : [le plus courant, l'intrus], des plus faciles aux plus durs
export const LOOKALIKE = [
  ['🐶', '🐱'], ['🍎', '🍌'], ['⚽', '🏀'], ['🐮', '🐷'], ['🚗', '🚲'], ['🌲', '🌵'],
  ['🍎', '🍏'], ['🐟', '🐠'], ['🌸', '🌺'], ['🚗', '🚙'], ['🐭', '🐹'], ['🍩', '🍪'],
  ['😀', '😃'], ['⭐', '🌟'], ['🌲', '🌳'], ['😺', '😸'], ['🌕', '🌖'], ['🔵', '🟣'],
  ['😐', '😑'], ['🕐', '🕑'], ['🌑', '🌒'], ['😊', '☺️'], ['🙂', '🙃'], ['🐻', '🐨'],
];

// Silhouettes (la bonne ombre) : familles de formes proches
export const SHAPES = [
  ['🐘', '🦒', '🐇', '🐈', '🐕', '🦌', '🐎', '🐿️', '🦘', '🐓', '🦆', '🐢', '🦔', '🐄', '🐖'],
  ['🍎', '🍐', '🍋', '🍌', '🍇', '🍓', '🍒', '🥕', '🍆', '🥦', '🍄', '🥑', '🌽'],
  ['🚗', '🚌', '🚲', '🛵', '🚂', '✈️', '🚁', '⛵', '🚀', '🛴', '🚜', '🚒'],
  ['🎸', '🎺', '🎻', '🥁', '🎷', '🎹', '🪗', '🪕'],
  ['🔨', '🔧', '🪛', '✂️', '🔑', '🪚', '📎', '🖊️', '✏️', '🖌️'],
  ['☂️', '👓', '👑', '🎩', '👟', '🧦', '👒', '🧤', '👜', '🎒'],
];

// Dessins qui ne sont pas symétriques (le miroir)
export const ASYM = ['🦒', '🐌', '🦆', '🚗', '🐟', '🦕', '🐎', '👢', '🎺', '🚀', '🦜', '🐊', '🐿️', '🦘', '🐓', '🚲', '🛵', '🔨'];

// Petits objets à retenir
export const MEMO = ['🍎', '🍌', '🍇', '🍓', '🐶', '🐱', '🐸', '🐵', '⚽', '🎈', '🎁', '🔑', '🚗', '⭐', '🌙', '☀️', '🌸', '🍄', '🧀', '🍕', '🎸', '📚', '👑', '🧸', '🦋', '🐢', '🍩', '🌵'];
export const ANIMALS = ['🐶', '🐱', '🐭', '🐰', '🦊', '🐻', '🐼', '🐯', '🦁', '🐮', '🐷', '🐸', '🐵', '🐔', '🐧', '🦉'];

// Couleurs (Stroop, cases) : nom, couleur
export const COLORS = [
  ['ROUGE', 0xFFE5484D], ['BLEU', 0xFF3F8CFF], ['VERT', 0xFF22B36B], ['JAUNE', 0xFFF5C400],
  ['VIOLET', 0xFF9B5CFF], ['ORANGE', 0xFFFF8A1F], ['ROSE', 0xFFFF4FA3],
];

// Mots à remettre dans l'ordre (sans accents), par longueur
export const WORDS = {
  4: ['CHAT', 'LOUP', 'LAPIN', 'PAIN', 'LAIT', 'BEAU', 'FLEUR', 'NUIT', 'JOUR', 'LUNE', 'ROUE', 'VELO', 'SAC', 'MAIN', 'PIED', 'NEZ', 'DENT', 'BOIS', 'FEUX', 'NOIX', 'POIRE', 'SEL', 'MIEL', 'OURS', 'COQ', 'BLE', 'LION', 'ROSE', 'CAKE', 'MOTO', 'BATEAU', 'TAXI', 'CERF', 'LOGO'].filter((w) => w.length === 4),
  5: ['LAPIN', 'FLEUR', 'POIRE', 'TIGRE', 'ZEBRE', 'PIANO', 'TABLE', 'CHAUD', 'FROID', 'PLAGE', 'NEIGE', 'POMME', 'SUCRE', 'MOUTON', 'CHIEN', 'PORTE', 'LIVRE', 'ROUGE', 'VERTE', 'BALLE', 'SINGE', 'TARTE', 'CREPE', 'TRAIN', 'AVION', 'MONDE', 'TERRE', 'ARBRE', 'FORET', 'JUPE', 'GANTS', 'LAMPE', 'PLUIE', 'ORAGE'].filter((w) => w.length === 5),
  6: ['MOUTON', 'BATEAU', 'CHEVAL', 'CAMION', 'JARDIN', 'MAISON', 'BANANE', 'CERISE', 'ORANGE', 'GIRAFE', 'LAPINS', 'SOLEIL', 'NUAGES', 'CARTON', 'BOUGIE', 'CHAISE', 'CANARD', 'FROMAGE', 'TOMATE', 'CAROTTE', 'PIRATE', 'FUSEE', 'DRAGON', 'BALLON', 'TORTUE', 'CITRON', 'ECOLE', 'RADIO', 'LIVRES', 'CRAYON', 'POULET', 'GATEAU'].filter((w) => w.length === 6),
  7: ['FROMAGE', 'CAROTTE', 'PINGOUIN', 'TORTUES', 'VOITURE', 'CHATEAU', 'LUNETTE', 'CHAPEAU', 'ELEPHANT', 'DAUPHIN', 'PAPILLON', 'CRAYONS', 'BONBONS', 'CUISINE', 'SORCIER', 'GUITARE', 'TROMPETTE', 'BIBERON', 'CANAPE', 'FENETRE', 'PRINCESSE', 'CHAUSSON', 'BALANCE', 'POMPIER', 'MOUCHOIR'].filter((w) => w.length === 7),
  8: ['PINGOUIN', 'ELEPHANT', 'PAPILLON', 'CHOCOLAT', 'DINOSAURE', 'PARAPLUIE', 'TELEPHONE', 'CHAUSSON', 'MOUCHOIR', 'KANGOUROU', 'CROCODILE', 'TOBOGGAN', 'BOULANGER', 'ORDINATEUR', 'ESCARGOT', 'HERISSON', 'CORNICHON', 'POTIRON', 'SPAGHETTI', 'TRACTEUR', 'ARROSOIR', 'COCCINELLE', 'MANDARINE', 'PASTEQUE'].filter((w) => w.length === 8),
};

// Contraires
export const OPPOSITES = [
  ['CHAUD', 'FROID'], ['GRAND', 'PETIT'], ['JOUR', 'NUIT'], ['HAUT', 'BAS'], ['VITE', 'LENTEMENT'], ['PLEIN', 'VIDE'],
  ['OUVERT', 'FERMÉ'], ['GENTIL', 'MÉCHANT'], ['DUR', 'MOU'], ['LOURD', 'LÉGER'], ['PROPRE', 'SALE'], ['RICHE', 'PAUVRE'],
  ['JEUNE', 'VIEUX'], ['MOUILLÉ', 'SEC'], ['LONG', 'COURT'], ['GAGNER', 'PERDRE'], ['ENTRER', 'SORTIR'], ['MONTER', 'DESCENDRE'],
  ['RIRE', 'PLEURER'], ['DEVANT', 'DERRIÈRE'], ['DEDANS', 'DEHORS'], ['AVANT', 'APRÈS'], ['TOUJOURS', 'JAMAIS'], ['ALLUMER', 'ÉTEINDRE'],
  ['ACHETER', 'VENDRE'], ['DONNER', 'PRENDRE'], ['FACILE', 'DIFFICILE'], ['CONTENT', 'TRISTE'], ['CLAIR', 'FONCÉ'], ['ÉPAIS', 'MINCE'],
  ['LARGE', 'ÉTROIT'], ['PROCHE', 'LOIN'], ['DÉBUT', 'FIN'], ['VRAI', 'FAUX'], ['AMI', 'ENNEMI'], ['ARRIVER', 'PARTIR'],
  ['SOMMEIL', 'RÉVEIL'], ['DOUX', 'RUGUEUX'], ['SUCRÉ', 'SALÉ'], ['BRUYANT', 'SILENCIEUX'], ['POLI', 'IMPOLI'], ['PRÉSENT', 'ABSENT'],
  ['COURAGEUX', 'PEUREUX'], ['GROS', 'MAIGRE'], ['TÔT', 'TARD'], ['SOUVENT', 'RAREMENT'], ['SOMBRE', 'LUMINEUX'], ['NEUF', 'USÉ'],
];

// Familles de mots (l'intrus)
export const FAMILIES = [
  ['Fruits', ['POMME', 'POIRE', 'BANANE', 'CERISE', 'FRAISE', 'PRUNE', 'KIWI', 'ORANGE', 'ABRICOT']],
  ['Légumes', ['CAROTTE', 'POIREAU', 'NAVET', 'CHOU', 'RADIS', 'TOMATE', 'COURGETTE', 'HARICOT', 'ÉPINARD']],
  ['Animaux de la ferme', ['VACHE', 'COCHON', 'POULE', 'MOUTON', 'CHÈVRE', 'CANARD', 'LAPIN', 'DINDON', 'ÂNE']],
  ['Animaux sauvages', ['LION', 'TIGRE', 'GIRAFE', 'ZÈBRE', 'ÉLÉPHANT', 'SINGE', 'OURS', 'LOUP', 'RENARD']],
  ['Couleurs', ['ROUGE', 'BLEU', 'VERT', 'JAUNE', 'VIOLET', 'ORANGE', 'ROSE', 'NOIR', 'BLANC']],
  ['Vêtements', ['PULL', 'JUPE', 'PANTALON', 'CHEMISE', 'MANTEAU', 'ÉCHARPE', 'CHAUSSETTE', 'BONNET', 'ROBE']],
  ['Instruments', ['PIANO', 'GUITARE', 'VIOLON', 'TROMPETTE', 'FLÛTE', 'TAMBOUR', 'HARPE', 'ACCORDÉON', 'BATTERIE']],
  ['Sports', ['FOOT', 'TENNIS', 'RUGBY', 'JUDO', 'NATATION', 'BOXE', 'SKI', 'GOLF', 'HANDBALL']],
  ['Métiers', ['BOULANGER', 'POMPIER', 'MÉDECIN', 'FACTEUR', 'COIFFEUR', 'PILOTE', 'CUISINIER', 'JARDINIER', 'PLOMBIER']],
  ['Pays', ['FRANCE', 'ESPAGNE', 'ITALIE', 'BELGIQUE', 'CANADA', 'JAPON', 'BRÉSIL', 'MAROC', 'CHINE']],
  ['Meubles', ['TABLE', 'CHAISE', 'ARMOIRE', 'LIT', 'CANAPÉ', 'BUFFET', 'COMMODE', 'TABOURET', 'BUREAU']],
  ['Véhicules', ['VOITURE', 'CAMION', 'VÉLO', 'MOTO', 'TRAIN', 'AVION', 'BATEAU', 'BUS', 'TRACTEUR']],
  ['Jours', ['LUNDI', 'MARDI', 'MERCREDI', 'JEUDI', 'VENDREDI', 'SAMEDI', 'DIMANCHE']],
  ['Mois', ['JANVIER', 'FÉVRIER', 'MARS', 'AVRIL', 'MAI', 'JUIN', 'JUILLET', 'AOÛT', 'OCTOBRE']],
  ['Oiseaux', ['MOINEAU', 'PIGEON', 'MERLE', 'AIGLE', 'HIBOU', 'CORBEAU', 'PERROQUET', 'MOUETTE', 'CYGNE']],
];

// Mots découpés en syllabes
export const SYLLABLES = [
  ['CHA', 'PEAU'], ['MAI', 'SON'], ['GA', 'TEAU'], ['LA', 'PIN'], ['BA', 'TEAU'], ['CA', 'NARD'], ['JAR', 'DIN'], ['SO', 'LEIL'],
  ['TO', 'MATE'], ['BAL', 'LON'], ['CA', 'MION'], ['MOU', 'TON'], ['CHE', 'VAL'], ['PI', 'RATE'], ['BOU', 'GIE'], ['CRAY', 'ON'],
  ['PA', 'PIL', 'LON'], ['CHO', 'CO', 'LAT'], ['TÉ', 'LÉ', 'PHONE'], ['É', 'LÉ', 'PHANT'], ['CA', 'NA', 'PÉ'], ['PA', 'RA', 'PLUIE'],
  ['TO', 'BOG', 'GAN'], ['CA', 'ROT', 'TE'], ['BI', 'BE', 'RON'], ['PIN', 'GOU', 'IN'], ['MA', 'GI', 'CIEN'], ['PO', 'TI', 'RON'],
  ['DI', 'NO', 'SAURE'], ['CRO', 'CO', 'DILE'], ['KAN', 'GOU', 'ROU'], ['HÉ', 'LI', 'COP', 'TÈRE'], ['OR', 'DI', 'NA', 'TEUR'],
  ['CO', 'CCI', 'NEL', 'LE'], ['MAN', 'DA', 'RI', 'NE'], ['A', 'NA', 'NAS'], ['SPA', 'GHET', 'TI'], ['TROM', 'PET', 'TE'],
  ['A', 'MI', 'TI', 'É'], ['RHI', 'NO', 'CÉ', 'ROS'], ['HIP', 'PO', 'PO', 'TAME'], ['TÉ', 'LÉ', 'VI', 'SION'],
];

// Pluriels : [singulier, bon pluriel, 3 faux]
export const PLURALS = [
  ['un cheval', 'des chevaux', 'des chevals', 'des chevaus', 'des chevalx'],
  ['un journal', 'des journaux', 'des journals', 'des journeaux', 'des journalx'],
  ['un bijou', 'des bijoux', 'des bijous', 'des bijouxs', 'des bijeaux'],
  ['un chou', 'des choux', 'des chous', 'des chouxs', 'des chaux'],
  ['un genou', 'des genoux', 'des genous', 'des genouxs', 'des geneaux'],
  ['un bateau', 'des bateaux', 'des bateaus', 'des batals', 'des bateauxs'],
  ['un oiseau', 'des oiseaux', 'des oiseaus', 'des oisaux', 'des oiseals'],
  ['un jeu', 'des jeux', 'des jeus', 'des jeuxs', 'des jaux'],
  ['un feu', 'des feux', 'des feus', 'des faux', 'des feuxs'],
  ['un œil', 'des yeux', 'des œils', 'des œux', 'des yeuxs'],
  ['un ciel', 'des cieux', 'des ciels', 'des cieus', 'des ciaux'],
  ['un animal', 'des animaux', 'des animals', 'des animeaux', 'des animalx'],
  ['un hôpital', 'des hôpitaux', 'des hôpitals', 'des hôpiteaux', 'des hôpitalx'],
  ['un festival', 'des festivals', 'des festivaux', 'des festiveaux', 'des festivalx'],
  ['un carnaval', 'des carnavals', 'des carnavaux', 'des carnaveaux', 'des carnavalx'],
  ['un pneu', 'des pneus', 'des pneux', 'des pneuxs', 'des pnaux'],
  ['un clou', 'des clous', 'des cloux', 'des clouxs', 'des claux'],
  ['un trou', 'des trous', 'des troux', 'des trouxs', 'des traux'],
  ['un travail', 'des travaux', 'des travails', 'des traveaux', 'des travailx'],
  ['un vitrail', 'des vitraux', 'des vitrails', 'des vitreaux', 'des vitrailx'],
  ['un détail', 'des détails', 'des détaux', 'des déteaux', 'des détailx'],
  ['un nez', 'des nez', 'des nezs', 'des nés', 'des neaux'],
  ['une souris', 'des souris', 'des sourises', 'des sourix', 'des sourits'],
  ['un prix', 'des prix', 'des prixs', 'des pris', 'des priss'],
  ['un caillou', 'des cailloux', 'des caillous', 'des caillouxs', 'des cailleaux'],
  ['un hibou', 'des hiboux', 'des hibous', 'des hibouxs', 'des hibeaux'],
  ['un landau', 'des landaus', 'des landaux', 'des landauxs', 'des landeaux'],
  ['un bleu', 'des bleus', 'des bleux', 'des bleuxs', 'des blaux'],
  ['un cadeau', 'des cadeaux', 'des cadeaus', 'des cadals', 'des cadeauxs'],
  ['un bal', 'des bals', 'des baux', 'des beaux', 'des balx'],
];

// Accords : [phrase avec ___, bonne réponse, 3 faux]
export const AGREEMENTS = [
  ['Les fleurs sont ___.', 'belles', 'beaux', 'belle', 'bels'],
  ['Mes amies sont ___.', 'contentes', 'contents', 'contente', 'content'],
  ['Ce gâteau est ___.', 'délicieux', 'délicieuse', 'délicieuxs', 'délicieuses'],
  ['Les chats ___ du lait.', 'boivent', 'boit', 'boive', 'boivons'],
  ['Nous ___ au parc.', 'allons', 'allez', 'vont', 'va'],
  ['Vous ___ très gentils.', 'êtes', 'sont', 'est', 'sommes'],
  ['Elle a ___ un gâteau.', 'mangé', 'manger', 'mangée', 'mangez'],
  ['Ils ont ___ leurs devoirs.', 'fini', 'finit', 'finis', 'finir'],
  ['Les enfants ___ dans la cour.', 'jouent', 'joue', 'joues', 'jouons'],
  ['La voiture est ___.', 'neuve', 'neuf', 'neufs', 'neuves'],
  ['Les garçons sont ___.', 'grands', 'grand', 'grande', 'grandes'],
  ['Tu ___ du piano.', 'joues', 'joue', 'jouent', 'jouez'],
  ['Je ___ un livre.', 'lis', 'lit', 'lisent', 'lisez'],
  ['Les pommes sont ___.', 'vertes', 'verts', 'verte', 'vert'],
  ['Ma sœur est ___.', 'gentille', 'gentil', 'gentils', 'gentilles'],
  ['Hier, nous ___ au cinéma.', 'sommes allés', 'sont allés', 'avons allé', 'êtes allés'],
  ['Demain, il ___ beau.', 'fera', 'fait', 'faisait', 'ferait'],
  ['Les oiseaux ___ dans le ciel.', 'volent', 'vole', 'voles', 'volons'],
  ['Cette robe est ___.', 'blanche', 'blanc', 'blancs', 'blanches'],
  ['Les nuits sont ___.', 'longues', 'longs', 'longue', 'long'],
  ['Elles sont ___ à l’école.', 'parties', 'partis', 'partie', 'parti'],
  ['Le chien ___ dans son panier.', 'dort', 'dors', 'dorment', 'dormons'],
  ['Vous ___ trop vite !', 'mangez', 'mangé', 'manger', 'mange'],
  ['Les filles sont ___.', 'heureuses', 'heureux', 'heureuse', 'heureuxs'],
  ['Ces livres sont ___.', 'anciens', 'ancien', 'ancienne', 'anciennes'],
];

// Rimes : [mot, rime juste, 3 mots qui ne riment pas]
export const RHYMES = [
  ['GÂTEAU', 'BATEAU', 'GARAGE', 'GALOP', 'GANT'],
  ['CHAT', 'RAT', 'CHIEN', 'CHAUD', 'CHOU'],
  ['MAISON', 'POISSON', 'MAÏS', 'MAIN', 'MAMAN'],
  ['SOURIS', 'PARIS', 'SOUPE', 'SOUCI', 'SOUS'],
  ['FLEUR', 'CŒUR', 'FLÛTE', 'FLEUVE', 'FLAQUE'],
  ['LAPIN', 'SAPIN', 'LAPIDE', 'LAMPE', 'LAVE'],
  ['LUNE', 'PRUNE', 'LUNDI', 'LUTIN', 'LUXE'],
  ['NUIT', 'BRUIT', 'NUAGE', 'NOIX', 'NEZ'],
  ['TABLE', 'SABLE', 'TAPIS', 'TARTE', 'TAXI'],
  ['CRAYON', 'BALLON', 'CRAPAUD', 'CRABE', 'CRÈME'],
  ['POMME', 'GOMME', 'POULE', 'PORTE', 'POUCE'],
  ['BALLE', 'MALLE', 'BAGUE', 'BANC', 'BARBE'],
  ['ÉTOILE', 'VOILE', 'ÉTÉ', 'ÉLAN', 'ÉCOLE'],
  ['MOUTON', 'BOUTON', 'MOUCHE', 'MOULIN', 'MOUSSE'],
  ['CANARD', 'RENARD', 'CANAPÉ', 'CAMION', 'CARTE'],
  ['SOLEIL', 'ABEILLE', 'SOLDAT', 'SOUPE', 'SOFA'],
  ['TORTUE', 'RUE', 'TORCHE', 'TOMATE', 'TOUR'],
  ['NEIGE', 'MANÈGE', 'NÉON', 'NAPPE', 'NID'],
  ['GIRAFE', 'CARAFE', 'GILET', 'GITE', 'GUITARE'],
  ['PIRATE', 'TOMATE', 'PIANO', 'PILOTE', 'PIPE'],
  ['CHEMIN', 'MATIN', 'CHEMISE', 'CHÈVRE', 'CHOSE'],
  ['BOUGIE', 'PLUIE', 'BOUCHE', 'BOULE', 'BOUTEILLE'],
  ['TRAIN', 'PAIN', 'TRACE', 'TRÉSOR', 'TROMPE'],
  ['ROUTE', 'GOUTTE', 'ROUGE', 'ROBE', 'RIRE'],
  ['PORTE', 'SORTE', 'POCHE', 'POULE', 'PONT'],
];
