import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'collaborateur_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/user_service.dart';
import 'edit_collaborateur_screen.dart';

class CollaborateurDetailScreen extends StatefulWidget {
  final CollaborateurModel collaborateur;

  const CollaborateurDetailScreen({super.key, required this.collaborateur});

  @override
  State<CollaborateurDetailScreen> createState() =>
      _CollaborateurDetailScreenState();
}

class _CollaborateurDetailScreenState
    extends State<CollaborateurDetailScreen> {
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

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Impossible de lancer $url';
      }
    } catch (e) {
      debugPrint("Erreur de lien : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiche Collaborateur'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        actions: _isAdmin
            ? [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: "Modifier",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditCollaborateurScreen(
                          collaborateur: widget.collaborateur,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever),
                  tooltip: "Supprimer",
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
              color: Colors.indigo[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.badge, size: 50, color: Colors.indigo),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.collaborateur.nomComplet,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle("Contact"),
            _buildInfoTile(
              Icons.phone_android,
              "Portable",
              widget.collaborateur.portable,
              onTap: widget.collaborateur.portable.isNotEmpty
                  ? () => _launchURL("tel:${widget.collaborateur.portable}")
                  : null,
            ),
            _buildInfoTile(
              Icons.email,
              "Email OGEC Services",
              widget.collaborateur.emailOgec,
              onTap: widget.collaborateur.emailOgec.isNotEmpty
                  ? () => _launchURL("mailto:${widget.collaborateur.emailOgec}")
                  : null,
            ),
            _buildInfoTile(
              Icons.alternate_email,
              "Email personnel",
              widget.collaborateur.emailPerso,
              onTap: widget.collaborateur.emailPerso.isNotEmpty
                  ? () =>
                        _launchURL("mailto:${widget.collaborateur.emailPerso}")
                  : null,
            ),
            const Divider(height: 32),
            _buildSectionTitle("Autres informations"),
            _buildInfoTile(
              Icons.location_on,
              "Commune d'habitation",
              widget.collaborateur.communeHabitation,
            ),
            _buildInfoTile(
              Icons.directions_car,
              "Véhicule",
              widget.collaborateur.vehicule,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Suppression"),
        content: Text(
          "Voulez-vous supprimer définitivement ${widget.collaborateur.nomComplet} ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ANNULER"),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              try {
                await _db.deleteCollaborateur(widget.collaborateur.id);

                if (!mounted) return;

                navigator.pop();
                navigator.pop();
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text("Erreur lors de la suppression : $e")),
                );
              }
            },
            child: const Text("SUPPRIMER", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.indigo,
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    String displayValue = (value.isEmpty || value == "null")
        ? "Non renseigné"
        : value;

    return ListTile(
      leading: Icon(icon, color: Colors.indigo[600]),
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Text(
        displayValue,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      trailing: onTap != null
          ? const Icon(Icons.open_in_new, size: 18, color: Colors.blue)
          : null,
      onTap: onTap,
    );
  }
}
