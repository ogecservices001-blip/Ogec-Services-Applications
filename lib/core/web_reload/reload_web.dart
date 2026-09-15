import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Recharge la page en forçant la récupération de la dernière version
/// déployée — un simple `location.reload()` ne suffit pas : le service
/// worker de Flutter web intercepte les requêtes réseau et continue de
/// servir son propre cache même après un F5 (vu en pratique : le
/// bandeau anti-cache s'affichait correctement mais "Recharger" ne
/// changeait rien tant que l'onglet n'était pas fermé et rouvert, ou le
/// site ouvert en navigation privée). On désenregistre les service
/// workers et on vide le cache avant de recharger pour garantir un
/// chargement réseau complet.
Future<void> rechargerPage() async {
  try {
    final regs = (await web.window.navigator.serviceWorker.getRegistrations().toDart).toDart;
    for (final reg in regs) {
      await reg.unregister().toDart;
    }
  } catch (_) {
    // Pas de service worker actif, ou API indisponible : tant pis, on
    // recharge quand même ci-dessous.
  }
  try {
    final noms = (await web.window.caches.keys().toDart).toDart;
    for (final nom in noms) {
      await web.window.caches.delete(nom.toDart).toDart;
    }
  } catch (_) {
    // Idem.
  }
  web.window.location.reload();
}
