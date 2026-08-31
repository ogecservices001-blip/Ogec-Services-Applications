import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/database_service.dart';
import '../annuaire/clients/client_list_screen.dart';
import '../annuaire/suppliers/supplier_list_screen.dart';
import '../annuaire/collaborateurs/collaborateur_list_screen.dart';
import '../cerfa/intervention/form_cerfa_screen.dart';
import '../cerfa/consultation/visualiser_equipement_screen.dart';
import '../cerfa/consultation/visualiser_bordereau_screen.dart';
import '../cerfa/services/firestore_service.dart';
import 'widgets/dashboard_grid_card.dart';
import 'widgets/dashboard_section_screen.dart';
import 'widgets/top_menu_card.dart';

class TechnicienHomeScreen extends StatefulWidget {
  const TechnicienHomeScreen({super.key});

  @override
  State<TechnicienHomeScreen> createState() => _TechnicienHomeScreenState();
}

class _TechnicienHomeScreenState extends State<TechnicienHomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final DatabaseService _db = DatabaseService();

  static const _appBarColor = Colors.black87;

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
            TopMenuCard(
              title: "Répertoire",
              icon: Icons.folder_shared_outlined,
              color: Colors.green,
              subtitle: "Clients et fournisseurs",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DashboardSectionScreen(
                    title: "Répertoire",
                    appBarColor: _appBarColor,
                    cards: _repertoireCards(context),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TopMenuCard(
              title: "CERFA",
              icon: Icons.description_outlined,
              color: Colors.blue,
              subtitle: "Interventions et consultation",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DashboardSectionScreen(
                    title: "CERFA",
                    appBarColor: _appBarColor,
                    cards: _cerfaCards(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DashboardGridCard> _cerfaCards(BuildContext context) => [
    DashboardGridCard(
      title: "Commencer nouveau CERFA",
      icon: Icons.add_circle_outline,
      color: Colors.blue,
      subtitle: "Nouvelle intervention",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => FormCerfaScreen()),
      ),
    ),
    DashboardGridCard(
      title: "Visualiser un équipement",
      icon: Icons.search,
      color: Colors.blue,
      subtitle: "Recherche",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const VisualiserEquipementScreen(),
        ),
      ),
    ),
    DashboardGridCard(
      title: "Visualiser un bordereau",
      icon: Icons.picture_as_pdf_outlined,
      color: Colors.blue,
      subtitle: "Consultation PDF",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const VisualiserBordereauScreen(),
        ),
      ),
    ),
  ];

  List<DashboardGridCard> _repertoireCards(BuildContext context) => [
    DashboardGridCard(
      title: "Clients contrat entretien",
      icon: Icons.business,
      color: Colors.green[700]!,
      countStream: _db.getClients().map(
        (list) => list.where((c) => !c.horsContrat).toList(),
      ),
      countLabel: (c) => "$c client(s)",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ClientListScreen(
            filterHorsContrat: false,
            title: "Clients contrat entretien",
          ),
        ),
      ),
    ),
    DashboardGridCard(
      title: "Clients hors contrat",
      icon: Icons.business_center_outlined,
      color: Colors.teal,
      countStream: _db.getClients().map(
        (list) => list.where((c) => c.horsContrat).toList(),
      ),
      countLabel: (c) => "$c client(s)",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ClientListScreen(
            filterHorsContrat: true,
            title: "Clients hors contrat",
          ),
        ),
      ),
    ),
    DashboardGridCard(
      title: "Fournisseurs",
      icon: Icons.local_shipping,
      color: Colors.blueGrey[700]!,
      countStream: _db.getSuppliers(),
      countLabel: (c) => "$c fournisseur(s)",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SupplierListScreen()),
      ),
    ),
    DashboardGridCard(
      title: "Collaborateurs",
      icon: Icons.badge_outlined,
      color: Colors.indigo,
      countStream: _db.getCollaborateurs(),
      countLabel: (c) => "$c collaborateur(s)",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CollaborateurListScreen(),
        ),
      ),
    ),
  ];
}
