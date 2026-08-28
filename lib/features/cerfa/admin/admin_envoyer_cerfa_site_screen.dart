import 'package:flutter/material.dart';
import '../models/equipement_model.dart';
import 'admin_envoyer_cerfa_equipement_screen.dart';

class AdminEnvoyerCerfaSiteScreen extends StatelessWidget {
  final String client;
  final List<Equipement> equipements; // liste complète, non filtrée

  const AdminEnvoyerCerfaSiteScreen({
    super.key,
    required this.client,
    required this.equipements,
  });

  List<Equipement> get _equipementsDuClient =>
      equipements.where((e) => e.client == client).toList();

  List<String> get _sites {
    return _equipementsDuClient.map((e) => e.site).toSet().toList()..sort();
  }

  void _ouvrirSite(BuildContext context, String site) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminEnvoyerCerfaEquipementScreen(
          client: client,
          site: site,
          equipements: equipements,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          client,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_equipementsDuClient.length} équipement(s) pour $client',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              const Text(
                'Site',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              Autocomplete<String>(
                optionsBuilder: (value) {
                  if (value.text.isEmpty) return _sites;
                  final q = value.text.toLowerCase();
                  return _sites.where((s) => s.toLowerCase().contains(q));
                },
                onSelected: (site) => _ouvrirSite(context, site),
                fieldViewBuilder: (context, controller, focusNode, _) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Site',
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
