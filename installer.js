const cfg = window.MUMIN_INSTALLER_CONFIG;
const button = document.getElementById('downloadButton');
function boot() {
 if (!cfg || !cfg.apkUrl) { button.textContent = 'DOSYA HAZIR DEGIL'; button.removeAttribute('href'); return; }
 button.href = cfg.apkUrl;
 button.setAttribute('download', cfg.downloadName || 'Mumin-Duasi.apk');
}
window.addEventListener('load', boot);
