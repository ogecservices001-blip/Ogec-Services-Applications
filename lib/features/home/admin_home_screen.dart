import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/database_service.dart';
import '../../core/services/user_service.dart';
import '../annuaire/clients/client_list_screen.dart';
import '../annuaire/suppliers/supplier_list_screen.dart';
import '../admin/user_management_screen.dart';
import '../admin/admin_tools_screen.dart';
import '../cerfa/admin/admin_cerfa_status_screen.dart';
import '../cerfa/admin/admin_creer_modele_screen.dart';
import '../cerfa/admin/admin_envoyer_cerfa_screen.dart';
import '../cerfa/admin/admin_ajouter_equipement_screen.dart';
import '../cerfa/admin/admin_verifier_dossiers_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final DatabaseService _db = DatabaseService();
  final UserService _userService = UserService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('OGEC SERVICES - Admin'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async => await FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tableau de bord",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                _buildStatCard("Clients", _db.getClients(), Colors.green),
                const SizedBox(width: 8),
                _buildStatCard(
                  "Fournisseurs",
                  _db.getSuppliers(),
                  Colors.blueGrey,
                ),
                const SizedBox(width: 8),
                _buildStatCard(
                  "Utilisateurs",
                  _userService.getUsers().map((snap) => snap.docs),
                  Colors.purple,
                ),
              ],
            ),

            _buildSectionTitle("CERFA"),
            _buildActionTile(
              "Point sur les CERFA",
              Icons.pie_chart_outline,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminCerfaStatusScreen(),
                ),
              ),
            ),
            _buildActionTile(
              "Créer modèle CERFA",
              Icons.note_add_outlined,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminCreerModeleScreen(),
                ),
              ),
            ),
            _buildActionTile(
              "Envoyer un CERFA rempli",
              Icons.send_outlined,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminEnvoyerCerfaScreen(),
                ),
              ),
            ),
            _buildActionTile(
              "Ajouter un équipement",
              Icons.add_circle_outline,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminAjouterEquipementScreen(),
                ),
              ),
            ),
            _buildActionTile(
              "Vérifier les dossiers clients",
              Icons.warning_amber_outlined,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminVerifierDossiersScreen(),
                ),
              ),
            ),

            _buildSectionTitle("Répertoire"),
            _buildActionTile(
              "Gérer les Clients",
              Icons.business,
              Colors.green,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ClientListScreen(),
                ),
              ),
            ),
            _buildActionTile(
              "Gérer les Fournisseurs",
              Icons.local_shipping,
              Colors.blueGrey,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SupplierListScreen(),
                ),
              ),
            ),

            _buildSectionTitle("Administration"),
            _buildActionTile(
              "Gérer les Utilisateurs",
              Icons.people,
              Colors.purple,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserManagementScreen(),
                ),
              ),
            ),
            _buildActionTile(
              "Outils de Données (CSV)",
              Icons.settings_suggest,
              Colors.orange,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminToolsScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 30, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    Stream<List<dynamic>> stream,
    Color color,
  ) {
    return Expanded(
      child: StreamBuilder<List<dynamic>>(
        stream: stream,
        builder: (context, snapshot) {
          int count = snapshot.data?.length ?? 0;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border(left: BorderSide(color: color, width: 5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "$count",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
