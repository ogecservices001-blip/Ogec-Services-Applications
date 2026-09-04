import 'package:flutter/material.dart';
import '../types_equipement/type_equipement_model.dart';
import '../gmao_database_service.dart';
import '../references_horaires/reference_horaire_model.dart';
import '../references_horaires/references_horaires_service.dart';
import '../references_horaires/choisir_reference_horaire_screen.dart';
import 'equipement_model.dart';

/// Formulaire d'ajout (ou modification) d'un équipement du parc d'un
/// client. Les champs "Marque", "Type réfrigérant", etc. sont générés
/// depuis le référentiel [TypeEquipementModel] de la famille choisie —
/// aucun champ codé en dur, comme le formulaire de relevé.
class AjouterEquipementScreen extends StatefulWidget {
  final String clientId;
  final List<TypeEquipementModel> typesDisponibles;
  final EquipementModel? equipementExistant;

  const AjouterEquipementScreen({
    super.key,
    required this.clientId,
    required this.typesDisponibles,
    this.equipementExistant,
  });

  @override
  State<AjouterEquipementScreen> createState() =>
      _AjouterEquipementScreenState();
}

class _AjouterEquipementScreenState extends State<AjouterEquipementScreen> {
  final GmaoDatabaseService _gmaoDb = GmaoDatabaseService();
  final ReferencesHorairesService _referencesService =
      ReferencesHorairesService();
  final _nomController = TextEditingController();
  final _numeroController = TextEditingController();
  final _localisationController = TextEditingController();
  final _groupeController = TextEditingController();
  final Map<String, dynamic> _champsEnTeteValues = {};

  TypeEquipementModel? _typeSelectionne;
  String _referenceHoraireId = '';
  ReferenceHoraireModel? _referenceHoraire;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    final existant = widget.equipementExistant;
    if (existant != null) {
      _nomController.text = existant.nom;
      _numeroController.text = existant.numeroEquipement;
      _localisationController.text = existant.localisation;
      _groupeController.text = existant.groupe;
      _referenceHoraireId = existant.referenceHoraireId;
      _champsEnTeteValues.addAll(existant.champsEnTete);
      _typeSelectionne = widget.typesDisponibles
          .where((t) => t.id == existant.typeEquipementId)
          .firstOrNull;
    }
    _typeSelectionne ??= widget.typesDisponibles.firstOrNull;
    if (_referenceHoraireId.isNotEmpty) _chargerReferenceHoraire();
  }

  Future<void> _chargerReferenceHoraire() async {
    final ref = await _referencesService.getReferenceById(_referenceHoraireId);
    if (mounted) setState(() => _referenceHoraire = ref);
  }

  Future<void> _choisirReferenceHoraire() async {
    final choix = await Navigator.push<ReferenceHoraireModel>(
      context,
      MaterialPageRoute(
        builder: (context) => const ChoisirReferenceHoraireScreen(),
      ),
    );
    if (choix != null) {
      setState(() {
        _referenceHoraireId = choix.id;
        _referenceHoraire = choix;
      });
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _numeroController.dispose();
    _localisationController.dispose();
    _groupeController.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (_typeSelectionne == null || _nomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Famille et nom sont obligatoires')),
      );
      return;
    }

    setState(() => _enCours = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final equipement = EquipementModel(
        id: widget.equipementExistant?.id ?? '',
        clientId: widget.clientId,
        typeEquipementId: _typeSelectionne!.id,
        nom: _nomController.text.trim(),
        numeroEquipement: _numeroController.text.trim(),
        localisation: _localisationController.text.trim(),
        groupe: _groupeController.text.trim(),
        referenceHoraireId: _referenceHoraireId,
        champsEnTete: _champsEnTeteValues,
      );

      if (widget.equipementExistant != null) {
        await _gmaoDb.updateEquipement(
          widget.equipementExistant!.id,
          equipement.toMap(),
        );
      } else {
        await _gmaoDb.addEquipement(equipement);
      }

      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          widget.equipementExistant == null
              ? 'Ajouter un équipement'
              : "Modifier l'équipement",
        ),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Famille d'équipement",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<TypeEquipementModel>(
            initialValue: _typeSelectionne,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: widget.typesDisponibles
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text('${t.code} — ${t.nom}'),
                  ),
                )
                .toList(),
            onChanged: (t) => setState(() => _typeSelectionne = t),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nomController,
            decoration: const InputDecoration(
              labelText: 'Nom (ex: UI VRV 04-06)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _numeroController,
            decoration: const InputDecoration(
              labelText: 'Numéro équipement (ex: 462-01-31)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _localisationController,
            decoration: const InputDecoration(
              labelText: 'Localisation',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _groupeController,
            decoration: const InputDecoration(
              labelText: 'Groupe (ex: Split Système)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.schedule_outlined, color: Colors.teal),
              title: const Text('Référence horaire'),
              subtitle: Text(
                _referenceHoraire?.designation ??
                    (_referenceHoraireId.isEmpty
                        ? 'Aucune — appuyer pour choisir'
                        : 'Chargement...'),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _choisirReferenceHoraire,
            ),
          ),
          if (_typeSelectionne?.champsEnTeteSupplementaires.isNotEmpty ==
              true) ...[
            const SizedBox(height: 20),
            const Text(
              'INFORMATIONS SPÉCIFIQUES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            for (final champ
                in _typeSelectionne!.champsEnTeteSupplementaires) ...[
              _champField(champ),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _enCours ? null : _enregistrer,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _enCours
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Widget _champField(ChampEnTete champ) {
    if (champ.options.isEmpty) {
      return TextField(
        keyboardType: champ.numerique
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: champ.label,
          suffixText: champ.unite.isEmpty ? null : champ.unite,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        controller: TextEditingController(
          text: _champsEnTeteValues[champ.cle]?.toString() ?? '',
        ),
        onChanged: (v) => _champsEnTeteValues[champ.cle] = v,
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _champsEnTeteValues[champ.cle] as String?,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: champ.label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: champ
          .optionsAvec(_champsEnTeteValues[champ.cle] as String?)
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: (v) => setState(() => _champsEnTeteValues[champ.cle] = v),
    );
  }
}
