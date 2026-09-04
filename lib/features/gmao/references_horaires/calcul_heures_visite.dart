import 'reference_horaire_model.dart';

class HeuresVisite {
  final double heuresTech;
  final double heuresAssistant;
  const HeuresVisite(this.heuresTech, this.heuresAssistant);
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
