import 'package:flutter/material.dart';
import 'client_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/user_service.dart';
import '../../home/widgets/top_menu_card.dart';
import 'client_field_group.dart';
import 'client_group_detail_screen.dart';
import 'edit_client_screen.dart';
import '../../gmao/equipements/client_equipements_list_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final ClientModel client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final DatabaseService _db = DatabaseService();
  final UserService _userService = UserService();

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
    final visibleGroups = clientFieldGroups
        .where((g) => !g.adminOnly || _isAdmin)
        .toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Fiche Client'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: _isAdmin
            ? [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: "Modifier ce client",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditClientScreen(client: widget.client),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever),
                  tooltip: "Supprimer ce client",
                  onPressed: _confirmDelete,
                ),
              ]
            : [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.green[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.business, size: 50, color: Colors.green),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.client.nom,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            widget.client.site,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TopMenuCard(
              title: 'Parc GMAO',
              icon: Icons.precision_manufacturing_outlined,
              color: Colors.teal,
              subtitle: "Équipements et relevés d'entretien",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ClientEquipementsListScreen(
                    client: widget.client,
                    readOnly: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final group in visibleGroups) ...[
              TopMenuCard(
                title: group.title,
                icon: group.icon,
                color: group.color,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClientGroupDetailScreen(
                      group: group,
                      client: widget.client,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Suppression"),
        content: Text("Voulez-vous supprimer le client ${widget.client.nom} ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("ANNULER"),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final dialogNavigator = Navigator.of(dialogContext);
              final messenger = ScaffoldMessenger.of(context);

              try {
                await _db.deleteClient(widget.client.id);

                if (!mounted) return;

                dialogNavigator.pop();
                navigator.pop();
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(content: Text("Erreur : $e")));
              }
            },
            child: const Text("SUPPRIMER", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
