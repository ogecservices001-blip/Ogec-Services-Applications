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
  final String title;
  final Color color;

  /// Si fourni, remplace la navigation par défaut vers [ClientDetailScreen]
  /// (ex: pour ouvrir directement le parc GMAO d'un client au lieu de sa
  /// fiche complète).
  final void Function(ClientModel client)? onClientTap;

  const ClientListScreen({
    super.key,
    this.filterHorsContrat,
    this.filterNom,
    this.title = 'Répertoire Clients',
    this.color = Colors.green,
    this.onClientTap,
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
                  subtitle: Text("${client.nom} - ${client.commune}"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
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
