import 'package:flutter/material.dart';
import '../models/equipement_model.dart';
import 'admin_ajouter_equipement_formulaire_screen.dart';

class AdminAjouterEquipementSiteScreen extends StatelessWidget {
  final String client;
  final List<Equipement> equipements;

  const AdminAjouterEquipementSiteScreen({
    super.key,
    required this.client,
    required this.equipements,
  });

  List<Equipement> get _equipementsDuClient =>
      equipements.where((e) => e.client == client).toList();

  List<String> get _sites =>
      _equipementsDuClient.map((e) => e.site).toSet().toList()..sort();

  void _ouvrirSiteExistant(BuildContext context, String site) {
    final exemple = _equipementsDuClient.firstWhere((e) => e.site == site);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminAjouterEquipementFormulaireScreen(
          clientNouveau: false,
          siteNouveau: false,
          clientExistant: client,
          siteExistant: site,
          equipementExemple: exemple,
        ),
      ),
    );
  }

  void _ouvrirNouveauSite(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminAjouterEquipementFormulaireScreen(
          clientNouveau: false,
          siteNouveau: true,
          clientExistant: client,
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _ouvrirNouveauSite(context),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('+ Nouveau site'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const Divider(height: 40),
              const Text(
                'Ou choisir un site existant',
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
                onSelected: (site) => _ouvrirSiteExistant(context, site),
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
