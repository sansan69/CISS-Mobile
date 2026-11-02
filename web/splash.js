// Removes the HTML splash once Flutter paints its first frame.
//
// Kept as an external file (not inline) so the deployment can serve the bundle
// under a strict Content-Security-Policy without nonce or hash exceptions.
window.addEventListener('flutter-first-frame', function () {
  var loader = document.getElementById('ciss-loader');
  if (loader) loader.remove();
});
