import 'package:flutter/material.dart';
import '../models/equipement_model.dart';
import '../services/sheets_service.dart';

class VisualiserEquipementScreen extends StatefulWidget {
  const VisualiserEquipementScreen({super.key});

  @override
  State<VisualiserEquipementScreen> createState() =>
      _VisualiserEquipementScreenState();
}

class _VisualiserEquipementScreenState
    extends State<VisualiserEquipementScreen> {
  final SheetsService _sheetsService = SheetsService();
  List<Equipement> _equipements = [];
  bool _isLoading = true;

  String? _selectedClient;
  String? _selectedSite;
  Equipement? _selectedEquipement;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _sheetsService.getEquipements();
      setState(() {
        _equipements = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de chargement : $e')));
      }
    }
  }

  List<String> get _clients {
    return _equipements.map((e) => e.client).toSet().toList()..sort();
  }

  List<String> get _sites {
    if (_selectedClient == null) return [];
    return _equipements
        .where((e) => e.client == _selectedClient)
        .map((e) => e.site)
        .toSet()
        .toList()
      ..sort();
  }

  List<Equipement> get _equipementsForSite {
    if (_selectedSite == null || _selectedClient == null) return [];
    return _equipements
        .where((e) => e.client == _selectedClient && e.site == _selectedSite)
        .toList();
  }

  Map<String, String>? get _details {
    if (_selectedEquipement == null) return null;
    final e = _selectedEquipement!;
    return {
      'Numéro Client': e.numeroClient,
      'Numéro Site': e.numeroSite,
      'Numéro Chantier': e.numeroChantier,
      'Marque': e.marque,
      'Date M.E.S.': e.dateMES,
      'Référence': e.reference,
      'Localisation': e.localisation,
      'Réfrigérant': e.refrigerants,
      'Charge': e.charge,
      'Adresse': e.adresse,
      'Complément d\'adresse': e.complementAdresse,
      'Code Postal': e.codePostal,
      'Commune': e.commune,
      'Date dernier contrôle': e.dateDernierControle,
      'Date prochain contrôle': e.dateProchainControle,
      'N° dernier bordereau': e.numeroDernierBordereau,
      'Nom Signataire client': e.nomSignataireClient,
      'Qualité du Signataire': e.qualiteSignataire,
      'Email Signataire client': e.emailSignataireClient,
      'Opérateur': e.operateur,
    };
  }

  Widget _buildClientField() {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _clients;
        }
        final query = textEditingValue.text.toLowerCase();
        return _clients.where((client) => client.toLowerCase().contains(query));
      },
      onSelected: (String selection) {
        setState(() {
          _selectedClient = selection;
          _selectedSite = null;
          _selectedEquipement = null;
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        if (_selectedClient == null && controller.text.isNotEmpty) {
          controller.clear();
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Client',
            hintText: 'Tapez pour rechercher...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.business, color: Colors.blue),
          ),
          onChanged: (value) {
            if (value != _selectedClient) {
              if (_selectedClient != null) {
                setState(() {
                  _selectedClient = null;
                  _selectedSite = null;
                  _selectedEquipement = null;
                });
              }
            }
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Visualiser un équipement',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sélection Hiérarchique',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildClientField(),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Site',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on, color: Colors.blue),
                      ),
                      initialValue: _selectedSite,
                      items: _sites.map((site) {
                        return DropdownMenuItem(value: site, child: Text(site));
                      }).toList(),
                      onChanged: _selectedClient == null
                          ? null
                          : (value) {
                              setState(() {
                                _selectedSite = value;
                                _selectedEquipement = null;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Nom Équipement',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(
                          Icons.precision_manufacturing,
                          color: Colors.blue,
                        ),
                      ),
                      initialValue: _selectedEquipement?.nomEquipement,
                      items: _equipementsForSite.map((equip) {
                        return DropdownMenuItem(
                          value: equip.nomEquipement,
                          child: Text(equip.nomEquipement),
                        );
                      }).toList(),
                      onChanged: _selectedSite == null
                          ? null
                          : (value) {
                              setState(() {
                                _selectedEquipement = _equipementsForSite
                                    .firstWhere(
                                      (e) => e.nomEquipement == value,
                                    );
                              });
                            },
                    ),
                    const SizedBox(height: 32),
                    if (_details != null) ...[
                      const Text(
                        'Informations de l\'équipement',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.blue.shade100),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: _details!.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${entry.key} :',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        entry.value.isEmpty ? '—' : entry.value,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
