import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cerfa_data_model.dart';
import '../models/detecteur_model.dart';
import '../services/firestore_service.dart';
import 'form_manipulation_screen.dart';

class FormDetectionScreen extends StatefulWidget {
  final CerfaData cerfaData;
  final double charge;

  const FormDetectionScreen({
    super.key,
    required this.cerfaData,
    required this.charge,
  });

  @override
  State<FormDetectionScreen> createState() => _FormDetectionScreenState();
}

class _FormDetectionScreenState extends State<FormDetectionScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  List<Detecteur> _detecteurs = [];
  Detecteur? _selectedDetecteur;
  bool _isLoadingDetecteurs = true;

  bool _systemePermanentOui = false;
  bool _systemePermanentNon = true;

  late bool _hcfc2a30;
  late bool _hcfc30a300;
  late bool _periodicite12m;
  late bool _periodicite6m;

  bool? _fuiteConstatee;

  final List<TextEditingController> _fuiteLocaControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  final List<bool> _fuiteRealisee = [false, false, false];
  final List<bool> _fuiteAFaire = [false, false, false];

  final bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _hcfc2a30 = widget.charge < 30;
    _hcfc30a300 = widget.charge >= 30;
    _periodicite12m = widget.charge < 30;
    _periodicite6m = widget.charge >= 30;
    _loadDetecteurs();
  }

  Future<void> _loadDetecteurs() async {
    setState(() => _isLoadingDetecteurs = true);
    try {
      final data = await _firestoreService.getDetecteurs();
      setState(() {
        _detecteurs = data;
        _isLoadingDetecteurs = false;
      });
    } catch (e) {
      setState(() => _isLoadingDetecteurs = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement des détecteurs : $e')),
        );
      }
    }
  }

  Future<void> _showAddDetecteurDialog() async {
    final refController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter un détecteur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: refController,
                decoration: const InputDecoration(
                  labelText: 'Référence',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Date de contrôle : ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    child: const Text('Choisir'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );

    if (result == true && refController.text.trim().isNotEmpty) {
      try {
        await _firestoreService.addDetecteur(
          refController.text.trim(),
          selectedDate,
        );
        await _loadDetecteurs();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Détecteur ajouté')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
        }
      }
    }
  }

  Future<void> _deleteDetecteur(Detecteur d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce détecteur ?'),
        content: Text('Référence : ${d.reference}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreService.deleteDetecteur(d.id);
        setState(() {
          if (_selectedDetecteur?.id == d.id) _selectedDetecteur = null;
        });
        await _loadDetecteurs();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur suppression : $e')));
        }
      }
    }
  }

  void _onAbandon() => Navigator.pop(context);

  void _onValider() {
    if (_selectedDetecteur == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un détecteur.')),
      );
      return;
    }
    if (_fuiteConstatee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez indiquer si des fuites ont été constatées.'),
        ),
      );
      return;
    }

    final dc = _selectedDetecteur!.dateControle;

    final data = widget.cerfaData
      ..detecteurId = _selectedDetecteur!.reference
      ..controleJour = dc.day.toString().padLeft(2, '0')
      ..controleMois = dc.month.toString().padLeft(2, '0')
      ..controleAnnee = dc.year.toString()
      ..boutonOui = _systemePermanentOui ? 'true' : '-'
      ..caseHcfc2 = _hcfc2a30
      ..caseHcfc30 = _hcfc30a300
      ..caseSans12m = _periodicite12m
      ..caseSans6m = _periodicite6m
      ..caseFuiteOui = _fuiteConstatee == true
      ..caseFuiteNon = _fuiteConstatee == false
      ..fuiteLoca1 = _fuiteLocaControllers[0].text
      ..caseRepFuite1Realisee = _fuiteRealisee[0]
      ..caseRepFuite1AFaire = _fuiteAFaire[0]
      ..fuiteLoca2 = _fuiteLocaControllers[1].text
      ..caseRepFuite2Realisee = _fuiteRealisee[1]
      ..caseRepFuite2AFaire = _fuiteAFaire[1]
      ..fuiteLoca3 = _fuiteLocaControllers[2].text
      ..caseRepFuite3Realisee = _fuiteRealisee[2]
      ..caseRepFuite3AFaire = _fuiteAFaire[2];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormManipulationScreen(cerfaData: data),
      ),
    );
  }

  Widget _buildFuiteZone(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.blue.shade100),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fuite ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _fuiteLocaControllers[index],
                decoration: const InputDecoration(
                  labelText: 'Localisation de la fuite',
                  border: OutlineInputBorder(),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Réalisée'),
                      value: _fuiteRealisee[index],
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) {
                        setState(() {
                          _fuiteRealisee[index] = v ?? false;
                          if (_fuiteRealisee[index]) {
                            _fuiteAFaire[index] = false;
                          }
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('À faire'),
                      value: _fuiteAFaire[index],
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) {
                        setState(() {
                          _fuiteAFaire[index] = v ?? false;
                          if (_fuiteAFaire[index]) {
                            _fuiteRealisee[index] = false;
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var c in _fuiteLocaControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Écran 3 : Détection & Périodicité',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: Colors.blue.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Équipement : ${widget.cerfaData.equipement.nomEquipement}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Text(
                              'Chrono : sera attribué à la validation',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.black54,
                              ),
                            ),
                            Text('Charge : ${widget.charge} kg'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '5 - Détecteur de fuite',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingDetecteurs)
                      const Center(child: CircularProgressIndicator())
                    else
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<Detecteur>(
                              decoration: const InputDecoration(
                                labelText: 'Détecteur',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: _selectedDetecteur,
                              items: _detecteurs.map((d) {
                                return DropdownMenuItem(
                                  value: d,
                                  child: Text(
                                    '${d.reference} — ${DateFormat('dd/MM/yyyy').format(d.dateControle)}',
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedDetecteur = value);
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: Colors.blue,
                            ),
                            onPressed: _showAddDetecteurDialog,
                            tooltip: 'Ajouter un détecteur',
                          ),
                          if (_selectedDetecteur != null)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _deleteDetecteur(_selectedDetecteur!),
                              tooltip: 'Supprimer ce détecteur',
                            ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    const Text(
                      '6 - Présence d\'un système permanent de détection de fuite avec',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            title: const Text('Oui'),
                            value: _systemePermanentOui,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (v) {
                              setState(() {
                                _systemePermanentOui = v ?? false;
                                _systemePermanentNon = !_systemePermanentOui;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: CheckboxListTile(
                            title: const Text('Non'),
                            value: _systemePermanentNon,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (v) {
                              setState(() {
                                _systemePermanentNon = v ?? false;
                                _systemePermanentOui = !_systemePermanentNon;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '7 - Règle des fluides HCFC',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text('Charge : ${widget.charge} kg'),
                    CheckboxListTile(
                      title: const Text('2 kg ≤ Q < 30 kg'),
                      value: _hcfc2a30,
                      onChanged: null,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      title: const Text('30 kg ≤ Q < 300 kg'),
                      value: _hcfc30a300,
                      onChanged: null,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Périodicité de contrôle',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    CheckboxListTile(
                      title: const Text('12 mois'),
                      value: _periodicite12m,
                      onChanged: null,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      title: const Text('6 mois'),
                      value: _periodicite6m,
                      onChanged: null,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Fuites constatées lors du contrôle d\'étanchéité',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            title: const Text('OUI'),
                            value: _fuiteConstatee == true,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (v) {
                              setState(() {
                                _fuiteConstatee = (v ?? false) ? true : null;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: CheckboxListTile(
                            title: const Text('NON'),
                            value: _fuiteConstatee == false,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (v) {
                              setState(() {
                                _fuiteConstatee = (v ?? false) ? false : null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_fuiteConstatee == true) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Localisation de la fuite',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildFuiteZone(0),
                      _buildFuiteZone(1),
                      _buildFuiteZone(2),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isValidating ? null : _onAbandon,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.red, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Abandon',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isValidating ? null : _onValider,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Valider',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
}
