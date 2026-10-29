# -*- coding: utf-8 -*-
"""
PartyBroc : télécharge les 192 photos réelles (Zoom mystère, Mémoire, Le juste prix).

Source : Pixabay (clé gratuite) ou, sans clé, Openverse (photos sous licence Creative Commons).
1. Clé Pixabay gratuite : crée un compte sur https://pixabay.com puis ouvre https://pixabay.com/api/docs/
   (ta clé est affichée dans la partie « Parameters », ligne « key »).
2. Lance :                       python photos_partybroc.py
   (la clé est demandée la première fois, puis gardée dans cle_pixabay.txt ; Entrée sans clé = Openverse)
3. Ouvre verification.html : toutes les photos d'un coup, avec leur nom.
4. Une photo ratée ? Prends la suivante trouvée :
                                 python photos_partybroc.py refaire chien soleil jean
   (autant de noms que tu veux, sans .jpg ; ou « animaux/chien » si besoin)
   Ou remplace toi-même le fichier dans le dossier, avec le même nom.
5. Envoie-moi photos_partybroc.zip (refait à chaque lancement).

Pixabay : utilisation gratuite, sans obligation de citer l'auteur. Openverse : licences Creative Commons,
auteurs et licences notés dans credits.csv. Pour un usage perso à la maison, les deux conviennent.
Les photos sont recadrées en carré 600×600 (centre de l'image).
"""
import csv
import io
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

ICI = os.path.dirname(os.path.abspath(__file__))
DOSSIER = os.path.join(ICI, "photos_partybroc")
ETAT = os.path.join(ICI, "photos_etat.json")
CLE = os.path.join(ICI, "cle_pixabay.txt")
TAILLE = 600

# Pillow (recadrage) : installé tout seul s'il manque
try:
    from PIL import Image
except ImportError:
    print("Installation de Pillow (recadrage des photos)…")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--quiet", "pillow"])
    from PIL import Image

# dossier, fichier (sans .jpg), nom affiché, recherche (en anglais : bien plus de résultats)
PHOTOS = [
    # ---- animaux
    ("animaux", "chien", "Chien", "dog portrait"),
    ("animaux", "chat", "Chat", "cat"),
    ("animaux", "souris", "Souris", "mouse rodent"),
    ("animaux", "lapin", "Lapin", "rabbit"),
    ("animaux", "renard", "Renard", "red fox"),
    ("animaux", "ours", "Ours", "brown bear"),
    ("animaux", "panda", "Panda", "giant panda"),
    ("animaux", "koala", "Koala", "koala"),
    ("animaux", "tigre", "Tigre", "tiger"),
    ("animaux", "lion", "Lion", "lion"),
    ("animaux", "vache", "Vache", "cow"),
    ("animaux", "cochon", "Cochon", "pig farm"),
    ("animaux", "grenouille", "Grenouille", "frog"),
    ("animaux", "singe", "Singe", "monkey"),
    ("animaux", "poule", "Poule", "hen chicken"),
    ("animaux", "pingouin", "Pingouin", "penguin"),
    ("animaux", "hibou", "Hibou", "owl"),
    ("animaux", "licorne", "Licorne", "unicorn figurine"),
    ("animaux", "abeille", "Abeille", "bee on flower"),
    ("animaux", "papillon", "Papillon", "butterfly"),
    ("animaux", "escargot", "Escargot", "snail"),
    ("animaux", "tortue", "Tortue", "turtle"),
    ("animaux", "serpent", "Serpent", "snake"),
    ("animaux", "pieuvre", "Pieuvre", "octopus"),
    ("animaux", "crabe", "Crabe", "crab"),
    ("animaux", "dauphin", "Dauphin", "dolphin"),
    ("animaux", "baleine", "Baleine", "whale"),
    ("animaux", "requin", "Requin", "shark"),
    ("animaux", "elephant", "Éléphant", "elephant"),
    ("animaux", "girafe", "Girafe", "giraffe"),
    ("animaux", "zebre", "Zèbre", "zebra"),
    ("animaux", "kangourou", "Kangourou", "kangaroo"),
    ("animaux", "chameau", "Chameau", "camel"),
    ("animaux", "herisson", "Hérisson", "hedgehog"),
    ("animaux", "flamant-rose", "Flamant rose", "flamingo"),
    ("animaux", "perroquet", "Perroquet", "parrot macaw"),
    # ---- nourriture
    ("nourriture", "pomme", "Pomme", "red apple"),
    ("nourriture", "banane", "Banane", "banana"),
    ("nourriture", "raisin", "Raisin", "grapes"),
    ("nourriture", "fraise", "Fraise", "strawberries fruit"),
    ("nourriture", "pasteque", "Pastèque", "watermelon"),
    ("nourriture", "ananas", "Ananas", "pineapple"),
    ("nourriture", "kiwi", "Kiwi", "kiwi fruit sliced"),
    ("nourriture", "cerises", "Cerises", "red cherries fruit"),
    ("nourriture", "citron", "Citron", "lemon"),
    ("nourriture", "carotte", "Carotte", "carrots vegetable"),
    ("nourriture", "mais", "Maïs", "corn on the cob yellow"),
    ("nourriture", "brocoli", "Brocoli", "broccoli vegetable"),
    ("nourriture", "champignon", "Champignon", "mushroom"),
    ("nourriture", "croissant", "Croissant", "croissant"),
    ("nourriture", "baguette", "Baguette", "french baguette bread"),
    ("nourriture", "fromage", "Fromage", "cheese wheel"),
    ("nourriture", "pizza", "Pizza", "pizza"),
    ("nourriture", "hamburger", "Hamburger", "hamburger"),
    ("nourriture", "frites", "Frites", "french fries"),
    ("nourriture", "hot-dog", "Hot-dog", "hot dog sausage bun"),
    ("nourriture", "oeuf", "Œuf", "egg"),
    ("nourriture", "donut", "Donut", "donut glazed"),
    ("nourriture", "cookie", "Cookie", "chocolate chip cookie"),
    ("nourriture", "gateau-d-anniversaire", "Gâteau d’anniversaire", "birthday cake"),
    ("nourriture", "glace", "Glace", "ice cream cone"),
    ("nourriture", "chocolat", "Chocolat", "chocolate bar"),
    ("nourriture", "pop-corn", "Pop-corn", "popcorn"),
    ("nourriture", "bretzel", "Bretzel", "pretzel"),
    ("nourriture", "sushi", "Sushi", "sushi"),
    ("nourriture", "noix-de-coco", "Noix de coco", "coconut"),
    # ---- objets
    ("objets", "ballon-de-foot", "Ballon de foot", "soccer ball"),
    ("objets", "ballon-de-basket", "Ballon de basket", "basketball ball"),
    ("objets", "guitare", "Guitare", "acoustic guitar"),
    ("objets", "trompette", "Trompette", "trumpet instrument"),
    ("objets", "tambour", "Tambour", "drum"),
    ("objets", "piano", "Piano", "piano keys"),
    ("objets", "telephone", "Téléphone", "smartphone"),
    ("objets", "ordinateur-portable", "Ordinateur portable", "laptop computer"),
    ("objets", "montre", "Montre", "wrist watch"),
    ("objets", "appareil-photo", "Appareil photo", "camera"),
    ("objets", "cle", "Clé", "key"),
    ("objets", "marteau", "Marteau", "hammer"),
    ("objets", "ciseaux", "Ciseaux", "scissors isolated"),
    ("objets", "livres", "Livres", "stack of books"),
    ("objets", "crayon", "Crayon", "pencil"),
    ("objets", "ballon-de-baudruche", "Ballon de baudruche", "balloon"),
    ("objets", "cadeau", "Cadeau", "gift box ribbon"),
    ("objets", "bougie", "Bougie", "candle"),
    ("objets", "ampoule", "Ampoule", "light bulb"),
    ("objets", "lampe-de-poche", "Lampe de poche", "flashlight torch"),
    ("objets", "parapluie", "Parapluie", "umbrella rain"),
    ("objets", "lunettes", "Lunettes", "glasses spectacles isolated"),
    ("objets", "couronne", "Couronne", "crown"),
    ("objets", "chapeau-haut-de-forme", "Chapeau haut-de-forme", "top hat"),
    ("objets", "basket", "Basket", "sneaker shoe"),
    ("objets", "chaussettes", "Chaussettes", "colorful socks"),
    ("objets", "chaise", "Chaise", "chair"),
    ("objets", "baignoire", "Baignoire", "bathtub bathroom"),
    ("objets", "reveil", "Réveil", "alarm clock"),
    ("objets", "ours-en-peluche", "Ours en peluche", "teddy bear"),
    # ---- nature
    ("nature", "cactus", "Cactus", "cactus"),
    ("nature", "sapin", "Sapin", "fir tree snow"),
    ("nature", "palmier", "Palmier", "palm tree beach"),
    ("nature", "tournesol", "Tournesol", "sunflower"),
    ("nature", "rose", "Rose", "red rose flower"),
    ("nature", "trefle-a-quatre-feuilles", "Trèfle à quatre feuilles", "four leaf clover lucky"),
    ("nature", "feuille-d-erable", "Feuille d’érable", "maple leaf"),
    ("nature", "arc-en-ciel", "Arc-en-ciel", "rainbow sky"),
    ("nature", "bonhomme-de-neige", "Bonhomme de neige", "snowman"),
    ("nature", "volcan", "Volcan", "volcano"),
    ("nature", "lune", "Lune", "full moon"),
    ("nature", "etoile", "Étoile", "star decoration gold"),
    ("nature", "soleil", "Soleil", "sun sky"),
    ("nature", "eclair", "Éclair", "lightning"),
    ("nature", "feu", "Feu", "campfire flames"),
    ("nature", "goutte-d-eau", "Goutte d’eau", "water drop"),
    ("nature", "vague", "Vague", "ocean wave"),
    ("nature", "flocon-de-neige", "Flocon de neige", "snowflake"),
    # ---- transports
    ("transports", "voiture", "Voiture", "car"),
    ("transports", "taxi", "Taxi", "taxi cab"),
    ("transports", "bus", "Bus", "bus vehicle"),
    ("transports", "voiture-de-police", "Voiture de police", "police car"),
    ("transports", "ambulance", "Ambulance", "ambulance"),
    ("transports", "camion-de-pompiers", "Camion de pompiers", "fire truck"),
    ("transports", "tracteur", "Tracteur", "tractor"),
    ("transports", "velo", "Vélo", "bicycle"),
    ("transports", "scooter", "Scooter", "scooter vespa"),
    ("transports", "locomotive", "Locomotive", "locomotive train"),
    ("transports", "helicoptere", "Hélicoptère", "helicopter"),
    ("transports", "avion", "Avion", "airplane flying sky"),
    ("transports", "fusee", "Fusée", "rocket launch"),
    ("transports", "voilier", "Voilier", "sailing boat"),
    ("transports", "paquebot", "Paquebot", "cruise ship"),
    ("transports", "soucoupe-volante", "Soucoupe volante", "ufo flying saucer"),
    ("transports", "wagon", "Wagon", "railway freight wagon"),
    ("transports", "trottinette", "Trottinette", "kick scooter child"),
    # ---- Le juste prix (de préférence le produit seul, sans prix visible)
    ("justeprix", "baguette-de-pain", "Une baguette de pain", "baguette bread bakery"),
    ("justeprix", "croissant-au-beurre", "Un croissant au beurre", "butter croissant"),
    ("justeprix", "sandwich-jambon-beurre", "Un sandwich jambon-beurre", "ham baguette sandwich"),
    ("justeprix", "part-de-tarte-aux-fraises", "Une part de tarte aux fraises", "strawberry tart slice"),
    ("justeprix", "boite-de-6-oeufs", "Une boîte de 6 œufs", "egg carton"),
    ("justeprix", "bouteille-de-lait-demi-ecreme", "Une bouteille de lait", "milk bottle"),
    ("justeprix", "plaquette-de-beurre", "Une plaquette de beurre", "butter"),
    ("justeprix", "tablette-de-chocolat-noir", "Une tablette de chocolat noir", "dark chocolate"),
    ("justeprix", "paquet-de-spaghettis", "Un paquet de spaghettis", "dry spaghetti pasta"),
    ("justeprix", "expresso", "Un expresso", "espresso coffee cup"),
    ("justeprix", "paquet-de-cafe-moulu", "Un paquet de café moulu", "ground coffee bag"),
    ("justeprix", "kilo-de-bananes", "Un kilo de bananes", "bunch of bananas"),
    ("justeprix", "kilo-de-pommes", "Un kilo de pommes", "red apples"),
    ("justeprix", "camembert", "Un camembert", "camembert cheese"),
    ("justeprix", "pizza-surgelee", "Une pizza surgelée", "frozen pizza"),
    ("justeprix", "menu-burger-frites-boisson", "Un menu burger + frites + boisson", "burger and fries"),
    ("justeprix", "canette-de-soda", "Une canette de soda", "soda can"),
    ("justeprix", "pack-de-6-bouteilles-d-eau", "Un pack de 6 bouteilles d’eau", "plastic water bottles"),
    ("justeprix", "bouteille-de-vin-rouge-de-table", "Une bouteille de vin rouge", "wine bottle"),
    ("justeprix", "bouteille-de-champagne", "Une bouteille de champagne", "champagne"),
    ("justeprix", "sachet-de-bonbons", "Un sachet de bonbons", "gummy candies"),
    ("justeprix", "deux-boules-de-glace-en-cornet", "Deux boules de glace en cornet", "two scoop ice cream cone"),
    ("justeprix", "pot-de-miel", "Un pot de miel", "honey jar"),
    ("justeprix", "boite-de-petits-pois", "Une boîte de petits pois", "green peas"),
    ("justeprix", "barquette-de-12-sushis", "Une barquette de 12 sushis", "sushi box"),
    ("justeprix", "stylo-bille-bleu", "Un stylo bille bleu", "blue ballpoint pen"),
    ("justeprix", "grand-cahier", "Un grand cahier", "notebook"),
    ("justeprix", "ramette-de-papier", "Une ramette de papier", "stack of printer paper"),
    ("justeprix", "paquet-de-12-rouleaux-de-papier-toilette", "Un paquet de papier toilette", "toilet paper rolls"),
    ("justeprix", "brosse-a-dents", "Une brosse à dents", "toothbrush"),
    ("justeprix", "tube-de-dentifrice", "Un tube de dentifrice", "toothpaste tube"),
    ("justeprix", "ampoule-led", "Une ampoule LED", "light bulb"),
    ("justeprix", "lot-de-4-piles-aa", "Un lot de 4 piles AA", "aa batteries"),
    ("justeprix", "parapluie-pliant", "Un parapluie pliant", "umbrella isolated"),
    ("justeprix", "paire-de-chaussettes", "Une paire de chaussettes", "pair of socks"),
    ("justeprix", "t-shirt-blanc", "Un t-shirt blanc", "white t-shirt"),
    ("justeprix", "jean", "Un jean", "blue jeans"),
    ("justeprix", "paire-de-baskets-de-marque", "Une paire de baskets de marque", "sneakers pair"),
    ("justeprix", "ballon-de-foot", "Un ballon de foot", "football ball grass"),
    ("justeprix", "jeu-de-54-cartes", "Un jeu de 54 cartes", "playing cards deck"),
    ("justeprix", "ours-en-peluche", "Un ours en peluche", "plush teddy bear"),
    ("justeprix", "velo-de-ville-neuf", "Un vélo de ville neuf", "bicycle"),
    ("justeprix", "trottinette-electrique", "Une trottinette électrique", "electric kick scooter"),
    ("justeprix", "smartphone-haut-de-gamme", "Un smartphone haut de gamme", "smartphone isolated"),
    ("justeprix", "console-de-jeux-de-salon", "Une console de jeux", "game console controller"),
    ("justeprix", "television-55-pouces-4k", "Une télévision 55 pouces", "flat screen tv living room"),
    ("justeprix", "casque-audio-sans-fil", "Un casque audio sans fil", "headphones"),
    ("justeprix", "place-de-cinema", "Une place de cinéma", "cinema ticket"),
    ("justeprix", "ticket-de-metro-a-paris", "Un ticket de métro à Paris", "paris metro"),
    ("justeprix", "litre-d-essence-sans-plomb-95", "Un litre d’essence", "gas station pump"),
    ("justeprix", "coupe-homme-chez-le-coiffeur", "Une coupe homme chez le coiffeur", "barber haircut"),
    ("justeprix", "bouquet-de-12-roses-rouges", "Un bouquet de 12 roses rouges", "bouquet red roses"),
    ("justeprix", "sac-de-croquettes-pour-chien", "Un sac de croquettes pour chien", "dog food kibble"),
    ("justeprix", "gateau-d-anniversaire-pour-8", "Un gâteau d’anniversaire pour 8", "cake"),
    ("justeprix", "menu-entree-plat-dessert", "Un menu entrée-plat-dessert", "plate dinner restaurant"),
    ("justeprix", "valise-cabine", "Une valise cabine", "carry on suitcase"),
    ("justeprix", "paire-de-lunettes-de-soleil", "Une paire de lunettes de soleil", "sunglasses isolated"),
    ("justeprix", "plante-verte-en-pot", "Une plante verte en pot", "potted plant"),
    ("justeprix", "lot-de-3-eponges", "Un lot de 3 éponges", "kitchen sponges"),
    ("justeprix", "sachet-de-20-ballons-de-baudruche", "Un sachet de ballons de baudruche", "balloons"),
]


def cle_api():
    """Clé Pixabay, ou '' pour Openverse (sans clé)."""
    if os.environ.get("PIXABAY_KEY"):
        return os.environ["PIXABAY_KEY"].strip()
    if os.path.exists(CLE):
        return open(CLE, encoding="utf-8").read().strip()
    print("Clé Pixabay gratuite : compte sur https://pixabay.com puis https://pixabay.com/api/docs/ (ligne « key »).")
    k = input("Colle ta clé Pixabay puis Entrée (ou juste Entrée pour Openverse, sans clé) : ").strip()
    open(CLE, "w", encoding="utf-8").write(k)
    return k


def lire_etat():
    if os.path.exists(ETAT):
        return json.load(open(ETAT, encoding="utf-8"))
    return {}


def ecrire_etat(etat):
    json.dump(etat, open(ETAT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


def http(url):
    req = urllib.request.Request(url, headers={"User-Agent": "PartyBroc/1.0 (jeu de soiree perso)"})
    for essai in range(4):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code == 429:  # trop de demandes d'un coup
                print("  Le site demande de patienter, pause d'une minute…")
                time.sleep(60)
                continue
            if e.code in (400, 401, 403) and "pixabay.com/api" in url:
                sys.exit("Clé Pixabay refusée : vérifie cle_pixabay.txt (ou supprime-le pour la retaper).")
            raise
        except (urllib.error.URLError, TimeoutError):
            time.sleep(3)
    raise RuntimeError("le réseau ne répond pas")


def chercher(query, cle):
    """Jusqu'à 15 photos pour cette recherche (gardées dans photos_etat.json : pas besoin de rechercher à nouveau)."""
    if cle:  # Pixabay
        url = "https://pixabay.com/api/?" + urllib.parse.urlencode(
            {"key": cle, "q": query, "image_type": "photo", "safesearch": "true", "per_page": 20, "order": "popular"})
        data = json.loads(http(url))
        return [{"url": h.get("largeImageURL") or h["webformatURL"], "mini": h.get("webformatURL", ""), "auteur": h.get("user", ""),
                 "page": h.get("pageURL", ""), "licence": "Pixabay"} for h in data.get("hits", [])]
    # Openverse (sans clé) : photos Creative Commons
    url = "https://api.openverse.org/v1/images/?" + urllib.parse.urlencode(
        {"q": query, "page_size": 15, "category": "photograph", "mature": "false"})
    data = json.loads(http(url))
    return [{"url": r["url"], "auteur": r.get("creator") or "", "page": r.get("foreign_landing_url") or "",
             "licence": f"CC {r.get('license', '').upper()} {r.get('license_version') or ''}".strip()} for r in data.get("results", [])]


def enregistrer(octets, chemin):
    im = Image.open(io.BytesIO(octets))
    if im.mode in ("RGBA", "LA", "P"):  # PNG transparent : sur fond blanc (sinon des rayures apparaissent)
        im = im.convert("RGBA")
        fond = Image.new("RGBA", im.size, (255, 255, 255, 255))
        im = Image.alpha_composite(fond, im)
    im = im.convert("RGB")
    c = min(im.size)
    g, h = (im.width - c) // 2, (im.height - c) // 2
    im = im.crop((g, h, g + c, h + c)).resize((TAILLE, TAILLE), Image.LANCZOS)
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    im.save(chemin, "JPEG", quality=85, optimize=True)


def page_verification(etat):
    blocs = []
    dossier_courant = None
    for dossier, fichier, nom, _ in PHOTOS:
        if dossier != dossier_courant:
            if dossier_courant:
                blocs.append("</div>")
            blocs.append(f"<h2>{dossier}</h2><div class='grille'>")
            dossier_courant = dossier
        cle = f"{dossier}/{fichier}"
        e = etat.get(cle, {})
        rel = f"photos_partybroc/{dossier}/{fichier}.jpg"
        ok = os.path.exists(os.path.join(ICI, rel))
        img = f"<img src='{rel}?v={e.get('i', 0)}'>" if ok else "<div class='vide'>pas de photo</div>"
        blocs.append(f"<figure>{img}<figcaption><b>{nom}</b><br><code>{fichier}</code> · photo n°{e.get('i', 0) + 1}</figcaption></figure>")
    blocs.append("</div>")
    html = f"""<!doctype html><meta charset="utf-8"><title>PartyBroc : vérification des photos</title>
<style>
body{{font-family:system-ui,sans-serif;background:#17102B;color:#F7F2FF;margin:20px}}
h1{{margin:0 0 6px}} p{{color:#B3A6D9}} code{{color:#3FE0FF}}
h2{{margin:28px 0 10px;color:#FFD23F;text-transform:capitalize}}
.grille{{display:grid;grid-template-columns:repeat(auto-fill,minmax(170px,1fr));gap:12px}}
figure{{margin:0;background:#2E2257;border-radius:12px;overflow:hidden}}
img,.vide{{width:100%;aspect-ratio:1;object-fit:cover;display:block}}
.vide{{display:flex;align-items:center;justify-content:center;background:#5a1d2c}}
figcaption{{padding:6px 8px;font-size:13px}}
</style>
<h1>PartyBroc : les {len(PHOTOS)} photos</h1>
<p>Une photo ne va pas ? Dans le dossier du script : <code>python photos_partybroc.py refaire chien soleil</code> (la photo suivante trouvée),
ou remplace le fichier toi-même avec le même nom. Puis recharge cette page.</p>
{''.join(blocs)}"""
    open(os.path.join(ICI, "verification.html"), "w", encoding="utf-8").write(html)


def faire_zip():
    chemin = os.path.join(ICI, "photos_partybroc.zip")
    with zipfile.ZipFile(chemin, "w", zipfile.ZIP_DEFLATED) as z:
        for racine, _, fichiers in os.walk(DOSSIER):
            for f in fichiers:
                p = os.path.join(racine, f)
                z.write(p, os.path.relpath(p, DOSSIER))
        if os.path.exists(os.path.join(ICI, "credits.csv")):
            z.write(os.path.join(ICI, "credits.csv"), "credits.csv")
    return chemin


def main():
    args = sys.argv[1:]
    refaire = set()
    if args and args[0] == "refaire":
        for a in args[1:]:
            a = a.replace(".jpg", "").replace("\\", "/")
            trouves = [f"{d}/{f}" for d, f, _, _ in PHOTOS if a in (f, f"{d}/{f}")]
            if not trouves:
                print(f"« {a} » n'est pas dans la liste (regarde le nom sous la photo dans verification.html).")
            refaire.update(trouves)
        if not refaire:
            return

    cle = cle_api()
    etat = lire_etat()
    faits = rates = 0
    for n, (dossier, fichier, nom, query) in enumerate(PHOTOS, 1):
        k = f"{dossier}/{fichier}"
        chemin = os.path.join(DOSSIER, dossier, fichier + ".jpg")
        e = etat.setdefault(k, {"i": 0})
        if k in refaire:
            e["i"] = e.get("i", 0) + 1
        elif os.path.exists(chemin):
            continue
        try:
            source = "pixabay" if cle else "openverse"
            if "res" not in e or e.get("q") != query or e.get("src") != source:
                e["res"], e["q"], e["src"] = chercher(query, cle), query, source
                time.sleep(0.8 if cle else 3.5)  # Openverse sans clé : on y va doucement
            if not e["res"]:
                print(f"[{n}/{len(PHOTOS)}] {nom} : aucune photo trouvée pour « {query} »")
                rates += 1
                continue
            if e["i"] >= len(e["res"]):
                e["i"] = 0
                print(f"  {nom} : plus d'autres photos, on revient à la première")
            choix = e["res"][e["i"]]
            try:
                octets = http(choix["url"])
            except Exception:
                # Lien mort (fréquent sur Openverse) : on essaie les suivantes
                octets = None
                for j in range(e["i"] + 1, len(e["res"])):
                    try:
                        octets = http(e["res"][j]["url"])
                        e["i"], choix = j, e["res"][j]
                        break
                    except Exception:
                        continue
                if octets is None:
                    raise
            enregistrer(octets, chemin)
            e["auteur"], e["page"], e["licence"] = choix["auteur"], choix["page"], choix.get("licence", "")
            faits += 1
            print(f"[{n}/{len(PHOTOS)}] {nom} : photo n°{e['i'] + 1}")
        except Exception as ex:  # on continue avec les autres
            print(f"[{n}/{len(PHOTOS)}] {nom} : erreur ({ex})")
            rates += 1
        ecrire_etat(etat)

    with open(os.path.join(ICI, "credits.csv"), "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["fichier", "auteur", "licence", "page d'origine"])
        for dossier, fichier, _, _ in PHOTOS:
            e = etat.get(f"{dossier}/{fichier}", {})
            w.writerow([f"{dossier}/{fichier}.jpg", e.get("auteur", ""), e.get("licence", ""), e.get("page", "")])
    page_verification(etat)
    z = faire_zip()
    total = sum(1 for d, f, _, _ in PHOTOS if os.path.exists(os.path.join(DOSSIER, d, f + ".jpg")))
    print(f"\n{faits} photo(s) téléchargée(s), {rates} problème(s). {total}/{len(PHOTOS)} photos en tout.")
    print("Vérifie : verification.html   ·   À m'envoyer : " + os.path.basename(z))
    if os.name == "nt":
        os.startfile(os.path.join(ICI, "verification.html"))


if __name__ == "__main__":
    main()
