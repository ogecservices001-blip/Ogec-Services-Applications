import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' as excel_pkg;
import '../../features/annuaire/clients/client_model.dart';
import '../../features/annuaire/suppliers/supplier_model.dart';
import '../../features/gmao/equipements/download/download.dart';

/// Position (index colonne, 0-based) de chaque champ [ClientModel] dans
/// la feuille "SITES" du classeur maître — même mapping que
/// [DatabaseService.importClientsFromExcelRows], à l'envers, pour que le
/// fichier exporté soit ensuite réimportable tel quel via "Importer
/// Clients". Les index absents (0, 3, 4) correspondent à des colonnes du
/// fichier maître non reprises dans le modèle — laissées vides.
final Map<int, String Function(ClientModel)> _colonnesSites = {
  1: (c) => c.nom,
  2: (c) => c.site,
  5: (c) => c.nAffaire,
  6: (c) => c.nbHeuresVendues,
  7: (c) => c.nbHeuresVenduesAssistant,
  8: (c) => c.qteHeuresProgrammees,
  9: (c) => c.qteHeuresRestantes,
  10: (c) => c.freqEntretienAn,
  11: (c) => c.commune,
  12: (c) => c.codePostal,
  13: (c) => c.adresse,
  14: (c) => c.complementAdresse,
  15: (c) => c.interlocuteurSite,
  16: (c) => c.telFixeInterlocuteurSite,
  17: (c) => c.portableInterlocuteurSite,
  18: (c) => c.courrielInterlocuteurSite,
  19: (c) => c.responsableContrat,
  20: (c) => c.telFixeResponsable,
  21: (c) => c.portableResponsable,
  22: (c) => c.courrielResponsable,
  23: (c) => c.communeFacturation,
  24: (c) => c.codePostalFacturation,
  25: (c) => c.adresseFacturation,
  26: (c) => c.complementAdresseFacturation,
  27: (c) => c.interlocuteurFacturation,
  28: (c) => c.telFixeInterlocuteurFacturation,
  29: (c) => c.portableInterlocuteurFacturation,
  30: (c) => c.courrielInterlocuteurFacturation,
  31: (c) => c.interlocuteurTiers,
  32: (c) => c.telFixeTiers,
  33: (c) => c.portableTiers,
  34: (c) => c.courrielTiers,
  35: (c) => c.epiSpecifique,
  36: (c) => c.habilitationSpecifique,
  37: (c) => c.moyenAcces,
  38: (c) => c.jourAcces,
  39: (c) => c.heuresAcces,
  40: (c) => c.dateOffre,
  41: (c) => c.datePriseEffetContrat,
  42: (c) => c.dureeContrat,
  43: (c) => c.montantContratAv,
  44: (c) => c.dateFinContrat,
  45: (c) => c.dateIndiceSPrime,
  46: (c) => c.dateIndiceChPrime,
  47: (c) => c.tauxHoraireVendu,
  48: (c) => c.tauxHoraireRegie,
  49: (c) => c.forfaitDeplacement,
  50: (c) => c.referenceOffreOgs,
  51: (c) => c.valeurIndiceSPrime,
  52: (c) => c.valeurIndiceChPrime,
  53: (c) => c.freqFactuAnnuelle,
  54: (c) => c.delaiIntervention,
  55: (c) => c.formuleRevisionEntretien,
  56: (c) => c.formuleRevisionDepannage,
  57: (c) => c.dateRevision,
  58: (c) => c.dateIndiceS,
  59: (c) => c.valeurIndiceS,
  60: (c) => c.dateIndiceCh,
  61: (c) => c.valeurIndiceCh,
  62: (c) => c.montantContratAvRevise,
  63: (c) => c.tauxHoraireRevise,
  64: (c) => c.forfaitDeplacementRevise,
  65: (c) => c.modifRiOuBg,
  66: (c) => c.remarquesLibres,
};

const Map<int, String> _entetesSites = {
  1: 'Nom',
  2: 'Site',
  5: 'N° Affaire',
  6: 'Nb Heures Vendues',
  7: 'Nb Heures Vendues Assistant',
  8: 'Qté Heures Programmées',
  9: 'Qté Heures Restantes',
  10: 'Fréq. Entretien/an',
  11: 'Commune',
  12: 'Code Postal',
  13: 'Adresse',
  14: 'Complément Adresse',
  15: 'Interlocuteur Site',
  16: 'Tél Fixe Interlocuteur Site',
  17: 'Portable Interlocuteur Site',
  18: 'Courriel Interlocuteur Site',
  19: 'Responsable Contrat',
  20: 'Tél Fixe Responsable',
  21: 'Portable Responsable',
  22: 'Courriel Responsable',
  23: 'Commune Facturation',
  24: 'Code Postal Facturation',
  25: 'Adresse Facturation',
  26: 'Complément Adresse Facturation',
  27: 'Interlocuteur Facturation',
  28: 'Tél Fixe Interlocuteur Facturation',
  29: 'Portable Interlocuteur Facturation',
  30: 'Courriel Interlocuteur Facturation',
  31: 'Interlocuteur Tiers',
  32: 'Tél Fixe Tiers',
  33: 'Portable Tiers',
  34: 'Courriel Tiers',
  35: 'EPI Spécifique',
  36: 'Habilitation Spécifique',
  37: 'Moyen Accès',
  38: 'Jour Accès',
  39: 'Heures Accès',
  40: "Date Offre",
  41: 'Date Prise Effet Contrat',
  42: 'Durée Contrat',
  43: 'Montant Contrat AV',
  44: 'Date Fin Contrat',
  45: 'Date Indice S\'',
  46: 'Date Indice Ch\'',
  47: 'Taux Horaire Vendu',
  48: 'Taux Horaire Régie',
  49: 'Forfait Déplacement',
  50: 'Référence Offre OGS',
  51: 'Valeur Indice S\'',
  52: 'Valeur Indice Ch\'',
  53: 'Fréq. Factu. Annuelle',
  54: 'Délai Intervention',
  55: 'Formule Révision Entretien',
  56: 'Formule Révision Dépannage',
  57: 'Date Révision',
  58: 'Date Indice S',
  59: 'Valeur Indice S',
  60: 'Date Indice Ch',
  61: 'Valeur Indice Ch',
  62: 'Montant Contrat AV Révisé',
  63: 'Taux Horaire Révisé',
  64: 'Forfait Déplacement Révisé',
  65: 'Modif RI ou BG',
  66: 'Remarques Libres',
};

class RepertoireExportService {
  /// Exporte des clients au format de la feuille "SITES" du classeur
  /// maître — réimportable tel quel via "Importer Clients" (Outils
  /// admin ou étiquette client du Répertoire).
  void exporterClients(List<ClientModel> clients, String nomFichier) {
    final excel = excel_pkg.Excel.createExcel();
    final nomFeuille = excel.getDefaultSheet()!;
    excel.rename(nomFeuille, 'SITES');

    final nbColonnes = 67;
    excel.appendRow(
      'SITES',
      List.generate(
        nbColonnes,
        (i) => excel_pkg.TextCellValue(_entetesSites[i] ?? ''),
      ),
    );

    for (final client in clients) {
      excel.appendRow(
        'SITES',
        List.generate(
          nbColonnes,
          (i) =>
              excel_pkg.TextCellValue(_colonnesSites[i]?.call(client) ?? ''),
        ),
      );
    }

    final bytes = excel.encode();
    if (bytes == null) return;
    downloadBytes(Uint8List.fromList(bytes), _nettoyerNomFichier(nomFichier));
  }

  /// Exporte des fournisseurs en CSV (point-virgule) — même ordre de
  /// colonnes que celui attendu par "Importer Fournisseurs".
  void exporterFournisseurs(List<SupplierModel> suppliers, String nomFichier) {
    final buffer = StringBuffer();
    buffer.writeln(
      [
        'Nom',
        'Dénomination courte',
        'Interlocuteurs',
        'Tél',
        'Portable',
        'Courriel',
        'Site Web',
        'Commune',
        'Code Postal',
        'Adresse',
        'Complément Adresse',
        'Produits Clés',
        'Remarques',
      ].join(';'),
    );
    for (final s in suppliers) {
      buffer.writeln(
        [
          s.nom,
          s.denominationCourte,
          s.interlocuteurs,
          s.tel,
          s.portable,
          s.courriel,
          s.siteWeb,
          s.commune,
          s.codePostal,
          s.adresse,
          s.complementAdresse,
          s.produitsCles,
          s.remarques,
        ].map((v) => v.replaceAll(';', ',').replaceAll('\n', ' ')).join(';'),
      );
    }

    downloadBytes(
      Uint8List.fromList(utf8.encode(buffer.toString())),
      _nettoyerNomFichier(nomFichier),
    );
  }

  String _nettoyerNomFichier(String nomFichier) =>
      nomFichier.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
}
