import 'package:flutter/material.dart';
import '../../../core/services/database_service.dart';
import '../../annuaire/clients/client_list_screen.dart';
import '../../annuaire/clients/client_model.dart';
import 'bi_wizard_screen.dart' show biAccent;

const List<Color> _couleursGroupes = [
  Colors.teal,
  Colors.indigo,
  Colors.orange,
  Colors.purple,
  Colors.brown,
  Colors.cyan,
  Colors.deepOrange,
  Colors.green,
];

/// Sélection du client pour un bon d'intervention — même flux Client →
/// Site, et même distinction contrat entretien / hors contrat, que le
/// Répertoire (`ClientGroupesListScreen`) et le GMAO
/// (`GmaoClientsScreen`), mais qui renvoie le site choisi au lieu
/// d'ouvrir une fiche.
class BiClientPickerScreen extends StatefulWidget {
  const BiClientPickerScreen({super.key});

  @override
  State<BiClientPickerScreen> createState() => _BiClientPickerScreenState();
}

class _BiClientPickerScreenState extends State<BiClientPickerScreen> {
  final DatabaseService _db = DatabaseService();
  String _recherche = '';
  bool _horsContrat = false;

  Future<void> _ouvrirSitesDuClient(String nom) async {
    final site = await Navigator.push<ClientModel>(
      context,
      MaterialPageRoute(
        builder: (context) => ClientListScreen(
          filterNom: nom,
          filterHorsContrat: _horsContrat,
          title: nom,
          color: biAccent,
          onClientTap: (s) => Navigator.pop(context, s),
        ),
      ),
    );
    if (site != null && mounted) Navigator.pop(context, site);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Choisir un client'),
        backgroundColor: biAccent,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _recherche = v.toLowerCase().trim()),
              decoration: InputDecoration(
                hintText: 'Rechercher un client...',
                prefixIcon: Icon(Icons.search, color: biAccent),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Contrat entretien'),
                    selected: !_horsContrat,
                    onSelected: (_) => setState(() => _horsContrat = false),
                    selectedColor: biAccent.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Hors contrat'),
                    selected: _horsContrat,
                    onSelected: (_) => setState(() => _horsContrat = true),
                    selectedColor: biAccent.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ClientModel>>(
              stream: _db.getClients(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sitesParClient = <String, List<ClientModel>>{};
                for (final s in snapshot.data!.where((s) => s.horsContrat == _horsContrat)) {
                  sitesParClient.putIfAbsent(s.nom, () => []).add(s);
                }
                final nomsTries = sitesParClient.keys
                    .where((nom) => nom.toLowerCase().contains(_recherche))
                    .toList()
                  ..sort();

                if (nomsTries.isEmpty) {
                  return Center(
                    child: Text(
                      _recherche.isEmpty ? 'Aucun client dans cette catégorie' : "Aucun résultat pour '$_recherche'",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: nomsTries.length,
                  itemBuilder: (context, index) {
                    final nom = nomsTries[index];
                    final sitesClient = sitesParClient[nom]!;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _couleursGroupes[index % _couleursGroupes.length].withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.apartment,
                            color: _couleursGroupes[index % _couleursGroupes.length],
                          ),
                        ),
                        title: Text(nom, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${sitesClient.length} site(s)', style: TextStyle(color: Colors.grey[600])),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          if (sitesClient.length == 1) {
                            Navigator.pop(context, sitesClient.first);
                            return;
                          }
                          _ouvrirSitesDuClient(nom);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
