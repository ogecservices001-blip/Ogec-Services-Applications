import 'package:flutter/material.dart';
import '../models/equipement_model.dart';
import '../services/sheets_service.dart';
import 'admin_ajouter_equipement_site_screen.dart';
import 'admin_ajouter_equipement_formulaire_screen.dart';

class AdminAjouterEquipementScreen extends StatefulWidget {
  const AdminAjouterEquipementScreen({super.key});

  @override
  State<AdminAjouterEquipementScreen> createState() =>
      _AdminAjouterEquipementScreenState();
}

class _AdminAjouterEquipementScreenState
    extends State<AdminAjouterEquipementScreen> {
  final SheetsService _sheetsService = SheetsService();

  bool _isLoading = true;
  List<Equipement> _equipements = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
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

  void _ouvrirClientExistant(String client) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminAjouterEquipementSiteScreen(
          client: client,
          equipements: _equipements,
        ),
      ),
    );
  }

  void _ouvrirNouveauClient() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminAjouterEquipementFormulaireScreen(
          clientNouveau: true,
          siteNouveau: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Ajouter un équipement',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choisissez un client existant, ou créez un nouveau '
                      'client complet (avec son site et son équipement).',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _ouvrirNouveauClient,
                        icon: const Icon(Icons.add_business_outlined),
                        label: const Text('+ Nouveau client'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const Divider(height: 40),
                    const Text(
                      'Ou choisir un client existant',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Autocomplete<String>(
                      optionsBuilder: (value) {
                        if (value.text.isEmpty) return _clients;
                        final q = value.text.toLowerCase();
                        return _clients.where(
                          (c) => c.toLowerCase().contains(q),
                        );
                      },
                      onSelected: _ouvrirClientExistant,
                      fieldViewBuilder: (context, controller, focusNode, _) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Client',
                            hintText: 'Tapez pour rechercher...',
                            border: OutlineInputBorder(),
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 250),
                              child: ListView.builder(
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
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
