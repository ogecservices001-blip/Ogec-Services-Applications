import 'package:flutter/material.dart';
import 'reference_horaire_model.dart';
import 'reference_horaire_tree.dart';
import 'references_horaires_service.dart';

/// Sélecteur en cascade dans le catalogue "Heures de référence" : on
/// navigue Famille → sous-niveaux → puissance, jusqu'à choisir une
/// ligne précise. Retourne le [ReferenceHoraireModel] choisi via
/// `Navigator.pop`.
class ChoisirReferenceHoraireScreen extends StatefulWidget {
  const ChoisirReferenceHoraireScreen({super.key});

  @override
  State<ChoisirReferenceHoraireScreen> createState() =>
      _ChoisirReferenceHoraireScreenState();
}

class _ChoisirReferenceHoraireScreenState
    extends State<ChoisirReferenceHoraireScreen> {
  final ReferencesHorairesService _service = ReferencesHorairesService();
  final List<NoeudReference> _pile = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          _pile.isEmpty
              ? 'Choisir une référence horaire'
              : _pile.map((n) => n.label).join(' › '),
        ),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        leading: _pile.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _pile.removeLast()),
              ),
      ),
      body: StreamBuilder<List<ReferenceHoraireModel>>(
        stream: _service.getReferences(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final arbre = construireArbreReferences(snapshot.data!);
          final noeuds = _pile.isEmpty ? arbre.racines : _pile.last.enfants;
          final feuilles = _pile.isEmpty ? const [] : _pile.last.feuilles;

          if (noeuds.isEmpty && feuilles.isEmpty) {
            return Center(
              child: Text(
                'Référentiel vide',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(10),
            children: [
              for (final noeud in noeuds)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.folder_outlined,
                      color: Colors.teal,
                    ),
                    title: Text(noeud.label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => setState(() => _pile.add(noeud)),
                  ),
                ),
              for (final feuille in feuilles)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.schedule_outlined,
                      color: Colors.orange,
                    ),
                    title: Text(
                      feuille.puissance.isEmpty
                          ? feuille.designation
                          : feuille.puissance,
                    ),
                    subtitle: Text(
                      'Tech ${feuille.hrsTechAn}/${feuille.hrsTechSem}/${feuille.hrsTechTri}h · '
                      'Assistant ${feuille.hrsAssistantAn}/${feuille.hrsAssistantSem}/${feuille.hrsAssistantTri}h',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () => Navigator.pop(context, feuille),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
