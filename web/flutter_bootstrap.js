{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  onEntrypointLoaded: async function(engineInitializer) {
    let appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    const loading = document.getElementById('loading');
    if (loading) {
      loading.style.transition = 'opacity 0.3s';
      loading.style.opacity = '0';
      setTimeout(() => loading.remove(), 300);
    }
  }
});
