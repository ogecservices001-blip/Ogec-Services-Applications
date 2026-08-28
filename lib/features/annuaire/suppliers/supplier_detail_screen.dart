import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'supplier_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/user_service.dart';
import 'edit_supplier_screen.dart';

class SupplierDetailScreen extends StatefulWidget {
  final SupplierModel supplier;

  const SupplierDetailScreen({super.key, required this.supplier});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
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
        title: const Text('Fiche Fournisseur'),
        backgroundColor: Colors.blueGrey[800],
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
                        builder: (context) =>
                            EditSupplierScreen(supplier: widget.supplier),
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
              color: Colors.blueGrey[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_shipping,
                      size: 50,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.supplier.nom,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.supplier.denominationCourte.isNotEmpty)
                            Text(
                              widget.supplier.denominationCourte,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.blueGrey[600],
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
            _buildSectionTitle("Expertise & Produits"),
            _buildInfoTile(
              Icons.inventory_2,
              "Produits Clés",
              widget.supplier.produitsCles,
            ),
            _buildInfoTile(
              Icons.comment,
              "Remarques",
              widget.supplier.remarques,
            ),
            const Divider(height: 32),
            _buildSectionTitle("Localisation"),
            _buildInfoTile(
              Icons.location_on,
              "Adresse",
              widget.supplier.adresse,
            ),
            _buildInfoTile(
              Icons.add_location,
              "Complément d'adresse",
              widget.supplier.complementAdresse,
            ),
            _buildInfoTile(
              Icons.map,
              "Ville",
              "${widget.supplier.codePostal} ${widget.supplier.commune}",
            ),
            const Divider(height: 32),
            _buildSectionTitle("Contact & Communication"),
            _buildInfoTile(
              Icons.people,
              "Interlocuteurs",
              widget.supplier.interlocuteurs,
            ),
            _buildInfoTile(
              Icons.phone,
              "Téléphone Fixe",
              widget.supplier.tel,
              onTap: widget.supplier.tel.isNotEmpty
                  ? () => _launchURL("tel:${widget.supplier.tel}")
                  : null,
            ),
            _buildInfoTile(
              Icons.phone_android,
              "Portable",
              widget.supplier.portable,
              onTap: widget.supplier.portable.isNotEmpty
                  ? () => _launchURL("tel:${widget.supplier.portable}")
                  : null,
            ),
            _buildInfoTile(
              Icons.email,
              "Courriel",
              widget.supplier.courriel,
              onTap: widget.supplier.courriel.isNotEmpty
                  ? () => _launchURL("mailto:${widget.supplier.courriel}")
                  : null,
            ),
            _buildInfoTile(
              Icons.language,
              "Site Web",
              widget.supplier.siteWeb,
              onTap: widget.supplier.siteWeb.isNotEmpty
                  ? () => _launchURL(widget.supplier.siteWeb)
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
      builder: (ctx) => AlertDialog(
        title: const Text("Suppression"),
        content: Text(
          "Voulez-vous supprimer définitivement ${widget.supplier.nom} ?",
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
                await _db.deleteSupplier(widget.supplier.id);

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
          color: Colors.blueGrey,
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
      leading: Icon(icon, color: Colors.blueGrey[600]),
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
