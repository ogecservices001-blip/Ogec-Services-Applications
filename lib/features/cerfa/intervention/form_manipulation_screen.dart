import 'package:flutter/material.dart';
import '../models/cerfa_data_model.dart';
import 'form_recap_screen.dart';

class FormManipulationScreen extends StatefulWidget {
  final CerfaData cerfaData;

  const FormManipulationScreen({super.key, required this.cerfaData});

  @override
  State<FormManipulationScreen> createState() => _FormManipulationScreenState();
}

class _FormManipulationScreenState extends State<FormManipulationScreen> {
  final _quantiteController = TextEditingController();
  final _qaController = TextEditingController();
  final _denomController = TextEditingController();
  final _qbController = TextEditingController();
  final _qcController = TextEditingController();

  final _qdeController = TextEditingController();
  final _qdController = TextEditingController();
  final _bsffController = TextEditingController();
  final _qeController = TextEditingController();
  final _contenantIdController = TextEditingController();

  final _observationsController = TextEditingController();

  bool _isUN1078 = false;
  bool _isUN3161 = false;

  static const List<String> _fluidesUN1078 = ['R-410A', 'R-134a', 'R-407C'];

  @override
  void initState() {
    super.initState();
    final fluideNormalise = widget.cerfaData.equipementFluide.trim();
    _isUN1078 = _fluidesUN1078.contains(fluideNormalise);
    _isUN3161 = fluideNormalise == 'R32';

    _qaController.addListener(_recalculerChargeTotale);
    _qbController.addListener(_recalculerChargeTotale);
    _qcController.addListener(_recalculerChargeTotale);
    _qdController.addListener(_recalculerRecupTotale);
    _qeController.addListener(_recalculerRecupTotale);
  }

  double _parse(String value) =>
      double.tryParse(value.replaceAll(',', '.')) ?? 0;

  void _recalculerChargeTotale() {
    final total =
        _parse(_qaController.text) +
        _parse(_qbController.text) +
        _parse(_qcController.text);
    final totalStr = total == total.truncateToDouble()
        ? total.toStringAsFixed(0)
        : total.toStringAsFixed(2);
    if (_quantiteController.text != totalStr) {
      _quantiteController.text = totalStr;
    }
  }

  void _recalculerRecupTotale() {
    final total = _parse(_qdController.text) + _parse(_qeController.text);
    final totalStr = total == total.truncateToDouble()
        ? total.toStringAsFixed(0)
        : total.toStringAsFixed(2);
    if (_qdeController.text != totalStr) {
      _qdeController.text = totalStr;
    }
  }

  void _onAbandon() => Navigator.pop(context);

  void _onValider() {
    final data = widget.cerfaData
      ..quantite = _quantiteController.text
      ..qa = _qaController.text
      ..denom = _denomController.text
      ..qb = _qbController.text
      ..qc = _qcController.text
      ..qde = _qdeController.text
      ..qd = _qdController.text
      ..bsff = _bsffController.text
      ..qe = _qeController.text
      ..contenantId = _contenantIdController.text
      ..caseUN1078 = _isUN1078
      ..caseUN3161 = _isUN3161
      ..observations = _observationsController.text;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FormRecapScreen(cerfaData: data)),
    );
  }

  Widget _buildNumField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildTotalField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          filled: true,
          fillColor: Colors.grey.shade100,
          suffixIcon: const Icon(Icons.calculate, size: 18),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _qaController.removeListener(_recalculerChargeTotale);
    _qbController.removeListener(_recalculerChargeTotale);
    _qcController.removeListener(_recalculerChargeTotale);
    _qdController.removeListener(_recalculerRecupTotale);
    _qeController.removeListener(_recalculerRecupTotale);

    _quantiteController.dispose();
    _qaController.dispose();
    _denomController.dispose();
    _qbController.dispose();
    _qcController.dispose();
    _qdeController.dispose();
    _qdController.dispose();
    _bsffController.dispose();
    _qeController.dispose();
    _contenantIdController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Écran 4 : Manipulation du Fluide',
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
                            Text(
                              'Fluide : ${widget.cerfaData.equipementFluide}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Manipulation du fluide frigorigène',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Fluide chargé',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTotalField(
                      _quantiteController,
                      'Quantité chargée totale (A+B+C) Kg — calculée',
                    ),
                    _buildNumField(_qaController, 'A - Dont fluide vierge Kg'),
                    _buildTextField(
                      _denomController,
                      'Dénomination du fluide chargé si changement',
                    ),
                    _buildNumField(_qbController, 'B - Dont fluide recyclé Kg'),
                    _buildNumField(
                      _qcController,
                      'C - Dont fluide régénéré Kg',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Fluide récupéré',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTotalField(
                      _qdeController,
                      'Quantité de fluide récupérée totale (D+E) Kg — calculée',
                    ),
                    _buildNumField(
                      _qdController,
                      'D - Dont fluide destiné au traitement Kg',
                    ),
                    _buildTextField(
                      _bsffController,
                      'Si connu, numéro du BSFF (Trackdéchets)',
                    ),
                    _buildNumField(
                      _qeController,
                      'E - Dont fluide conservé pour réutilisation Kg',
                    ),
                    _buildTextField(
                      _contenantIdController,
                      'Identification du ou des contenants',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Classification UN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    CheckboxListTile(
                      title: const Text('UN 1078'),
                      subtitle: const Text('R-410A / R-134a / R-407C'),
                      value: _isUN1078,
                      onChanged: null,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      title: const Text('UN 3161'),
                      subtitle: const Text('R32'),
                      value: _isUN3161,
                      onChanged: null,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Observations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _observationsController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Observations libres...',
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
