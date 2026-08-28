import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'client_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/user_service.dart';
import 'edit_client_screen.dart';

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

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      debugPrint("Impossible de lancer $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                            "Clients : ${widget.client.nom}",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            "Sites : ${widget.client.site}",
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
            _buildSectionTitle("Dossier"),
            _buildInfoTile(Icons.tag, "N° d'Affaire", widget.client.nAffaire),
            const Divider(height: 32),
            _buildSectionTitle("Localisation"),
            _buildInfoTile(
              Icons.mark_as_unread,
              "Code Postal",
              widget.client.codePostal,
            ),
            _buildInfoTile(
              Icons.location_city,
              "Commune",
              widget.client.commune,
            ),
            _buildInfoTile(Icons.location_on, "Adresse", widget.client.adresse),
            _buildInfoTile(
              Icons.add_location,
              "Complément d'adresse",
              widget.client.complementAdresse,
            ),
            const Divider(height: 32),
            _buildSectionTitle("Responsable Contrat"),
            _buildInfoTile(
              Icons.person,
              "Nom",
              widget.client.responsableContrat,
            ),
            _buildInfoTile(
              Icons.phone,
              "Téléphone Fixe",
              widget.client.telFixeResponsable,
              onTap: widget.client.telFixeResponsable.isNotEmpty
                  ? () => _launchURL("tel:${widget.client.telFixeResponsable}")
                  : null,
            ),
            _buildInfoTile(
              Icons.phone_android,
              "Portable",
              widget.client.portableResponsable,
              onTap: widget.client.portableResponsable.isNotEmpty
                  ? () => _launchURL("tel:${widget.client.portableResponsable}")
                  : null,
            ),
            _buildInfoTile(
              Icons.email,
              "Courriel",
              widget.client.courrielResponsable,
              onTap: widget.client.courrielResponsable.isNotEmpty
                  ? () => _launchURL(
                      "mailto:${widget.client.courrielResponsable}",
                    )
                  : null,
            ),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.green,
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
    String displayValue = (value.trim().isEmpty || value == "null")
        ? "Non renseigné"
        : value;
    return ListTile(
      leading: Icon(icon, color: Colors.green[600]),
      title: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
      subtitle: Text(
        displayValue,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      trailing: onTap != null
          ? const Icon(Icons.open_in_new, size: 18, color: Colors.blue)
          : null,
      onTap: onTap,
    );
  }
}
