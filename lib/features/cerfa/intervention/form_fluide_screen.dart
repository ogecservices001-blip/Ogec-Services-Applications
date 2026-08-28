import 'package:flutter/material.dart';
import '../models/cerfa_data_model.dart';
import 'form_detection_screen.dart';

class FormFluideScreen extends StatefulWidget {
  final CerfaData cerfaData;

  const FormFluideScreen({super.key, required this.cerfaData});

  @override
  State<FormFluideScreen> createState() => _FormFluideScreenState();
}

class _FormFluideScreenState extends State<FormFluideScreen> {
  final TextEditingController _marqueController = TextEditingController();
  final TextEditingController _dateMESController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _localisationController = TextEditingController();

  String? _selectedFluide;
  final TextEditingController _chargeController = TextEditingController();
  String _teqCO2 = '0.00';
  bool _caseAssemblage = false;
  bool _caseMiseService = false;
  bool _caseModif = false;
  bool _caseMaintenance = false;
  bool _caseCtrlPerio = false;
  bool _caseCtrlNonPerio = false;
  bool _caseDemantel = false;
  bool _caseAutre = false;
  final TextEditingController _autreController = TextEditingController();

  final List<String> _fluides = ['R-410A', 'R32', 'R-134a', 'R-407C'];

  final Map<String, double> _prg = {
    'R-410A': 1924,
    'R32': 675,
    'R-134a': 1430,
    'R-407C': 1774,
  };

  @override
  void initState() {
    super.initState();
    final e = widget.cerfaData.equipement;
    _marqueController.text = e.marque;
    _dateMESController.text = e.dateMES;
    _referenceController.text = e.reference;
    _localisationController.text = e.localisation;
    _chargeController.text = e.charge;
    _selectedFluide = e.refrigerants;
    _calculerTeqCO2();
  }

  void _calculerTeqCO2() {
    if (_selectedFluide == null || _chargeController.text.isEmpty) {
      setState(() => _teqCO2 = '0.00');
      return;
    }
    final chargeDouble = double.tryParse(
      _chargeController.text.replaceAll(',', '.'),
    );
    if (chargeDouble == null || chargeDouble <= 0) {
      setState(() => _teqCO2 = '0.00');
      return;
    }
    final prg = _prg[_selectedFluide] ?? 0;
    final resultat = (chargeDouble * prg) / 1000;
    setState(() => _teqCO2 = resultat.toStringAsFixed(2));
  }

  void _onValider() {
    if (!_caseAssemblage &&
        !_caseMiseService &&
        !_caseModif &&
        !_caseMaintenance &&
        !_caseCtrlPerio &&
        !_caseCtrlNonPerio &&
        !_caseDemantel &&
        !_caseAutre) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez sélectionner au moins une nature d\'intervention.',
          ),
        ),
      );
      return;
    }

    final chargeValue =
        double.tryParse(_chargeController.text.replaceAll(',', '.')) ?? 0;

    final data = widget.cerfaData
      ..equipementMarque = _marqueController.text.trim()
      ..equipementDateMES = _dateMESController.text.trim()
      ..equipementReference = _referenceController.text.trim()
      ..equipementLocalisation = _localisationController.text.trim()
      ..equipementFluide = _selectedFluide ?? ''
      ..equipementCharge = _chargeController.text
      ..equipementTeqCO2 = _teqCO2
      ..caseAssemblage = _caseAssemblage
      ..caseMiseService = _caseMiseService
      ..caseModif = _caseModif
      ..caseMaintenance = _caseMaintenance
      ..caseCtrlPerio = _caseCtrlPerio
      ..caseCtrlNonPerio = _caseCtrlNonPerio
      ..caseDemantel = _caseDemantel
      ..caseAutre = _caseAutre
      ..autreTexte = _autreController.text;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FormDetectionScreen(cerfaData: data, charge: chargeValue),
      ),
    );
  }

  void _onAbandon() => Navigator.pop(context);

  @override
  void dispose() {
    _marqueController.dispose();
    _dateMESController.dispose();
    _referenceController.dispose();
    _localisationController.dispose();
    _chargeController.dispose();
    _autreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.cerfaData.equipement;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Écran 2 : Fluide & Intervention',
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
                              'Équipement : ${e.nomEquipement}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Client : ${e.client}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              'Site : ${e.site}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Chrono : sera attribué à la validation',
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '1 - Informations équipement',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ces champs sont pré-remplis depuis la base ; '
                      'vous pouvez les corriger si besoin. Toute correction '
                      'sera reportée dans la base équipements si la valeur '
                      'd\'origine était vide.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _marqueController,
                      decoration: const InputDecoration(
                        labelText: 'Marque',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(
                          Icons.branding_watermark,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _dateMESController,
                      decoration: const InputDecoration(
                        labelText: 'Date M.E.S.',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.event, color: Colors.blue),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Référence',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.qr_code, color: Colors.blue),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _localisationController,
                      decoration: const InputDecoration(
                        labelText: 'Localisation',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.place, color: Colors.blue),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '2 - Fluide frigorigène',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Fluide frigorigène',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.science, color: Colors.blue),
                      ),
                      initialValue: _selectedFluide,
                      items: _fluides.map((fluide) {
                        return DropdownMenuItem(
                          value: fluide,
                          child: Text(fluide),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedFluide = value);
                        _calculerTeqCO2();
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _chargeController,
                      decoration: const InputDecoration(
                        labelText: 'Charge (kg)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.scale, color: Colors.blue),
                        hintText: 'Ex: 12.5',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => _calculerTeqCO2(),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tonnage équivalent CO₂ :',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '$_teqCO2 t éq CO₂',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '3 - Nature de l\'intervention',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 3.5,
                      children: [
                        CheckboxListTile(
                          title: const Text('Assemblage'),
                          value: _caseAssemblage,
                          onChanged: (v) =>
                              setState(() => _caseAssemblage = v ?? false),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          title: const Text('Mise en service'),
                          value: _caseMiseService,
                          onChanged: (v) =>
                              setState(() => _caseMiseService = v ?? false),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          title: const Text('Modification'),
                          value: _caseModif,
                          onChanged: (v) =>
                              setState(() => _caseModif = v ?? false),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          title: const Text('Maintenance'),
                          value: _caseMaintenance,
                          onChanged: (v) =>
                              setState(() => _caseMaintenance = v ?? false),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          title: const Text('Contrôle périodique'),
                          value: _caseCtrlPerio,
                          onChanged: (v) =>
                              setState(() => _caseCtrlPerio = v ?? false),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          title: const Text('Contrôle non périodique'),
                          value: _caseCtrlNonPerio,
                          onChanged: (v) =>
                              setState(() => _caseCtrlNonPerio = v ?? false),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          title: const Text('Démantèlement'),
                          value: _caseDemantel,
                          onChanged: (v) =>
                              setState(() => _caseDemantel = v ?? false),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          title: const Text('Autre (préciser)'),
                          value: _caseAutre,
                          onChanged: (v) =>
                              setState(() => _caseAutre = v ?? false),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ),
                    if (_caseAutre)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextField(
                          controller: _autreController,
                          decoration: const InputDecoration(
                            labelText: 'Précisez la nature de l\'intervention',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.edit, color: Colors.blue),
                          ),
                          maxLines: 2,
                        ),
                      ),
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
                      onPressed: _onAbandon,
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
                      onPressed: _onValider,
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
