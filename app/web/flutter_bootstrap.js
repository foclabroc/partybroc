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

  // Ce qu'il faut au minimum : WebAssembly et WebGL
  if (typeof WebAssembly !== 'object') return fail('WebAssembly n’est pas disponible.');
  try {
    const c = document.createElement('canvas');
    if (!(c.getContext('webgl2') || c.getContext('webgl'))) return fail('WebGL n’est pas disponible.');
  } catch (e) { return fail('WebGL n’est pas disponible.'); }

  const slow = setTimeout(() => fail('Le chargement prend trop de temps (plus de 30 s).'), 30000);
  window.addEventListener('flutter-first-frame', () => {
    clearTimeout(slow);
    const l = document.getElementById('pb-loading');
    if (l) l.remove();
  });

  _flutter.loader.load({
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
