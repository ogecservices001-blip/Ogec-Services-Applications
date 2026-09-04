import 'package:flutter/material.dart';
import '../../core/services/database_service.dart';
import '../../core/services/user_service.dart';
import '../annuaire/clients/client_model.dart';
import '../annuaire/clients/client_list_screen.dart';
import 'equipements/client_equipements_list_screen.dart';
import 'equipements/equipement_export_service.dart';
import 'gmao_database_service.dart';

/// Point d'entrée GMAO : regroupe les sites par client (même champ
/// `nom`, sans nouvelle collection — un client "physique" a souvent
/// plusieurs sites, chacun étant aujourd'hui un document séparé), pour
/// un statut de contrat donné. Tape un client → liste de ses sites →
/// parc d'un site (groupé par Groupe).
class GmaoClientsScreen extends StatefulWidget {
  /// true : uniquement les sites hors contrat (N°Affaire "362-"). false :
  /// uniquement les sites en contrat entretien.
  final bool filterHorsContrat;
  final String title;
  final Color color;

  const GmaoClientsScreen({
    super.key,
    required this.filterHorsContrat,
    required this.title,
    this.color = Colors.teal,
  });

  @override
  State<GmaoClientsScreen> createState() => _GmaoClientsScreenState();
}

class _GmaoClientsScreenState extends State<GmaoClientsScreen> {
  final DatabaseService _db = DatabaseService();
  final UserService _userService = UserService();
  final GmaoDatabaseService _gmaoDb = GmaoDatabaseService();
  String _recherche = '';
  bool _isAdmin = false;
  String? _exportEnCours;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final isAdmin = await _userService.isCurrentUserAdmin();
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  Future<void> _exporterTousLesSites(
    String nomClient,
    List<ClientModel> sitesClient,
  ) async {
    setState(() => _exportEnCours = nomClient);
    try {
      final types = await _gmaoDb.getTypesEquipement().first;
      final typesById = {for (final t in types) t.id: t};

      final lignes = <EquipementAvecSite>[];
      for (final site in sitesClient) {
        final equipements = await _gmaoDb
            .getEquipementsForClient(site.id)
            .first;
        lignes.addAll(
          equipements.map((eq) => EquipementAvecSite(eq, site)),
        );
      }

      EquipementExportService().exporter(
        lignes: lignes,
        typesById: typesById,
        nomFichier: '${nomClient}_tous_sites_equipements.xlsx',
      );
    } finally {
      if (mounted) setState(() => _exportEnCours = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _recherche = v.toLowerCase().trim()),
              decoration: InputDecoration(
                hintText: 'Rechercher un client...',
                prefixIcon: Icon(Icons.search, color: widget.color),
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
      body: StreamBuilder<List<ClientModel>>(
        stream: _db.getClients(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final sites = snapshot.data!
              .where((s) => s.horsContrat == widget.filterHorsContrat)
              .toList();

          final sitesParClient = <String, List<ClientModel>>{};
          for (final s in sites) {
            sitesParClient.putIfAbsent(s.nom, () => []).add(s);
          }
          final nomsTries = sitesParClient.keys
              .where((nom) => nom.toLowerCase().contains(_recherche))
              .toList()
            ..sort();

          if (nomsTries.isEmpty) {
            return Center(
              child: Text(
                _recherche.isEmpty
                    ? 'Aucun client dans cette catégorie'
                    : "Aucun résultat pour '$_recherche'",
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.apartment, color: widget.color),
                  ),
                  title: Text(
                    nom,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${sitesClient.length} site(s)',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isAdmin)
                        _exportEnCours == nom
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.download),
                                tooltip:
                                    'Exporter tous les équipements de ce client',
                                onPressed: () =>
                                    _exporterTousLesSites(nom, sitesClient),
                              ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    if (sitesClient.length == 1) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ClientEquipementsListScreen(
                            client: sitesClient.first,
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ClientListScreen(
                          filterNom: nom,
                          filterHorsContrat: widget.filterHorsContrat,
                          title: nom,
                          color: widget.color,
                          onClientTap: (site) => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ClientEquipementsListScreen(client: site),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
