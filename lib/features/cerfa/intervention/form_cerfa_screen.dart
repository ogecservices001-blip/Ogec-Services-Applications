import 'package:flutter/material.dart';
import '../models/equipement_model.dart';
import '../models/cerfa_data_model.dart';
import '../services/sheets_service.dart';
import 'form_fluide_screen.dart';

class FormCerfaScreen extends StatefulWidget {
  const FormCerfaScreen({super.key});

  @override
  State<FormCerfaScreen> createState() => _FormCerfaScreenState();
}

class _FormCerfaScreenState extends State<FormCerfaScreen> {
  final SheetsService _sheetsService = SheetsService();
  List<Equipement> _equipements = [];
  bool _isLoading = true;
  bool _isValidating = false;

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
    };
  }

  void _onAbandon() {
    Navigator.pop(context);
  }

  Future<void> _onValider() async {
    if (_selectedEquipement == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un équipement.')),
      );
      return;
    }

    if (_isValidating) return;

    setState(() => _isValidating = true);

    try {
      final e = _selectedEquipement!;

      final detenteurLigne3 = e.complementAdresse.isNotEmpty
          ? e.complementAdresse
          : '${e.codePostal} - ${e.commune}';

      final cerfaData = CerfaData(equipement: e)
        ..operateur =
            'Omnium Génie Climatique Services\n918 Chemin Du Tour Des Roches\n97460 Saint-Paul'
        ..detenteur = '${e.client} ${e.site}\n${e.adresse}\n$detenteurLigne3'
        ..equipementId = e.nomEquipement
        ..nomSignataireClient = e.nomSignataireClient
        ..qualiteSignataire = e.qualiteSignataire
        ..emailSignataireClient = e.emailSignataireClient;

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FormFluideScreen(cerfaData: cerfaData),
        ),
      );

      setState(() => _isValidating = false);
    } catch (e) {
      setState(() => _isValidating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la création du CERFA : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        // Garde le champ synchronisé si _selectedClient est réinitialisé
        // ailleurs (ex: après validation d'un CERFA)
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
            // Si le texte tapé ne correspond plus exactement à un
            // client valide, on efface la sélection en cours
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
          'Écran 1 : Sélection',
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
                              prefixIcon: Icon(
                                Icons.location_on,
                                color: Colors.blue,
                              ),
                            ),
                            initialValue: _selectedSite,
                            items: _sites.map((site) {
                              return DropdownMenuItem(
                                value: site,
                                child: Text(site),
                              );
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                              entry.value,
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
                      child: _isValidating
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
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
