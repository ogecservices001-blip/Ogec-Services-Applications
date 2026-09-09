import 'package:flutter/material.dart';
import '../types_equipement/type_equipement_model.dart';
import '../references_horaires/reference_horaire_model.dart';
import '../references_horaires/references_horaires_service.dart';
import '../references_horaires/suggestion_reference_horaire.dart';
import '../references_horaires/calcul_heures_visite.dart';
import '../releve/releve_service.dart';
import '../releve/releve_historique_screen.dart';
import '../../annuaire/clients/client_model.dart';
import 'equipement_model.dart';

/// Consultation en lecture seule de toutes les données actuelles d'un
/// équipement — aucune saisie, aucun relevé démarré, juste un aperçu
/// rapide (ex: avant un dépannage, pour vérifier une référence sans
/// ouvrir tout le formulaire d'entretien).
class VisualiserDonneesScreen extends StatefulWidget {
  final EquipementModel equipement;
  final TypeEquipementModel type;
  final ClientModel? client;

  const VisualiserDonneesScreen({
    super.key,
    required this.equipement,
    required this.type,
    this.client,
  });

  @override
  State<VisualiserDonneesScreen> createState() =>
      _VisualiserDonneesScreenState();
}

class _VisualiserDonneesScreenState extends State<VisualiserDonneesScreen> {
  final ReferencesHorairesService _referencesService =
      ReferencesHorairesService();
  final ReleveService _releveService = ReleveService();
  List<ReferenceHoraireModel> _toutesReferences = [];
  int? _freqCouranteCalculee;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final references = await _referencesService.getReferences().first;
    final freq = await _releveService.freqCouranteCalculee(
      widget.equipement.id,
    );
    if (mounted) {
      setState(() {
        _toutesReferences = references;
        _freqCouranteCalculee = freq;
        _chargement = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final eq = widget.equipement;
    final type = widget.type;
    final c = eq.champsEnTete;

    final reference = trouverReferenceExacte(
      champsEnTete: c,
      references: _toutesReferences,
    );
    final freqAnnuelle = int.tryParse(
      c['freqEntretienAnnuelle']?.toString() ?? '',
    );
    final heures = (reference != null &&
            freqAnnuelle != null &&
            _freqCouranteCalculee != null)
        ? calculerHeuresVisite(
            freqEntretienAnnuelle: freqAnnuelle,
            freqCourante: _freqCouranteCalculee!,
            reference: reference,
          )
        : null;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Visualiser Données'),
        backgroundColor: Colors.blueGrey[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'Historique des visites',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReleveHistoriqueScreen(
                  equipementId: eq.id,
                  nomEquipement: eq.nom,
                  type: type,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _carteIdentite(eq, type),
                const SizedBox(height: 10),
                _carteChamps([
                  if (c['freqEntretienAnnuelle']?.toString().isNotEmpty == true)
                    MapEntry(
                      'Fréquence entretien annuelle',
                      c['freqEntretienAnnuelle'].toString(),
                    ),
                  if (_freqCouranteCalculee != null && freqAnnuelle != null)
                    MapEntry(
                      'Visite en cours',
                      '$_freqCouranteCalculee de $freqAnnuelle ${DateTime.now().year}',
                    ),
                  if (heures != null)
                    MapEntry(
                      'Heures prévues',
                      '${heures.heuresTech}h Tech / ${heures.heuresAssistant}h Assistant',
                    ),
                  if (reference != null)
                    MapEntry('Référence catalogue', reference.designation),
                  for (final champ in type.champsEnTeteSupplementaires)
                    if (c[champ.cle]?.toString().isNotEmpty == true)
                      MapEntry(
                        champ.unite.isEmpty
                            ? champ.label
                            : '${champ.label} (${champ.unite})',
                        c[champ.cle].toString(),
                      ),
                ]),
              ],
            ),
    );
  }

  Widget _carteIdentite(EquipementModel eq, TypeEquipementModel type) {
    return Card(
      color: Colors.teal[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.precision_manufacturing_outlined,
              size: 36,
              color: Colors.teal,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.client != null)
                    Text(
                      [
                        widget.client!.nom,
                        widget.client!.site,
                      ].where((s) => s.isNotEmpty).join(' — '),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    type.code,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.teal,
                    ),
                  ),
                  Text(
                    type.nom,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    eq.nom,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (eq.groupe.isNotEmpty)
                    Text('Groupe : ${eq.groupe}', style: const TextStyle(fontSize: 12)),
                  if (eq.numeroEquipement.isNotEmpty || eq.localisation.isNotEmpty)
                    Text(
                      [
                        eq.numeroEquipement,
                        eq.localisation,
                      ].where((s) => s.isNotEmpty).join(' — '),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  if (type.typeEquipement1Fixe.isNotEmpty &&
                      concatTypeEquipement(eq.champsEnTete).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        concatTypeEquipement(eq.champsEnTete),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[800],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteChamps(List<MapEntry<String, String>> champs) {
    if (champs.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            'Aucune information renseignée',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ),
      );
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < champs.length; i++) ...[
              if (i > 0) Divider(height: 1, color: Colors.grey[200]),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        champs[i].key,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Text(
                        champs[i].value,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
