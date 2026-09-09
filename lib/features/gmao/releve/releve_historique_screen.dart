import 'package:flutter/material.dart';
import '../types_equipement/type_equipement_model.dart';
import 'releve_model.dart';
import 'releve_service.dart';

/// Historique des visites déjà enregistrées pour un équipement — pensé
/// pour un technicien qui découvre le site/l'équipement (dépannage,
/// site inconnu) : les anomalies (checklist "À voir"/"Mauvais"/etc.)
/// sont mises en évidence plutôt que noyées dans le détail, tout est
/// classé du plus récent au plus ancien.
class ReleveHistoriqueScreen extends StatelessWidget {
  final String equipementId;
  final String nomEquipement;
  final TypeEquipementModel type;

  const ReleveHistoriqueScreen({
    super.key,
    required this.equipementId,
    required this.nomEquipement,
    required this.type,
  });

  String _deuxChiffres(int n) => n.toString().padLeft(2, '0');

  String _formaterDate(DateTime d) =>
      '${_deuxChiffres(d.day)}/${_deuxChiffres(d.month)}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Historique — $nomEquipement'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<ReleveModel>>(
        stream: ReleveService().getRelevesForEquipement(equipementId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final releves = snapshot.data!;
          if (releves.isEmpty) {
            return Center(
              child: Text(
                'Aucune visite enregistrée pour cet équipement',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: releves.length,
            itemBuilder: (context, index) => _carteReleve(releves[index]),
          );
        },
      ),
    );
  }

  Widget _carteReleve(ReleveModel releve) {
    final remarques = <String, String>{
      'Remarque 1': releve.remarque1,
      'Remarque 2': releve.remarque2,
      'Informations internes': releve.informationsInternes,
    }..removeWhere((_, valeur) => valeur.trim().isEmpty);

    final anomalies = <String, String>{};
    final normaux = <String, String>{};
    for (final item in type.checklist) {
      final valeur = releve.checklistValues[item.rep.toString()];
      if (valeur == null || valeur.toString().trim().isEmpty) continue;
      final texte = valeur.toString();
      if (item.typeValeur == TypeValeurChecklist.enum_ &&
          item.options.isNotEmpty &&
          texte != item.options.first) {
        anomalies[item.label] = texte;
      } else {
        normaux[item.label] = texte;
      }
    }

    final mesures = <String, List<MapEntry<String, String>>>{};
    for (final groupe in type.groupesMesures) {
      final occurrences = releve.groupesMesures[groupe.cle];
      if (occurrences == null) continue;
      for (var i = 0; i < occurrences.length; i++) {
        final valeurs = occurrences[i];
        final entrees = <MapEntry<String, String>>[];
        for (final champ in groupe.champs) {
          final v = valeurs[champ.cle];
          if (v == null || v.trim().isEmpty) continue;
          entrees.add(
            MapEntry(
              champ.unite.isEmpty ? champ.label : '${champ.label} (${champ.unite})',
              v,
            ),
          );
        }
        if (entrees.isEmpty) continue;
        final titre = groupe.repetable
            ? '${groupe.label} ${i + 1}'
            : groupe.label;
        mesures[titre] = entrees;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_outlined, color: Colors.teal, size: 18),
                const SizedBox(width: 8),
                Text(
                  _formaterDate(releve.date),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (releve.nomTech.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.person_outline, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 4),
                  Text(
                    releve.nomTech,
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
                if (releve.validationFonctionnement != null) ...[
                  const Spacer(),
                  Text(
                    releve.validationFonctionnement!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: releve.validationFonctionnement == 'Fonctionnel'
                          ? Colors.green[700]
                          : Colors.orange[800],
                    ),
                  ),
                ],
              ],
            ),
            if (anomalies.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange[800], size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Points signalés',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                    for (final entry in anomalies.entries)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${entry.key} : ${entry.value}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (remarques.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final entry in remarques.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      children: [
                        TextSpan(
                          text: '${entry.key} : ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: entry.value),
                      ],
                    ),
                  ),
                ),
            ],
            if (mesures.isNotEmpty) ...[
              const SizedBox(height: 6),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Mesures', style: TextStyle(fontSize: 13)),
                children: [
                  for (final groupe in mesures.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupe.key,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _listeLignes(groupe.value),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            if (normaux.isNotEmpty) ...[
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text(
                  'Détail checklist',
                  style: TextStyle(fontSize: 13),
                ),
                children: [_listeLignes(normaux.entries.toList())],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Liste compacte "label : valeur", une ligne par entrée — plus
  /// lisible qu'un paragraphe unique séparé par des tirets.
  Widget _listeLignes(List<MapEntry<String, String>> lignes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final ligne in lignes)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                children: [
                  TextSpan(
                    text: '${ligne.key} : ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: ligne.value),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
