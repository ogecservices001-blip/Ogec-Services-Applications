import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../annuaire/clients/client_list_screen.dart';
import '../annuaire/suppliers/supplier_list_screen.dart';
import '../cerfa/intervention/form_cerfa_screen.dart';
import '../cerfa/consultation/visualiser_equipement_screen.dart';
import '../cerfa/consultation/visualiser_bordereau_screen.dart';
import '../cerfa/services/firestore_service.dart';

class TechnicienHomeScreen extends StatefulWidget {
  const TechnicienHomeScreen({super.key});

  @override
  State<TechnicienHomeScreen> createState() => _TechnicienHomeScreenState();
}

class _TechnicienHomeScreenState extends State<TechnicienHomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoadingNom = true;
  String? _nomTechnicien;

  @override
  void initState() {
    super.initState();
    _chargerNomTechnicien();
  }

  Future<void> _chargerNomTechnicien() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoadingNom = false);
      return;
    }
    try {
      final tech = await _firestoreService.getTechnicien(uid);
      setState(() {
        _nomTechnicien = (tech != null && tech['nom']!.isNotEmpty)
            ? tech['nom']
            : null;
        _isLoadingNom = false;
      });
    } catch (e) {
      setState(() => _isLoadingNom = false);
    }
  }

  String get _titreAppBar {
    if (_isLoadingNom || _nomTechnicien == null) return 'OGEC SERVICES';
    final parts = _nomTechnicien!.trim().split(' ');
    final prenomAffiche = parts.length > 1 ? parts.last : _nomTechnicien!;
    return 'OGEC SERVICES - $prenomAffiche';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          _titreAppBar,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black87,
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
            _buildSectionTitle("CERFA"),
            _buildActionTile(
              "Commencer nouveau CERFA",
              Icons.add_circle_outline,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FormCerfaScreen()),
              ),
            ),
            _buildActionTile(
              "Visualiser un équipement",
              Icons.search,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VisualiserEquipementScreen(),
                ),
              ),
            ),
            _buildActionTile(
              "Visualiser un bordereau",
              Icons.picture_as_pdf_outlined,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VisualiserBordereauScreen(),
                ),
              ),
            ),

            _buildSectionTitle("Répertoire"),
            _buildActionTile(
              "Répertoire Clients",
              Icons.business,
              Colors.green[700]!,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ClientListScreen(),
                ),
              ),
            ),
            _buildActionTile(
              "Répertoire Fournisseurs",
              Icons.local_shipping,
              Colors.blueGrey[700]!,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SupplierListScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
