import 'package:flutter/material.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/user_service.dart';
import 'client_model.dart';
import 'client_detail_screen.dart';
import 'add_client_screen.dart';

class ClientListScreen extends StatefulWidget {
  /// null : tous les clients. true : uniquement les clients hors contrat
  /// (N°Affaire commençant par "362-"). false : uniquement les clients en
  /// contrat entretien.
  final bool? filterHorsContrat;

  /// Si fourni, ne montre que les sites dont le nom client correspond
  /// exactement (ex: liste des sites d'un client donné, regroupement
  /// GMAO Client → Site).
  final String? filterNom;

  /// Si fourni, ne montre que les clients/sites dont l'id figure dans cet
  /// ensemble (ex: Travaux Clients ne propose, pour un client multi-sites,
  /// que les sites ayant déjà une affaire de la nature en cours — sans ce
  /// filtre, tous les sites du client apparaîtraient ici même ceux sans
  /// affaire correspondante, menant à un écran suivant vide).
  final Set<String>? filterIds;
  final String title;
  final Color color;

  /// Si fourni, remplace la navigation par défaut vers [ClientDetailScreen]
  /// (ex: pour ouvrir directement le parc GMAO d'un client au lieu de sa
  /// fiche complète).
  final void Function(ClientModel client)? onClientTap;

  /// Si fourni, affiche une icône de suppression (admin) sur chaque
  /// ligne — le sens de "supprimer" dépend de l'appelant (ex: vider le
  /// parc GMAO de ce site, ou supprimer sa fiche Répertoire).
  final Future<void> Function(ClientModel client)? onDeleteTap;

  /// Si fourni, ajoute une ligne sous le sous-titre habituel (ex:
  /// "3 affaire(s)" pour Travaux Clients) — calculé synchrone par
  /// l'appelant, pas de nouvelle requête ici.
  final String? Function(ClientModel client)? countLabel;

  const ClientListScreen({
    super.key,
    this.filterHorsContrat,
    this.filterNom,
    this.filterIds,
    this.title = 'Répertoire Clients',
    this.color = Colors.green,
    this.onClientTap,
    this.onDeleteTap,
    this.countLabel,
  });

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  final DatabaseService _db = DatabaseService();
  final UserService _userService = UserService();
  String _searchQuery = "";
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final isAdmin = await _userService.isCurrentUserAdmin();
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase().trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Rechercher un site ou une ville...',
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
          if (snapshot.hasError) {
            return const Center(child: Text("Erreur de connexion à Firebase"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: widget.color),
            );
          }

          final allClients = snapshot.data ?? [];

          final filtered = allClients.where((client) {
            if (widget.filterHorsContrat != null &&
                client.horsContrat != widget.filterHorsContrat) {
              return false;
            }
            if (widget.filterNom != null && client.nom != widget.filterNom) {
              return false;
            }
            if (widget.filterIds != null && !widget.filterIds!.contains(client.id)) {
              return false;
            }
            final query = _searchQuery.toLowerCase();
            return client.nom.toLowerCase().contains(query) ||
                client.site.toLowerCase().contains(query) ||
                client.commune.toLowerCase().contains(query);
          }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.business_center_outlined,
                    size: 60,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? "Aucun client dans la base"
                        : "Aucun résultat pour '$_searchQuery'",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: filtered.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final client = filtered[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: widget.color,
                    child: const Icon(Icons.business, color: Colors.white),
                  ),
                  title: Text(
                    client.site,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("${client.nom} - ${client.commune}"),
                      if (widget.countLabel != null && widget.countLabel!(client) != null)
                        Text(
                          widget.countLabel!(client)!,
                          style: TextStyle(fontSize: 12, color: widget.color),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isAdmin && widget.onDeleteTap != null)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () => widget.onDeleteTap!(client),
                        ),
                      const Icon(Icons.arrow_forward_ios, size: 14),
                    ],
                  ),
                  onTap: () {
                    if (widget.onClientTap != null) {
                      widget.onClientTap!(client);
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ClientDetailScreen(client: client),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddClientScreen(),
                  ),
                );
              },
              backgroundColor: widget.color,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
