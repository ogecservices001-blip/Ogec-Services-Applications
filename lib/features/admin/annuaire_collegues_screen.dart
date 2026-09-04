import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/user_service.dart';

/// Annuaire des collègues (coordonnées), en lecture seule — pour que
/// n'importe qui (admin ou technicien) puisse retrouver le numéro/email
/// d'un collègue, sans passer par "Gestion Utilisateurs" (réservée à
/// l'admin, qui permet aussi de modifier rôle/compte). Alimenté par la
/// même collection `users` : une seule source de données, deux écrans.
class AnnuaireColleguesScreen extends StatefulWidget {
  const AnnuaireColleguesScreen({super.key});

  @override
  State<AnnuaireColleguesScreen> createState() =>
      _AnnuaireColleguesScreenState();
}

class _AnnuaireColleguesScreenState extends State<AnnuaireColleguesScreen> {
  final UserService _userService = UserService();
  String _searchQuery = "";

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
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
        title: const Text('Collaborateurs'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase().trim()),
              decoration: InputDecoration(
                hintText: 'Rechercher un nom...',
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _userService.getUsers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.indigo),
            );
          }

          final all = snapshot.data!.docs;
          final filtered = all.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery);
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
              final data = filtered[index].data() as Map<String, dynamic>;
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
                    data['name'] ?? 'Sans nom',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    (data['qualite'] ?? '').toString().isNotEmpty
                        ? data['qualite']
                        : (data['communeHabitation'] ?? '').toString(),
                  ),
                  trailing: (data['portable'] ?? '').toString().isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.phone, color: Colors.indigo),
                          onPressed: () => _launchURL('tel:${data['portable']}'),
                        )
                      : null,
                  onTap: () => _showDetail(context, data),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['name'] ?? 'Sans nom',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if ((data['qualite'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  data['qualite'],
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            const SizedBox(height: 16),
            _detailRow(Icons.phone_android, 'Portable', data['portable']),
            _detailRow(Icons.email_outlined, 'Email OGEC', data['email']),
            _detailRow(
              Icons.alternate_email,
              'Email personnel',
              data['emailPerso'],
            ),
            _detailRow(
              Icons.location_on_outlined,
              "Commune d'habitation",
              data['communeHabitation'],
            ),
            _detailRow(
              Icons.directions_car_outlined,
              'Véhicule',
              data['vehicule'],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, dynamic value) {
    final v = (value ?? '').toString();
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.indigo[400]),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const Spacer(),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
