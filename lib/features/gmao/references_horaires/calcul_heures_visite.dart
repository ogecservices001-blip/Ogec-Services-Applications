import '../equipements/equipement_model.dart';
import 'reference_horaire_model.dart';
import 'suggestion_reference_horaire.dart';

class HeuresVisite {
  final double heuresTech;
  final double heuresAssistant;
  const HeuresVisite(this.heuresTech, this.heuresAssistant);

  HeuresVisite operator +(HeuresVisite autre) =>
      HeuresVisite(heuresTech + autre.heuresTech, heuresAssistant + autre.heuresAssistant);
}

/// Additionne les heures prévues de tous les équipements de [equipements]
/// dont la fréquence est renseignée — pour les compteurs par
/// groupe/site/client/global. La référence de chaque équipement est
/// recalculée en direct depuis Type Equipement 1/2/3 (pas depuis le
/// champ `referenceHoraireId` stocké, qui n'est rempli qu'au moment où
/// un relevé est enregistré — un équipement juste importé n'aurait
/// sinon jamais d'heures comptées).
HeuresVisite sommeHeuresVisite(
  List<EquipementModel> equipements,
  List<ReferenceHoraireModel> references,
) {
  var total = const HeuresVisite(0, 0);
  for (final eq in equipements) {
    final reference = trouverReferenceExacte(
      champsEnTete: eq.champsEnTete,
      references: references,
    );
    if (reference == null) continue;
    final freqAnnuelle = int.tryParse(
      eq.champsEnTete['freqEntretienAnnuelle']?.toString() ?? '',
    );
    final freqCourante = int.tryParse(
      eq.champsEnTete['freqCourante']?.toString() ?? '',
    );
    if (freqAnnuelle == null || freqCourante == null) continue;
    final heures = calculerHeuresVisite(
      freqEntretienAnnuelle: freqAnnuelle,
      freqCourante: freqCourante,
      reference: reference,
    );
    if (heures != null) total = total + heures;
  }
  return total;
}

/// Calcule les heures Tech/Assistant prévues pour la visite en cours,
/// selon la séquence : une visite "Annuelle" toujours en 1ère position,
/// puis en alternance selon la fréquence :
/// - 1 visite/an : la seule visite est en An
/// - 2 visites/an : 1ère = An, 2ème = Sem
/// - 4 visites/an : 1ère = An, 2ème = Tri, 3ème = Sem, 4ème = Tri
///
/// Retourne null si la fréquence/visite en cours n'est pas reconnue.
HeuresVisite? calculerHeuresVisite({
  required int freqEntretienAnnuelle,
  required int freqCourante,
  required ReferenceHoraireModel reference,
}) {
  switch (freqEntretienAnnuelle) {
    case 1:
      if (freqCourante != 1) return null;
      return HeuresVisite(reference.hrsTechAn, reference.hrsAssistantAn);
    case 2:
      switch (freqCourante) {
        case 1:
          return HeuresVisite(reference.hrsTechAn, reference.hrsAssistantAn);
        case 2:
          return HeuresVisite(reference.hrsTechSem, reference.hrsAssistantSem);
        default:
          return null;
      }
    case 4:
      switch (freqCourante) {
        case 1:
          return HeuresVisite(reference.hrsTechAn, reference.hrsAssistantAn);
        case 2:
          return HeuresVisite(reference.hrsTechTri, reference.hrsAssistantTri);
        case 3:
          return HeuresVisite(reference.hrsTechSem, reference.hrsAssistantSem);
        case 4:
          return HeuresVisite(reference.hrsTechTri, reference.hrsAssistantTri);
        default:
          return null;
      }
    default:
      return null;
  }
}
