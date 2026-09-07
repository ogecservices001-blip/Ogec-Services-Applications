import 'package:flutter/material.dart';
import '../../annuaire/clients/client_model.dart';
import '../gmao_database_service.dart';
import '../types_equipement/type_equipement_model.dart';
import 'equipement_model.dart';
import 'equipement_import_service.dart';

/// Écran récapitulatif d'un import "Sommaire" pour un ou plusieurs
/// sites : montre les ajouts / modifications / suppressions détectés
/// par rapport à l'existant, avec une case à cocher par équipement (pas
/// par champ), avant toute écriture en base. Avec plusieurs [sites],
/// chaque ligne est rattachée au bon site via ses colonnes Client/Site
/// (voir [EquipementImportService.calculerDiff]).
class ImportEquipementsScreen extends StatefulWidget {
  final List<ClientModel> sites;
  final List<TypeEquipementModel> types;

  const ImportEquipementsScreen({
    super.key,
    required this.sites,
    required this.types,
  });

  @override
  State<ImportEquipementsScreen> createState() =>
      _ImportEquipementsScreenState();
}

class _ImportEquipementsScreenState extends State<ImportEquipementsScreen> {
  final GmaoDatabaseService _gmaoDb = GmaoDatabaseService();
  final EquipementImportService _importService = EquipementImportService();

  bool _chargementEnCours = true;
  bool _applicationEnCours = false;
  ResultatDiff? _diff;

  final Set<int> _ajoutsCoches = {};
  final Set<int> _modificationsCochees = {};
  final Set<int> _suppressionsCochees = {};

  @override
  void initState() {
    super.initState();
    _chargerEtComparer();
  }

  Future<void> _chargerEtComparer() async {
    final lignes = await _importService.pickAndParseSommaire();
    if (lignes == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final existantsParSite = <String, List<EquipementModel>>{};
    for (final site in widget.sites) {
      existantsParSite[site.id] = await _gmaoDb
          .getEquipementsForClient(site.id)
          .first;
    }
    final typesById = {for (final t in widget.types) t.id: t};

    final diff = _importService.calculerDiff(
      lignes: lignes,
      sites: widget.sites,
      existantsParSite: existantsParSite,
      typesById: typesById,
    );

    setState(() {
      _diff = diff;
      _ajoutsCoches.addAll(List.generate(diff.ajouts.length, (i) => i));
      _modificationsCochees.addAll(
        List.generate(diff.modifications.length, (i) => i),
      );
      _chargementEnCours = false;
    });
  }

  Future<void> _appliquer() async {
    final diff = _diff;
    if (diff == null) return;

    setState(() => _applicationEnCours = true);
    try {
      for (var i = 0; i < diff.ajouts.length; i++) {
        if (!_ajoutsCoches.contains(i)) continue;
        final ligne = diff.ajouts[i].ligne;
        await _gmaoDb.addEquipement(
          EquipementModel(
            id: '',
            clientId: diff.ajouts[i].clientId,
            typeEquipementId: ligne.typeEquipementId!,
            nom: ligne.nom,
            numeroEquipement: ligne.numeroEquipement,
            localisation: ligne.localisation,
            groupe: ligne.groupe,
            champsEnTete: ligne.champsEnTete,
          ),
        );
      }

      for (var i = 0; i < diff.modifications.length; i++) {
        if (!_modificationsCochees.contains(i)) continue;
        final mod = diff.modifications[i];
        final champsEnTete = Map<String, dynamic>.from(
          mod.existant.champsEnTete,
        )..addAll(mod.ligne.champsEnTete);
        await _gmaoDb.updateEquipement(mod.existant.id, {
          'nom': mod.ligne.nom.isNotEmpty ? mod.ligne.nom : mod.existant.nom,
          'localisation': mod.ligne.localisation.isNotEmpty
              ? mod.ligne.localisation
              : mod.existant.localisation,
          'groupe': mod.ligne.groupe.isNotEmpty
              ? mod.ligne.groupe
              : mod.existant.groupe,
          'champsEnTete': champsEnTete,
        });
      }

      for (var i = 0; i < diff.suppressions.length; i++) {
        if (!_suppressionsCochees.contains(i)) continue;
        await _gmaoDb.deleteEquipement(diff.suppressions[i].existant.id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import appliqué')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _applicationEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          widget.sites.length == 1
              ? 'Import équipements'
              : 'Import équipements (${widget.sites.length} sites)',
        ),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
      ),
      body: _chargementEnCours
          ? const Center(child: CircularProgressIndicator())
          : _buildContenu(),
      floatingActionButton: (_diff == null || _diff!.vide)
          ? null
          : FloatingActionButton.extended(
              backgroundColor: Colors.teal[700],
              onPressed: _applicationEnCours ? null : _appliquer,
              icon: _applicationEnCours
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check, color: Colors.white),
              label: const Text(
                'Appliquer',
                style: TextStyle(color: Colors.white),
              ),
            ),
    );
  }

  Widget _buildContenu() {
    final diff = _diff!;
    if (diff.vide && diff.avertissements.isEmpty) {
      return Center(
        child: Text(
          'Aucun changement détecté — le parc est déjà à jour',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (diff.avertissements.isNotEmpty)
          _sectionAvertissements(diff.avertissements),
        if (diff.ajouts.isNotEmpty)
          _section(
            'Ajouts (${diff.ajouts.length})',
            Colors.green,
            List.generate(
              diff.ajouts.length,
              (i) => _ligneAjout(i, diff.ajouts[i]),
            ),
          ),
        if (diff.modifications.isNotEmpty)
          _section(
            'Modifications (${diff.modifications.length})',
            Colors.orange,
            List.generate(
              diff.modifications.length,
              (i) => _ligneModification(i, diff.modifications[i]),
            ),
          ),
        if (diff.suppressions.isNotEmpty)
          _section(
            'Suppressions proposées (${diff.suppressions.length})',
            Colors.red,
            List.generate(
              diff.suppressions.length,
              (i) => _ligneSuppression(i, diff.suppressions[i]),
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _sectionAvertissements(List<String> avertissements) {
    return Card(
      color: Colors.amber[50],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Avertissements (${avertissements.length})',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 6),
            for (final a in avertissements)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(a, style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(String titre, Color couleur, List<Widget> lignes) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              titre.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: couleur,
              ),
            ),
          ),
          ...lignes,
        ],
      ),
    );
  }

  String _libelleSite(String clientId) {
    final site = widget.sites.where((s) => s.id == clientId).firstOrNull;
    return site == null
        ? ''
        : [site.nom, site.site].where((s) => s.isNotEmpty).join(' — ');
  }

  Widget _ligneAjout(int i, DiffAjout ajout) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: CheckboxListTile(
        value: _ajoutsCoches.contains(i),
        onChanged: (v) => setState(() {
          if (v == true) {
            _ajoutsCoches.add(i);
          } else {
            _ajoutsCoches.remove(i);
          }
        }),
        activeColor: Colors.green,
        title: Text(ajout.ligne.nom),
        subtitle: Text(
          [
            if (widget.sites.length > 1) _libelleSite(ajout.clientId) else '',
            ajout.ligne.typeDeReleveBrut,
            ajout.ligne.numeroEquipement,
            ajout.ligne.localisation,
          ].where((s) => s.isNotEmpty).join(' — '),
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _ligneModification(int i, DiffModification mod) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: CheckboxListTile(
        value: _modificationsCochees.contains(i),
        onChanged: (v) => setState(() {
          if (v == true) {
            _modificationsCochees.add(i);
          } else {
            _modificationsCochees.remove(i);
          }
        }),
        activeColor: Colors.orange,
        title: Text(mod.existant.nom),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in mod.champs)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${c.label} : "${c.ancienne}" → "${c.nouvelle}"',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _ligneSuppression(int i, DiffSuppression sup) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: CheckboxListTile(
        value: _suppressionsCochees.contains(i),
        onChanged: (v) => setState(() {
          if (v == true) {
            _suppressionsCochees.add(i);
          } else {
            _suppressionsCochees.remove(i);
          }
        }),
        activeColor: Colors.red,
        title: Text(sup.existant.nom),
        subtitle: Text(
          'Absent du fichier importé — ${sup.existant.numeroEquipement}',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
