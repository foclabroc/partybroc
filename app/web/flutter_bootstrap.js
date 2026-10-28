{{flutter_js}}
{{flutter_build_config}}

// Démarrage de PartyBroc : CanvasKit est servi par notre serveur (pas de CDN),
// pas de service worker (il garde parfois une vieille version en cache).
(function () {
  const status = document.getElementById('pb-status');
  const show = (html) => { if (status) { status.innerHTML = html; status.style.display = 'block'; } };
  const fail = (why) => show(
    '<b>PartyBroc n’arrive pas à démarrer sur ce navigateur.</b><br>' + why +
    '<br><br><small>' + navigator.userAgent + '</small>');

  // Indispensable : WebAssembly
  if (typeof WebAssembly !== 'object') return fail('WebAssembly n’est pas disponible.');

  // WebGL : souvent coupé sur les navigateurs de TV. Sans lui, on dessine
  // en mode logiciel (CanvasKit sur le processeur) : plus lent mais ça marche.
  let webgl = false;
  try {
    const c = document.createElement('canvas');
    webgl = !!(c.getContext('webgl2') || c.getContext('webgl'));
  } catch (e) { webgl = false; }
  // Mode de dessin forcé par l'adresse (?rendu=cpu|gl|auto), retenu par ce navigateur :
  //   auto : WebAssembly + WebGL (le plus rapide), logiciel si pas de WebGL
  //   gl   : version JavaScript + WebGL (pour les WebGL capricieux)
  //   cpu  : version JavaScript, dessin logiciel sans WebGL (le plus sûr)
  const store = { get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
                  set(k, v) { try { localStorage.setItem(k, v); } catch (e) {} } };
  const asked = new URLSearchParams(location.search).get('rendu');
  if (asked === 'cpu' || asked === 'gl' || asked === 'auto') store.set('pb_rendu', asked);
  let mode = store.get('pb_rendu') || 'auto';
  // Téléphones : WebGL dans la page (« gl ») plutôt que WebAssembly + dessin dans un
  // worker. Quand Android met le navigateur de côté (choix d'une photo…), le dessin
  // du worker peut être perdu sans retour : écran violet. En « gl », la perte est
  // visible (et Flutter sait la réparer).
  const isPhone = location.pathname.replace(/\/+$/, '') === '/play';
  if (mode === 'auto' && isPhone) mode = 'gl';
  if (mode === 'auto' && !webgl) mode = 'cpu';
  const config = mode === 'cpu' ? { renderer: 'canvaskit', canvasKitForceCpuOnly: true }
               : mode === 'gl'  ? { renderer: 'canvaskit' }
               : {};
  console.info('PartyBroc : rendu ' + mode + (webgl ? '' : ' (pas de WebGL)'));

  // ?debug=1 : affiche les infos techniques en bas de l'écran
  if (new URLSearchParams(location.search).get('debug') === '1') {
    const d = document.createElement('div');
    d.style.cssText = 'position:fixed;left:8px;bottom:8px;z-index:99999;font:14px monospace;color:#fff;background:rgba(0,0,0,.7);padding:6px 10px;border-radius:6px;max-width:95vw';
    d.textContent = 'rendu=' + mode + ' webgl=' + webgl + ' | ' + navigator.userAgent;
    document.body.appendChild(d);
  }

  const slow = setTimeout(() => fail('Le chargement prend trop de temps (plus de 30 s).'), 30000);
  window.addEventListener('flutter-first-frame', () => {
    clearTimeout(slow);
    const l = document.getElementById('pb-loading');
    if (l) l.remove();
  });

  // Filet de sécurité sur le téléphone : au retour sur la page après un passage en
  // arrière-plan (choix d'une photo, veille…), un petit bouton HTML « Recharger »
  // s'affiche quelques secondes. Il reste visible même si le dessin de l'appli est
  // perdu (écran violet). Recharger ne fait rien perdre : le joueur retrouve sa
  // place grâce à son jeton, pseudo et photo sont déjà enregistrés.
  let hiddenAt = 0;
  let tip = null;
  const showTip = () => {
    if (tip) tip.remove();
    tip = document.createElement('button');
    tip.textContent = '↻ Écran vide ? Recharger';
    tip.style.cssText = 'position:fixed;top:10px;right:10px;z-index:99999;font:600 15px sans-serif;' +
      'color:#fff;background:#FF4FA3;border:0;border-radius:20px;padding:10px 16px;box-shadow:0 4px 16px rgba(0,0,0,.4)';
    tip.onclick = () => location.reload();
    document.body.appendChild(tip);
    const t = tip;
    setTimeout(() => { if (tip === t) { t.remove(); tip = null; } }, 7000);
  };
  const back = () => {
    if (!isPhone || document.visibilityState !== 'visible' || !hiddenAt) return;
    if (Date.now() - hiddenAt > 1500) showTip();
    hiddenAt = 0;
  };
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') hiddenAt = Date.now(); else back();
  });
  window.addEventListener('blur', () => { if (!hiddenAt) hiddenAt = Date.now(); });
  window.addEventListener('focus', back);
  window.addEventListener('pageshow', (e) => { if (e.persisted) { hiddenAt = Date.now() - 2000; back(); } });

  // ---- Téléphone : plein écran, écran toujours allumé, icône sur l'écran d'accueil ----
  // Lancé depuis l'icône de l'écran d'accueil : déjà sans barre du navigateur
  const installed = matchMedia('(display-mode: fullscreen)').matches || matchMedia('(display-mode: standalone)').matches
    || navigator.standalone === true;
  const isIos = /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  if (isPhone) {
    // Plein écran au premier appui (le navigateur l'exige après un geste) ; s'il en sort
    // (geste Retour…), on y revient à l'appui suivant. Pas sur iPhone (Safari refuse).
    const el = document.documentElement;
    const goFull = () => {
      if (installed || document.fullscreenElement || !el.requestFullscreen) return;
      el.requestFullscreen({ navigationUI: 'hide' }).catch(() => {});
    };
    document.addEventListener('pointerup', goFull, true);
    // Écran qui ne s'éteint pas pendant qu'on joue (repris au retour sur la page)
    let lock = null;
    const wake = async () => {
      if (!('wakeLock' in navigator) || document.visibilityState !== 'visible' || lock) return;
      try {
        lock = await navigator.wakeLock.request('screen');
        lock.addEventListener('release', () => { lock = null; });
      } catch (e) { lock = null; }
    };
    document.addEventListener('pointerup', wake, true);
    document.addEventListener('visibilitychange', wake);
    wake();
  }
  // Ajouter à l'écran d'accueil : Android propose une vraie installation (on garde la
  // demande pour le bouton de l'appli) ; iPhone : il faut passer par le menu Partager.
  let installAsk = null;
  window.addEventListener('beforeinstallprompt', (e) => { e.preventDefault(); installAsk = e; });
  window.addEventListener('appinstalled', () => { installAsk = null; });
  window.pbInstallKind = () => (installed ? 'done' : installAsk ? 'prompt' : isIos ? 'ios' : 'none');
  window.pbInstall = async () => {
    if (!installAsk) return false;
    const e = installAsk;
    installAsk = null;
    e.prompt();
    const r = await e.userChoice;
    return r && r.outcome === 'accepted';
  };

  _flutter.loader.load({
    config: config,
    onEntrypointLoaded: async function (engineInitializer) {
      try {
        const app = await engineInitializer.initializeEngine();
        await app.runApp();
      } catch (e) {
        clearTimeout(slow);
        fail('Erreur au démarrage : ' + (e && e.message ? e.message : e));
      }
    },
  }).catch(function (e) {
    clearTimeout(slow);
    fail('Erreur au chargement : ' + (e && e.message ? e.message : e));
  });
})();
