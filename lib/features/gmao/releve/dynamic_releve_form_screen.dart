import 'package:flutter/material.dart';
import '../types_equipement/type_equipement_model.dart';
import '../equipements/equipement_model.dart';
import '../gmao_database_service.dart';
import '../../annuaire/clients/client_model.dart';
import '../references_horaires/reference_horaire_model.dart';
import '../references_horaires/references_horaires_service.dart';
import '../references_horaires/choisir_reference_horaire_screen.dart';
import '../references_horaires/calcul_heures_visite.dart';
import '../references_horaires/suggestion_reference_horaire.dart';

/// Formulaire de relevé entièrement généré à partir de la config d'une
/// [TypeEquipementModel] : aucun champ n'est codé en dur pour une
/// famille — ajouter/modifier une famille dans le référentiel change
/// directement ce que ce formulaire affiche.
///
/// Si [equipement] est fourni (relevé réel sur un équipement du parc),
/// les champs d'en-tête spécifiques (marque, référence, n° série...)
/// restent éditables et toute modification est répercutée en
/// permanence sur la fiche équipement à l'enregistrement — ce sont des
/// propriétés de l'équipement, pas du relevé lui-même, mais un
/// technicien doit pouvoir corriger une erreur constatée sur place.
///
/// À ce stade, la partie relevé (checklist/mesures) reste un aperçu :
/// il n'y a pas encore de collection "releves" à laquelle la rattacher
/// (prochaine étape du Lot 1). Seules les infos équipement sont
/// réellement persistées.
class DynamicReleveFormScreen extends StatefulWidget {
  final TypeEquipementModel type;
  final EquipementModel? equipement;
  final ClientModel? client;

  const DynamicReleveFormScreen({
    super.key,
    required this.type,
    this.equipement,
    this.client,
  });

  @override
  State<DynamicReleveFormScreen> createState() =>
      _DynamicReleveFormScreenState();
}

class _DynamicReleveFormScreenState extends State<DynamicReleveFormScreen> {
  final GmaoDatabaseService _gmaoDb = GmaoDatabaseService();
  final ReferencesHorairesService _referencesService =
      ReferencesHorairesService();
  bool _enregistrementEnCours = false;
  String _referenceHoraireId = '';
  ReferenceHoraireModel? _referenceHoraire;
  bool _referenceSuggereeAuto = false;
  final Map<int, dynamic> _checklistValues = {};
  final Map<String, dynamic> _champsEnTeteValues = {};
  final Map<String, TextEditingController> _champsEnTeteControllers = {};
  final Map<String, List<Map<String, TextEditingController>>>
  _groupeControllers = {};
  String? _validationFonctionnement;

  static const _optionsValidation = [
    'Fonctionnel',
    'Non Fonctionnel',
    'Remarque ci dessous',
  ];
  late final List<TextEditingController> _remarques;

  @override
  void initState() {
    super.initState();
    _remarques = List.generate(3, (_) => TextEditingController());

    if (widget.equipement != null) {
      _champsEnTeteValues.addAll(widget.equipement!.champsEnTete);
      _referenceHoraireId = widget.equipement!.referenceHoraireId;
      if (_referenceHoraireId.isNotEmpty) {
        _chargerReferenceHoraire();
      } else {
        _suggererReferenceHoraire();
      }
    }

    for (final champ in widget.type.champsEnTeteSupplementaires) {
      if (champ.options.isEmpty) {
        _champsEnTeteControllers[champ.cle] = TextEditingController(
          text: _champsEnTeteValues[champ.cle]?.toString() ?? '',
        );
      }
    }

    for (final groupe in widget.type.groupesMesures) {
      final occurrences = groupe.repetable ? groupe.nombreMax : 1;
      _groupeControllers[groupe.cle] = List.generate(
        occurrences,
        (_) => {for (final champ in groupe.champs) champ.cle: TextEditingController()},
      );
    }
  }

  @override
  void dispose() {
    for (final c in _remarques) {
      c.dispose();
    }
    for (final c in _champsEnTeteControllers.values) {
      c.dispose();
    }
    for (final instances in _groupeControllers.values) {
      for (final instance in instances) {
        for (final c in instance.values) {
          c.dispose();
        }
      }
    }
    super.dispose();
  }

  Future<void> _chargerReferenceHoraire() async {
    final ref = await _referencesService.getReferenceById(_referenceHoraireId);
    if (mounted) setState(() => _referenceHoraire = ref);
  }

  /// Pré-remplit la référence horaire à partir du type d'équipement et
  /// de la puissance (cas standard "Split Autonome") — le technicien
  /// garde la main via [_choisirReferenceHoraire] si c'est en fait du
  /// VRV ou un autre cas particulier.
  Future<void> _suggererReferenceHoraire() async {
    final references = await _referencesService.getReferences().first;
    final suggestion = suggererReferenceHoraire(
      typeEquipement: _champsEnTeteValues['typeEquipement']?.toString() ?? '',
      puissanceBrute: _champsEnTeteValues['puissance']?.toString() ?? '',
      references: references,
    );
    if (suggestion != null && mounted) {
      setState(() {
        _referenceHoraireId = suggestion.id;
        _referenceHoraire = suggestion;
        _referenceSuggereeAuto = true;
      });
    }
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
        _referenceSuggereeAuto = false;
      });
    }
  }

  HeuresVisite? get _heuresVisiteEnCours {
    if (_referenceHoraire == null) return null;
    final freqAnnuelle = int.tryParse(
      _champsEnTeteValues['freqEntretienAnnuelle']?.toString() ?? '',
    );
    final freqCourante = int.tryParse(
      _champsEnTeteValues['freqCourante']?.toString() ?? '',
    );
    if (freqAnnuelle == null || freqCourante == null) return null;
    return calculerHeuresVisite(
      freqEntretienAnnuelle: freqAnnuelle,
      freqCourante: freqCourante,
      reference: _referenceHoraire!,
    );
  }

  Future<void> _enregistrer() async {
    final messenger = ScaffoldMessenger.of(context);

    if (widget.equipement == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Aperçu — ouvre ce formulaire depuis le parc d\'un client pour '
            'enregistrer un équipement réel',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _enregistrementEnCours = true);
    try {
      await _gmaoDb.updateEquipement(widget.equipement!.id, {
        'champsEnTete': _champsEnTeteValues,
        'referenceHoraireId': _referenceHoraireId,
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Informations équipement enregistrées — la checklist et les '
            'mesures restent en aperçu (collection "releves" à venir)',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _enregistrementEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(type.nom),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerCard(type),

                if (type.champsEnTeteSupplementaires.isNotEmpty) ...[
                  _sectionTitle('Informations complémentaires'),
                  _fieldsCard(
                    type.champsEnTeteSupplementaires
                        .map(_staticFieldRow)
                        .toList(),
                  ),
                ],

                if (widget.equipement != null) ...[
                  _sectionTitle('Référence horaire'),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.schedule_outlined,
                            color: Colors.teal,
                          ),
                          title: Text(
                            _referenceHoraire?.designation ??
                                (_referenceHoraireId.isEmpty
                                    ? 'Aucune — appuyer pour choisir'
                                    : 'Chargement...'),
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: _referenceSuggereeAuto
                              ? Text(
                                  'Suggestion automatique — corriger si besoin (ex: VRV)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange[800],
                                  ),
                                )
                              : null,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _choisirReferenceHoraire,
                        ),
                        if (_heuresVisiteEnCours != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Heures prévues pour cette visite : '
                                '${_heuresVisiteEnCours!.heuresTech}h Tech / '
                                '${_heuresVisiteEnCours!.heuresAssistant}h Assistant',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal[700],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                _sectionTitle("Checklist d'entretien"),
                _fieldsCard(
                  type.checklist.map(_checklistRow).toList(),
                ),

                for (final groupe in type.groupesMesures) ...[
                  _sectionTitle(groupe.label),
                  for (var i = 0; i < (_groupeControllers[groupe.cle]?.length ?? 0); i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (groupe.repetable)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '${groupe.label} ${i + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: groupe.champs.map((champ) {
                                  final controller =
                                      _groupeControllers[groupe.cle]![i][champ.cle]!;
                                  return SizedBox(
                                    width: 165,
                                    child: TextField(
                                      controller: controller,
                                      decoration: InputDecoration(
                                        labelText: champ.unite.isEmpty
                                            ? champ.label
                                            : '${champ.label} (${champ.unite})',
                                        isDense: true,
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],

                _sectionTitle('Validation'),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fonctionnement validé',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _optionsValidation
                              .map(
                                (o) => ChoiceChip(
                                  label: Text(o),
                                  selected: _validationFonctionnement == o,
                                  onSelected: (v) => setState(
                                    () => _validationFonctionnement = o,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),

                _sectionTitle('Remarques'),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: List.generate(3, (i) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: i < 2 ? 10 : 0),
                          child: TextField(
                            controller: _remarques[i],
                            decoration: InputDecoration(
                              labelText: 'Remarque ${i + 1}',
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                _sectionTitle('Signature'),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    height: 90,
                    alignment: Alignment.center,
                    child: Text(
                      'Signer ici',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ElevatedButton(
              onPressed: _enregistrementEnCours ? null : _enregistrer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _enregistrementEnCours
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Enregistrer le relevé',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard(TypeEquipementModel type) {
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
                        color: Colors.black87,
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
                  if (widget.equipement != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.equipement!.nom,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.equipement!.numeroEquipement.isNotEmpty ||
                        widget.equipement!.localisation.isNotEmpty)
                      Text(
                        [
                          widget.equipement!.numeroEquipement,
                          widget.equipement!.localisation,
                        ].where((s) => s.isNotEmpty).join(' — '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _staticFieldRow(ChampEnTete champ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: champ.options.isEmpty
          ? TextField(
              controller: _champsEnTeteControllers[champ.cle],
              keyboardType: champ.numerique
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              decoration: InputDecoration(
                labelText: champ.label,
                suffixText: champ.unite.isEmpty ? null : champ.unite,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => _champsEnTeteValues[champ.cle] = v,
            )
          : DropdownButtonFormField<String>(
              initialValue: _champsEnTeteValues[champ.cle] as String?,
              decoration: InputDecoration(
                labelText: champ.label,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              items: champ
                  .optionsAvec(_champsEnTeteValues[champ.cle] as String?)
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _champsEnTeteValues[champ.cle] = v),
            ),
    );
  }

  Widget _checklistRow(ChecklistItem item) {
    Widget input;
    switch (item.typeValeur) {
      case TypeValeurChecklist.bool_:
        input = Checkbox(
          value: _checklistValues[item.rep] == true,
          onChanged: (v) => setState(() => _checklistValues[item.rep] = v),
          activeColor: Colors.teal,
        );
        break;
      case TypeValeurChecklist.enum_:
        input = DropdownButton<String>(
          value: _checklistValues[item.rep] as String?,
          hint: const Text('—', style: TextStyle(fontSize: 12)),
          underline: const SizedBox(),
          items: item.options
              .map(
                (o) => DropdownMenuItem(
                  value: o,
                  child: Text(o, style: const TextStyle(fontSize: 13)),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _checklistValues[item.rep] = v),
        );
        break;
      case TypeValeurChecklist.text:
        input = SizedBox(
          width: 120,
          child: TextField(
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(isDense: true),
            onChanged: (v) => _checklistValues[item.rep] = v,
          ),
        );
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${item.rep}. ${item.label}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          input,
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 2),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _fieldsCard(List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: children),
      ),
    );
  }
}
