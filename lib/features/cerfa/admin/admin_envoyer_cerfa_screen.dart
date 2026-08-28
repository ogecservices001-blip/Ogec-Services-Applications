import 'package:flutter/material.dart';
import '../models/equipement_model.dart';
import '../services/sheets_service.dart';
import 'admin_envoyer_cerfa_site_screen.dart';

class AdminEnvoyerCerfaScreen extends StatefulWidget {
  const AdminEnvoyerCerfaScreen({super.key});

  @override
  State<AdminEnvoyerCerfaScreen> createState() =>
      _AdminEnvoyerCerfaScreenState();
}

class _AdminEnvoyerCerfaScreenState extends State<AdminEnvoyerCerfaScreen> {
  final SheetsService _sheetsService = SheetsService();

  bool _isLoadingEquipements = true;
  List<Equipement> _equipements = [];

  @override
  void initState() {
    super.initState();
    _chargerEquipements();
  }

  Future<void> _chargerEquipements() async {
    setState(() => _isLoadingEquipements = true);
    try {
      final data = await _sheetsService.getEquipements();
      setState(() {
        _equipements = data;
        _isLoadingEquipements = false;
      });
    } catch (e) {
      setState(() => _isLoadingEquipements = false);
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

  void _ouvrirClient(String client) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminEnvoyerCerfaSiteScreen(
          client: client,
          equipements: _equipements,
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
          'Envoyer un CERFA déjà rempli',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoadingEquipements
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choisissez un client, puis un site, puis '
                      'l\'équipement dont vous voulez envoyer le CERFA.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Client',
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
                      onSelected: _ouvrirClient,
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
