import 'bi_constants.dart';
import 'bi_model.dart';

/// Règles de dates, durées et numérotation — portées depuis
/// re.ogec.bi/util/BiFormat.kt. Centralisées ici, jamais dupliquées
/// dans les écrans.
class BiFormat {
  static String _deuxChiffres(int n) => n.toString().padLeft(2, '0');

  static String today() {
    final d = DateTime.now();
    return '${_deuxChiffres(d.day)}/${_deuxChiffres(d.month)}/${d.year}';
  }

  static String now() {
    final d = DateTime.now();
    return '${today()} ${_deuxChiffres(d.hour)}:${_deuxChiffres(d.minute)}';
  }

  static int currentYear() => DateTime.now().year;

  /// "BI-`pôle`-`année`-`chrono sur 6 chiffres`".
  static String numeroBI(String pole, int annee, int chrono) =>
      'BI-$pole-$annee-${chrono.toString().padLeft(6, '0')}';

  /// Durée "Xh" ou "XhYY" entre deux horaires "HH:mm" — vide si l'une
  /// des deux heures manque.
  static String dureeEntre(String heureDebut, String heureFin) {
    if (heureDebut.isEmpty || heureFin.isEmpty) return '';
    final debut = _parseHeure(heureDebut);
    final fin = _parseHeure(heureFin);
    if (debut == null || fin == null) return '';
    var minutes = fin - debut;
    if (minutes < 0) minutes += 24 * 60;
    return _formaterDuree(minutes);
  }

  static int? _parseHeure(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  static String _formaterDuree(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h${_deuxChiffres(m)}';
  }

  /// Journée type OGEC : 7h30 du lundi au jeudi, 5h le vendredi — vide
  /// le week-end (saisie manuelle requise) et toujours vide au SAV, qui
  /// enchaîne plusieurs interventions dans la même journée (géré par
  /// l'appelant, pas ici).
  static String tempsStandard(String dateFrJJMMAAAA) {
    final d = _parseDateFr(dateFrJJMMAAAA);
    if (d == null) return '';
    switch (d.weekday) {
      case DateTime.monday:
      case DateTime.tuesday:
      case DateTime.wednesday:
      case DateTime.thursday:
        return '7h30';
      case DateTime.friday:
        return '5h';
      default:
        return '';
    }
  }

  static DateTime? _parseDateFr(String jjMmAaaa) {
    final parts = jjMmAaaa.split('/');
    if (parts.length != 3) return null;
    final j = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final a = int.tryParse(parts[2]);
    if (j == null || m == null || a == null) return null;
    return DateTime(a, m, j);
  }

  /// Résumé "désignation ×quantité" des prestations, pour l'historique
  /// des corrections bureau.
  static String prestaSummary(List<Presta> prestas) {
    return prestas
        .where((p) => p.designation.trim().isNotEmpty)
        .map((p) => '${p.designation} ×${p.quantite}')
        .join(', ');
  }

  /// Prix unitaire HT saisi par le bureau — jamais par le technicien.
  static double? parsePu(String v) => double.tryParse(v.trim().replaceAll(',', '.'));

  static double? montantLigne(Presta p) {
    final pu = parsePu(p.pu);
    if (pu == null) return null;
    final n = double.tryParse(p.quantite.trim().replaceAll(',', '.'));
    if (n == null) return null;
    return pu * n;
  }

  static String eur(double v) => '${v.toStringAsFixed(2)} €';

  static double totalHT(List<Presta> prestas) => prestas.fold(
    0,
    (total, p) => total + (montantLigne(p) ?? 0),
  );
}

/// Libellé "PP - Libellé" du dossier Drive d'un pôle (ex "20 - Maintenance") —
/// utilisé plus tard pour l'archivage (Phase 4), gardé ici pour rester
/// avec les autres formats.
String driveFolderNamePole(String code) => '$code - ${Poles.label(code)}';
