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
