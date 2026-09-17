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

  /// "BI-`pôle`-`année`-`chrono sur 4 chiffres`" — 2 à 3 000 bons max par
  /// an, pas besoin de plus.
  static String numeroBI(String pole, int annee, int chrono) =>
      'BI-$pole-$annee-${chrono.toString().padLeft(4, '0')}';

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

  /// Accepte "Xh", "XhYY" ou un nombre d'heures simple ("3", "3.5",
  /// "3,5") — le technicien tape rarement le "h" au SAV.
  static int? _parseDuree(String duree) {
    final s = duree.trim();
    if (s.isEmpty) return null;
    final matchH = RegExp(r'^(\d+)h(\d{1,2})?$').firstMatch(s);
    if (matchH != null) {
      final h = int.parse(matchH.group(1)!);
      final m = int.tryParse(matchH.group(2) ?? '0') ?? 0;
      return h * 60 + m;
    }
    final nombre = double.tryParse(s.replaceAll(',', '.'));
    if (nombre != null) return (nombre * 60).round();
    return null;
  }

  /// Multiplie une durée par le nombre de techniciens intervenus — le
  /// temps passé standard représente le temps de présence sur site,
  /// mais la main d'œuvre facturée compte chaque technicien. Laisse la
  /// durée telle quelle si elle est illisible ou si un seul technicien
  /// est intervenu.
  static String multiplierDuree(String duree, int nbTechniciens) {
    if (nbTechniciens <= 1) return duree;
    final minutes = _parseDuree(duree);
    if (minutes == null) return duree;
    return _formaterDuree(minutes * nbTechniciens);
  }

  /// Ajuste une durée saisie librement (Dépannage) au prorata d'un
  /// changement d'effectif — pas de calcul automatique de base à
  /// multiplier ici, seulement un rééquilibrage proportionnel de ce qui
  /// est déjà saisi quand un technicien est ajouté ou retiré.
  static String ajusterDureeEffectif(String duree, int ancienEffectif, int nouvelEffectif) {
    if (ancienEffectif <= 0 || nouvelEffectif == ancienEffectif) return duree;
    final minutes = _parseDuree(duree);
    if (minutes == null || minutes == 0) return duree;
    return _formaterDuree((minutes * nouvelEffectif / ancienEffectif).round());
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

  /// "Nom - Groupe - Localisation" (segments vides ignorés) — même
  /// format partout où l'équipement du bon est affiché (PDF, écran
  /// bureau), pour ne jamais le composer à deux endroits différemment.
  /// Installation neuve : la fiche n'existe pas encore dans le parc GMAO
  /// tant que le bureau ne l'a pas validée — toujours marqué comme tel.
  static String equipementLabel(BonIntervention b) {
    final base = [b.equipementNom, b.equipementGroupe, b.equipementLocalisation]
        .where((s) => s.trim().isNotEmpty)
        .join(' - ');
    if (base.isEmpty) return base;
    return b.pole == Poles.installationNeuve ? '$base (à confirmer)' : base;
  }

  static double totalHT(List<Presta> prestas) => prestas.fold(
    0,
    (total, p) => total + (montantLigne(p) ?? 0),
  );
}

/// Libellé "PP - Libellé" du dossier Drive d'un pôle (ex "20 - Maintenance") —
/// utilisé plus tard pour l'archivage (Phase 4), gardé ici pour rester
/// avec les autres formats.
String driveFolderNamePole(String code) => '$code - ${Poles.label(code)}';
