import 'package:flutter/material.dart';
import 'reference_horaire_model.dart';
import 'reference_horaire_tree.dart';
import 'references_horaires_service.dart';

/// Référentiel des heures d'entretien standard (Tech/Assistant ×
/// Annuelle/Semestrielle/Trimestrielle) par type d'équipement — source
/// unique, réutilisée pour tous les clients au lieu d'être recopiée sur
/// chaque fiche équipement.
class ReferencesHorairesListScreen extends StatefulWidget {
  const ReferencesHorairesListScreen({super.key});

  @override
  State<ReferencesHorairesListScreen> createState() =>
      _ReferencesHorairesListScreenState();
}

const List<Color> _couleursFamilles = [
  Colors.teal,
  Colors.indigo,
  Colors.orange,
  Colors.purple,
  Colors.brown,
  Colors.cyan,
  Colors.deepOrange,
  Colors.green,
  Colors.blueGrey,
  Colors.pink,
  Colors.blue,
];

class _ReferencesHorairesListScreenState
    extends State<ReferencesHorairesListScreen> {
  final ReferencesHorairesService _service = ReferencesHorairesService();
  bool _importEnCours = false;

  Future<void> _importer() async {
    setState(() => _importEnCours = true);
    try {
      final compte = await _service.importerClasseur();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              compte == 0
                  ? 'Aucune ligne importée'
                  : '$compte référence(s) importée(s) (remplace le référentiel existant)',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _importEnCours = false);
    }
  }

  void _ouvrirFormulaire({ReferenceHoraireModel? existante}) {
    final designationController = TextEditingController(
      text: existante?.designation ?? '',
    );
    final controllers = {
      'hrsTechAn': TextEditingController(
        text: existante == null ? '' : existante.hrsTechAn.toString(),
      ),
      'hrsAssistantAn': TextEditingController(
        text: existante == null ? '' : existante.hrsAssistantAn.toString(),
      ),
      'hrsTechSem': TextEditingController(
        text: existante == null ? '' : existante.hrsTechSem.toString(),
      ),
      'hrsAssistantSem': TextEditingController(
        text: existante == null ? '' : existante.hrsAssistantSem.toString(),
      ),
      'hrsTechTri': TextEditingController(
        text: existante == null ? '' : existante.hrsTechTri.toString(),
      ),
      'hrsAssistantTri': TextEditingController(
        text: existante == null ? '' : existante.hrsAssistantTri.toString(),
      ),
    };
    final labels = {
      'hrsTechAn': 'Hrs Tech Annuelle',
      'hrsAssistantAn': 'Hrs Assistant Annuelle',
      'hrsTechSem': 'Hrs Tech Semestrielle',
      'hrsAssistantSem': 'Hrs Assistant Semestrielle',
      'hrsTechTri': 'Hrs Tech Trimestrielle',
      'hrsAssistantTri': 'Hrs Assistant Trimestrielle',
    };

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existante == null ? 'Ajouter une référence' : 'Modifier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: designationController,
                decoration: const InputDecoration(labelText: 'Désignation'),
              ),
              const SizedBox(height: 10),
              for (final cle in controllers.keys)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: TextField(
                    controller: controllers[cle],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: labels[cle]),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              double n(String cle) =>
                  double.tryParse(
                    controllers[cle]!.text.trim().replaceAll(',', '.'),
                  ) ??
                  0;

              try {
                final reference = ReferenceHoraireModel(
                  id: existante?.id ?? '',
                  designation: designationController.text.trim(),
                  hrsTechAn: n('hrsTechAn'),
                  hrsAssistantAn: n('hrsAssistantAn'),
                  hrsTechSem: n('hrsTechSem'),
                  hrsAssistantSem: n('hrsAssistantSem'),
                  hrsTechTri: n('hrsTechTri'),
                  hrsAssistantTri: n('hrsAssistantTri'),
                );
                if (existante == null) {
                  await _service.addReference(reference);
                } else {
                  await _service.updateReference(
                    existante.id,
                    reference.toMap(),
                  );
                }
                if (!dialogContext.mounted) return;
                navigator.pop();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Erreur : $e')),
                );
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Heures de référence équipements'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _importEnCours
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.upload_file),
            tooltip: 'Importer le classeur "Base horaire équipement"',
            onPressed: _importEnCours ? null : _importer,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Exporter en Excel',
            onPressed: () => _service.exporterClasseur(),
          ),
        ],
      ),
      body: StreamBuilder<List<ReferenceHoraireModel>>(
        stream: _service.getReferences(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final references = snapshot.data!;

          if (references.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 60,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Référentiel vide — importe le classeur ou ajoute une ligne',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final arbre = construireArbreReferences(references);

          return ListView(
            padding: const EdgeInsets.all(10),
            children: [
              for (var i = 0; i < arbre.racines.length; i++)
                _etiquetteNoeud(
                  noeud: arbre.racines[i],
                  couleur: _couleursFamilles[i % _couleursFamilles.length],
                  ouvertParDefaut: arbre.racines.length == 1,
                  estRacine: true,
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal[700],
        onPressed: () => _ouvrirFormulaire(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// Rendu récursif d'un nœud de l'arbre : étiquette colorée pleine
  /// largeur pour la racine (même style que les autres écrans GMAO),
  /// sous-menus plus discrets pour les niveaux suivants.
  Widget _etiquetteNoeud({
    required NoeudReference noeud,
    required Color couleur,
    required bool ouvertParDefaut,
    required bool estRacine,
  }) {
    final nbReferences = _compterFeuilles(noeud);
    final enfants = [
      for (final feuille in noeud.feuilles) _carteReference(feuille),
      for (final enfant in noeud.enfants)
        _etiquetteNoeud(
          noeud: enfant,
          couleur: couleur,
          ouvertParDefaut: false,
          estRacine: false,
        ),
    ];

    if (estRacine) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            elevation: 1,
            child: ExpansionTile(
              initiallyExpanded: ouvertParDefaut,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              iconColor: couleur,
              collapsedIconColor: couleur,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.category_outlined,
                  color: couleur,
                  size: 26,
                ),
              ),
              title: Text(
                noeud.label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                '$nbReferences référence(s)',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: enfants,
            ),
          ),
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        iconColor: couleur,
        collapsedIconColor: couleur,
        title: Text(
          noeud.label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: couleur,
          ),
        ),
        subtitle: Text(
          '$nbReferences référence(s)',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        children: enfants,
      ),
    );
  }

  int _compterFeuilles(NoeudReference noeud) {
    var total = noeud.feuilles.length;
    for (final enfant in noeud.enfants) {
      total += _compterFeuilles(enfant);
    }
    return total;
  }

  Widget _carteReference(ReferenceHoraireModel ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(
          ref.designation,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Tech : ${ref.hrsTechAn}h / ${ref.hrsTechSem}h / ${ref.hrsTechTri}h  '
          '·  Assistant : ${ref.hrsAssistantAn}h / ${ref.hrsAssistantSem}h / ${ref.hrsAssistantTri}h\n'
          '(Annuelle / Semestrielle / Trimestrielle)',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            if (action == 'modifier') {
              _ouvrirFormulaire(existante: ref);
            } else if (action == 'supprimer') {
              await _service.deleteReference(ref.id);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'modifier', child: Text('Modifier')),
            PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
          ],
        ),
      ),
    );
  }
}
