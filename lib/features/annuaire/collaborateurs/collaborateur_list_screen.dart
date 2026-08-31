import 'package:flutter/material.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/user_service.dart';
import 'collaborateur_model.dart';
import 'collaborateur_detail_screen.dart';
import 'add_collaborateur_screen.dart';

class CollaborateurListScreen extends StatefulWidget {
  const CollaborateurListScreen({super.key});

  @override
  State<CollaborateurListScreen> createState() =>
      _CollaborateurListScreenState();
}

class _CollaborateurListScreenState extends State<CollaborateurListScreen> {
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
        title: const Text('Collaborateurs'),
        backgroundColor: Colors.indigo[700],
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
                hintText: 'Rechercher un nom ou une commune...',
                prefixIcon: const Icon(Icons.search, color: Colors.indigo),
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
      body: StreamBuilder<List<CollaborateurModel>>(
        stream: _db.getCollaborateurs(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text("Erreur de chargement des collaborateurs"),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.indigo),
            );
          }

          final allCollaborateurs = snapshot.data ?? [];
          final filtered = allCollaborateurs.where((c) {
            final query = _searchQuery.toLowerCase();
            return c.nomComplet.toLowerCase().contains(query) ||
                c.communeHabitation.toLowerCase().contains(query);
          }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.badge_outlined, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    "Aucun collaborateur trouvé",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: filtered.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final collaborateur = filtered[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo[100],
                    child: const Icon(Icons.badge, color: Colors.indigo),
                  ),
                  title: Text(
                    collaborateur.nomComplet,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    collaborateur.communeHabitation.isNotEmpty
                        ? collaborateur.communeHabitation
                        : "Non renseigné",
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CollaborateurDetailScreen(
                          collaborateur: collaborateur,
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
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddCollaborateurScreen(),
                  ),
                );
              },
              backgroundColor: Colors.indigo[700],
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
