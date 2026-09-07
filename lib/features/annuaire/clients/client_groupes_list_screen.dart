import 'package:flutter/material.dart';
import '../../../core/services/csv_import_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/repertoire_export_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import 'client_detail_screen.dart';
import 'client_list_screen.dart';
import 'client_model.dart';

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

/// Répertoire : regroupe les sites par client (même champ `nom`, sans
/// nouvelle collection — miroir de [GmaoClientsScreen]) pour un statut
/// de contrat donné. Tape une étiquette → fiche du site (un seul) ou
/// liste de ses sites (plusieurs). Import/export/suppression par
/// étiquette réservés à l'admin.
class ClientGroupesListScreen extends StatefulWidget {
  final bool? filterHorsContrat;
  final String title;
  final Color color;

  const ClientGroupesListScreen({
    super.key,
    this.filterHorsContrat,
    this.title = 'Répertoire Clients',
    this.color = Colors.green,
  });

  @override
  State<ClientGroupesListScreen> createState() =>
      _ClientGroupesListScreenState();
}

class _ClientGroupesListScreenState extends State<ClientGroupesListScreen> {
  final DatabaseService _db = DatabaseService();
  final CsvImportService _csvImportService = CsvImportService();
  final RepertoireExportService _exportService = RepertoireExportService();
  final UserService _userService = UserService();
  String _recherche = '';
  bool _isAdmin = false;
  String? _actionEnCours;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final isAdmin = await _userService.isCurrentUserAdmin();
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  Future<void> _importerPourClient(String nom) async {
    setState(() => _actionEnCours = 'import-$nom');
    try {
      await _csvImportService.importClients(filterNom: nom);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import terminé pour $nom')),
      );
    } finally {
      if (mounted) setState(() => _actionEnCours = null);
    }
  }

  void _exporterPourClient(String nom, List<ClientModel> sitesClient) {
    _exportService.exporterClients(sitesClient, '${nom}_sites.xlsx');
  }

  Future<void> _supprimerPourClient(
    String nom,
    List<ClientModel> sitesClient,
  ) async {
    final confirme = await confirmerSuppressionMasse(
      context: context,
      titre: 'Supprimer $nom du Répertoire',
      message:
          'Supprime la fiche Répertoire de tous les sites de "$nom" '
          '(${sitesClient.length} site(s)) — action irréversible. '
          "N'affecte pas les équipements GMAO déjà enregistrés.",
      motConfirmation: nom,
    );
    if (!confirme || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    await _db.deleteClients(sitesClient.map((s) => s.id).toList());
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('$nom supprimé')));
  }

  /// Supprime la fiche Répertoire d'un seul site — depuis le sous-menu
  /// (liste des sites d'un client à plusieurs sites).
  Future<void> _supprimerSite(BuildContext context, ClientModel site) async {
    final label = [
      site.nom,
      site.site,
    ].where((s) => s.isNotEmpty).join(' — ');
    final confirme = await confirmerSuppression(
      context: context,
      titre: 'Supprimer ce site',
      message: 'Supprime la fiche Répertoire de "$label" — action irréversible.',
    );
    if (!confirme || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    await _db.deleteClient(site.id);
    messenger.showSnackBar(SnackBar(content: Text('$label supprimé')));
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
              onChanged: (v) =>
                  setState(() => _recherche = v.toLowerCase().trim()),
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
              .where(
                (s) =>
                    widget.filterHorsContrat == null ||
                    s.horsContrat == widget.filterHorsContrat,
              )
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
                      color:
                          _couleursGroupes[index % _couleursGroupes.length]
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.apartment,
                      color: _couleursGroupes[index % _couleursGroupes.length],
                    ),
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
                        _actionEnCours == 'import-$nom'
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.upload_file),
                                tooltip:
                                    'Rafraîchir ce client depuis le fichier maître',
                                onPressed: () => _importerPourClient(nom),
                              ),
                      if (_isAdmin)
                        IconButton(
                          icon: const Icon(Icons.download),
                          tooltip: 'Exporter les sites de ce client',
                          onPressed: () =>
                              _exporterPourClient(nom, sitesClient),
                        ),
                      if (_isAdmin)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          tooltip: 'Supprimer ce client du Répertoire',
                          onPressed: () =>
                              _supprimerPourClient(nom, sitesClient),
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    if (sitesClient.length == 1) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ClientDetailScreen(client: sitesClient.first),
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
                          onDeleteTap: (site) =>
                              _supprimerSite(context, site),
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
