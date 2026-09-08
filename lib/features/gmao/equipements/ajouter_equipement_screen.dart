import 'package:flutter/material.dart';
import '../types_equipement/type_equipement_model.dart';
import '../gmao_database_service.dart';
import '../references_horaires/reference_horaire_model.dart';
import '../references_horaires/references_horaires_service.dart';
import '../references_horaires/suggestion_reference_horaire.dart';
import '../references_horaires/choisir_type_equipement_23.dart';
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
  final Map<String, TextEditingController> _champsEnTeteControllers = {};

  TypeEquipementModel? _typeSelectionne;
  List<ReferenceHoraireModel> _toutesReferences = [];
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
      _champsEnTeteValues.addAll(existant.champsEnTete);
      _typeSelectionne = widget.typesDisponibles
          .where((t) => t.id == existant.typeEquipementId)
          .firstOrNull;
    }
    _typeSelectionne ??= widget.typesDisponibles.firstOrNull;
    _reconstruireControleurs();
    _chargerReferences();
  }

  /// Reconstruit les contrôleurs de texte des champs spécifiques à la
  /// famille sélectionnée — persistants entre les frappes (pas recréés
  /// à chaque `setState`, sinon le curseur saute) ; à refaire quand la
  /// famille change, puisque la liste de champs change avec elle.
  void _reconstruireControleurs() {
    for (final c in _champsEnTeteControllers.values) {
      c.dispose();
    }
    _champsEnTeteControllers.clear();
    for (final champ in _typeSelectionne?.champsEnTeteSupplementaires ?? const []) {
      if (champ.options.isEmpty) {
        _champsEnTeteControllers[champ.cle] = TextEditingController(
          text: _champsEnTeteValues[champ.cle]?.toString() ?? '',
        );
      }
    }
  }

  Future<void> _chargerReferences() async {
    final references = await _referencesService.getReferences().first;
    if (mounted) setState(() => _toutesReferences = references);
  }

  /// Référence horaire correspondant exactement à Type Equipement 1/2/3
  /// (champs génériques de la famille, ci-dessous) — pas de sélection
  /// manuelle séparée.
  ReferenceHoraireModel? get _referenceCorrespondante => trouverReferenceExacte(
    champsEnTete: _champsEnTeteValues,
    references: _toutesReferences,
  );

  /// Ouvre la sélection guidée (Type Equipement 2 puis 3, avec
  /// confirmation) pour la famille sélectionnée.
  Future<void> _changerTypeEquipement23() async {
    final fixe = _typeSelectionne?.typeEquipement1Fixe ?? '';
    if (fixe.isEmpty) return;
    final resultat = await choisirTypeEquipement23(
      context: context,
      typeEquipement1Fixe: fixe,
      references: _toutesReferences,
    );
    if (resultat == null || !mounted) return;
    setState(() {
      _champsEnTeteValues['typeEquipement1'] = fixe;
      _champsEnTeteValues['typeEquipement2'] = resultat['typeEquipement2'];
      _champsEnTeteValues['typeEquipement3'] = resultat['typeEquipement3'];
    });
  }

  @override
  void dispose() {
    _nomController.dispose();
    _numeroController.dispose();
    _localisationController.dispose();
    _groupeController.dispose();
    for (final c in _champsEnTeteControllers.values) {
      c.dispose();
    }
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
        referenceHoraireId: _referenceCorrespondante?.id ?? '',
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
            onChanged: (t) => setState(() {
              _typeSelectionne = t;
              _reconstruireControleurs();
            }),
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
          if ((_typeSelectionne?.typeEquipement1Fixe ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: _changerTypeEquipement23,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Type Equipement',
                  isDense: true,
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.chevron_right),
                ),
                child: Text(
                  concatTypeEquipement(_champsEnTeteValues).isEmpty
                      ? 'Appuyer pour choisir'
                      : concatTypeEquipement(_champsEnTeteValues),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
          if (_referenceCorrespondante != null) ...[
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
                  _referenceCorrespondante!.designation,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
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
        controller: _champsEnTeteControllers[champ.cle],
        onChanged: (v) => setState(() => _champsEnTeteValues[champ.cle] = v),
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
