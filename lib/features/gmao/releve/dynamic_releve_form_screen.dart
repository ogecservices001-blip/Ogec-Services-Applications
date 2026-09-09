import 'package:flutter/material.dart';
import '../types_equipement/type_equipement_model.dart';
import '../equipements/equipement_model.dart';
import '../gmao_database_service.dart';
import '../../annuaire/clients/client_model.dart';
import '../../../core/services/user_service.dart';
import '../references_horaires/reference_horaire_model.dart';
import '../references_horaires/references_horaires_service.dart';
import '../references_horaires/calcul_heures_visite.dart';
import '../references_horaires/suggestion_reference_horaire.dart';
import '../references_horaires/choisir_type_equipement_23.dart';
import 'releve_model.dart';
import 'releve_service.dart';
import 'releve_historique_screen.dart';

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
/// L'enregistrement crée deux choses : la mise à jour des champs
/// équipement (permanents) et un nouveau document dans la collection
/// `releves` (historique de cette visite précise — checklist, mesures,
/// remarques), qui sert aussi à calculer automatiquement "Fréquence
/// courante" (voir `releve_service.dart`).
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
  final UserService _userService = UserService();
  final ReleveService _releveService = ReleveService();
  bool _enregistrementEnCours = false;
  List<ReferenceHoraireModel> _toutesReferences = [];
  int? _freqCouranteCalculee;
  final Map<String, dynamic> _champsEnTeteOriginaux = {};
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

    if (widget.equipement != null) {
      _champsEnTeteValues.addAll(widget.equipement!.champsEnTete);
      _champsEnTeteOriginaux.addAll(widget.equipement!.champsEnTete);
      _chargerFreqCourante();
    }
    // Chaque visite a ses propres remarques (historisées dans le
    // relevé, voir `releve_service.dart`) — on ne repart jamais de ce
    // qu'un précédent technicien avait écrit.
    _remarques = List.generate(3, (_) => TextEditingController());
    _chargerReferences();
    _preremplirNomTechnicien();

    if (widget.equipement != null) {
      // "Date interv. prévue" est repartie à la date du jour à chaque
      // nouvel entretien ouvert — l'ancienne valeur (déjà passée
      // puisqu'on est en train de faire la visite) n'a plus de sens à
      // afficher ; reste modifiable si le technicien connaît la vraie
      // prochaine date.
      final today = DateTime.now();
      _champsEnTeteValues['dateIntervPrevue'] =
          '${_deuxChiffres(today.day)}/${_deuxChiffres(today.month)}/${today.year}';
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

  Future<void> _chargerReferences() async {
    final references = await _referencesService.getReferences().first;
    if (mounted) setState(() => _toutesReferences = references);
  }

  /// Pré-remplit "Nom technicien" avec le compte connecté — évite une
  /// resaisie manuelle, le technicien peut toujours corriger si besoin
  /// (ex: il fait la visite pour un collègue).
  Future<void> _preremplirNomTechnicien() async {
    final nom = await _userService.getCurrentUserName();
    if (nom.isNotEmpty && mounted) {
      setState(() => _champsEnTeteValues['nomTech'] = nom);
    }
  }

  /// Référence horaire correspondant exactement à Type Equipement 1/2/3
  /// de l'équipement.
  ReferenceHoraireModel? get _referenceCorrespondante => trouverReferenceExacte(
    champsEnTete: _champsEnTeteValues,
    references: _toutesReferences,
  );

  /// Ouvre la sélection guidée (Type Equipement 2 puis 3, avec
  /// confirmation) — si l'admin s'est trompé à l'import, le technicien
  /// corrige ainsi plutôt qu'en texte libre, pour rester toujours
  /// cohérent avec le catalogue. La correction est tracée dans
  /// Remarque 1 au moment de l'enregistrement (voir
  /// [_tracerCorrectionsTypeEquipement]).
  Future<void> _changerTypeEquipement23() async {
    final fixe = widget.type.typeEquipement1Fixe;
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

  Future<void> _chargerFreqCourante() async {
    final freq = await _releveService.freqCouranteCalculee(
      widget.equipement!.id,
    );
    if (mounted) setState(() => _freqCouranteCalculee = freq);
  }

  int? get _freqEntretienAnnuelle => int.tryParse(
    _champsEnTeteValues['freqEntretienAnnuelle']?.toString() ?? '',
  );

  HeuresVisite? get _heuresVisiteEnCours {
    final reference = _referenceCorrespondante;
    if (reference == null) return null;
    final freqAnnuelle = _freqEntretienAnnuelle;
    final freqCourante = _freqCouranteCalculee;
    if (freqAnnuelle == null || freqCourante == null) return null;
    return calculerHeuresVisite(
      freqEntretienAnnuelle: freqAnnuelle,
      freqCourante: freqCourante,
      reference: reference,
    );
  }

  String _deuxChiffres(int n) => n.toString().padLeft(2, '0');

  /// Si le technicien a corrigé Type Equipement 1/2/3 par rapport à ce
  /// qui était importé, ajoute une ligne de traçabilité dans Remarque 1
  /// (ancienne valeur → nouvelle, technicien, date) — sans écraser ce
  /// que le technicien y a déjà écrit.
  void _tracerCorrectionsTypeEquipement() {
    const labels = {
      'typeEquipement1': 'Type Equipement 1',
      'typeEquipement2': 'Type Equipement 2',
      'typeEquipement3': 'Type Equipement 3',
    };
    final notes = <String>[];
    for (final entry in labels.entries) {
      final avant = _champsEnTeteOriginaux[entry.key]?.toString().trim() ?? '';
      final apres = _champsEnTeteValues[entry.key]?.toString().trim() ?? '';
      if (avant.isNotEmpty && avant != apres) {
        notes.add('${entry.value} : "$avant" → "$apres"');
      }
    }
    if (notes.isEmpty) return;

    final nomTech = _champsEnTeteValues['nomTech']?.toString() ?? '';
    final now = DateTime.now();
    final date = '${_deuxChiffres(now.day)}/${_deuxChiffres(now.month)}/${now.year}';
    final ligne =
        '[Correction $date${nomTech.isNotEmpty ? ' - $nomTech' : ''}] ${notes.join(' ; ')}';
    _remarques[0].text = _remarques[0].text.isEmpty
        ? ligne
        : '${_remarques[0].text}\n$ligne';
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

    _tracerCorrectionsTypeEquipement();

    setState(() => _enregistrementEnCours = true);
    try {
      await _gmaoDb.updateEquipement(widget.equipement!.id, {
        'champsEnTete': _champsEnTeteValues,
        'referenceHoraireId': _referenceCorrespondante?.id ?? '',
      });

      final groupesMesures = <String, List<Map<String, String>>>{};
      for (final entry in _groupeControllers.entries) {
        groupesMesures[entry.key] = entry.value
            .map(
              (occurrence) => occurrence.map(
                (cle, controller) => MapEntry(cle, controller.text),
              ),
            )
            .toList();
      }

      await _releveService.addReleve(
        ReleveModel(
          id: '',
          equipementId: widget.equipement!.id,
          clientId: widget.equipement!.clientId,
          date: DateTime.now(),
          nomTech: _champsEnTeteValues['nomTech']?.toString() ?? '',
          checklistValues: _checklistValues.map(
            (rep, valeur) => MapEntry(rep.toString(), valeur),
          ),
          groupesMesures: groupesMesures,
          validationFonctionnement: _validationFonctionnement,
          remarque1: _remarques[0].text,
          remarque2: _remarques[1].text,
          informationsInternes: _remarques[2].text,
        ),
      );

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Relevé enregistré'),
          duration: Duration(seconds: 3),
        ),
      );
      if (mounted) Navigator.of(context).pop();
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
        actions: widget.equipement == null
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.history, color: Colors.white),
                  tooltip: 'Historique des visites',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReleveHistoriqueScreen(
                        equipementId: widget.equipement!.id,
                        nomEquipement: widget.equipement!.nom,
                        type: widget.type,
                      ),
                    ),
                  ),
                ),
              ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerCard(type),

                if (type.champsEnTeteSupplementaires.isNotEmpty ||
                    type.typeEquipement1Fixe.isNotEmpty) ...[
                  _sectionTitle('Informations complémentaires'),
                  _fieldsCard([
                    if (type.typeEquipement1Fixe.isNotEmpty)
                      _ligneTypeEquipement(),
                    ...type.champsEnTeteSupplementaires.map(_staticFieldRow),
                  ]),
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


  Widget _ligneTypeEquipement() {
    final concat = concatTypeEquipement(_champsEnTeteValues);
    final heures = _heuresVisiteEnCours;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                concat.isEmpty ? 'Appuyer pour choisir' : concat,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          if (_freqCouranteCalculee != null && _freqEntretienAnnuelle != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Visite en cours : $_freqCouranteCalculee de '
                '$_freqEntretienAnnuelle ${DateTime.now().year}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ),
          if (heures != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'Heures prévues pour cette visite : '
                '${heures.heuresTech}h Tech / ${heures.heuresAssistant}h Assistant',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal[700],
                ),
              ),
            ),
        ],
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
              onChanged: (v) =>
                  setState(() => _champsEnTeteValues[champ.cle] = v),
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
