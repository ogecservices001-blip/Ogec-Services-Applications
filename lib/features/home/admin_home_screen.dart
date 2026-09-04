import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/database_service.dart';
import '../../core/services/user_service.dart';
import '../../core/services/update_service.dart';
import '../annuaire/clients/client_list_screen.dart';
import '../annuaire/clients/client_model.dart';
import '../annuaire/suppliers/supplier_list_screen.dart';
import '../admin/user_management_screen.dart';
import '../admin/admin_tools_screen.dart';
import '../admin/annuaire_collegues_screen.dart';
import '../cerfa/admin/admin_cerfa_status_screen.dart';
import '../cerfa/admin/admin_creer_modele_screen.dart';
import '../cerfa/admin/admin_envoyer_cerfa_screen.dart';
import '../cerfa/admin/admin_ajouter_equipement_screen.dart';
import '../cerfa/admin/admin_verifier_dossiers_screen.dart';
import '../cerfa/intervention/form_cerfa_screen.dart';
import '../cerfa/consultation/visualiser_equipement_screen.dart';
import '../cerfa/consultation/visualiser_bordereau_screen.dart';
import '../gmao/types_equipement/types_equipement_list_screen.dart';
import '../gmao/references_horaires/references_horaires_list_screen.dart';
import '../gmao/gmao_home_screen.dart';
import 'widgets/dashboard_grid_card.dart';
import 'widgets/dashboard_section_screen.dart';
import 'widgets/top_menu_card.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final DatabaseService _db = DatabaseService();
  final UserService _userService = UserService();

  static const _appBarColor = Color(0xFF0D47A1); // Colors.blue[900]

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService().verifierEtProposer(context);
    });
  }

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

            TopMenuCard(
              title: "GMAO",
              icon: Icons.precision_manufacturing_outlined,
              color: Colors.teal,
              subtitle: "Parc équipements et relevés d'entretien",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GmaoHomeScreen()),
              ),
            ),
            const SizedBox(height: 12),
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
              subtitle: "Modèles, envois, équipements, vérifications",
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
            const SizedBox(height: 12),
            TopMenuCard(
              title: "Administration utilisateur",
              icon: Icons.admin_panel_settings_outlined,
              color: Colors.purple,
              subtitle: "Utilisateurs et outils de données",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DashboardSectionScreen(
                    title: "Administration utilisateur",
                    appBarColor: _appBarColor,
                    cards: _administrationCards(context),
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
      color: Colors.green,
      subtitle: "Nouvelle intervention",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => FormCerfaScreen()),
      ),
    ),
    DashboardGridCard(
      title: "Visualiser un équipement",
      icon: Icons.search,
      color: Colors.green,
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
      color: Colors.green,
      subtitle: "Consultation PDF",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const VisualiserBordereauScreen(),
        ),
      ),
    ),
    DashboardGridCard(
      title: "Point sur les CERFA",
      icon: Icons.pie_chart_outline,
      color: Colors.blue,
      subtitle: "Vue d'ensemble",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AdminCerfaStatusScreen(),
        ),
      ),
    ),
    DashboardGridCard(
      title: "Créer modèle CERFA",
      icon: Icons.note_add_outlined,
      color: Colors.blue,
      subtitle: "Nouveau modèle",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AdminCreerModeleScreen(),
        ),
      ),
    ),
    DashboardGridCard(
      title: "Envoyer un CERFA rempli",
      icon: Icons.send_outlined,
      color: Colors.blue,
      subtitle: "Par email",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AdminEnvoyerCerfaScreen(),
        ),
      ),
    ),
    DashboardGridCard(
      title: "Ajouter un équipement",
      icon: Icons.add_circle_outline,
      color: Colors.blue,
      subtitle: "Nouveau site/équipement",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AdminAjouterEquipementScreen(),
        ),
      ),
    ),
    DashboardGridCard(
      title: "Vérifier les dossiers clients",
      icon: Icons.warning_amber_outlined,
      color: Colors.blue,
      subtitle: "Contrôle qualité",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AdminVerifierDossiersScreen(),
        ),
      ),
    ),
  ];

  List<DashboardGridCard> _repertoireCards(BuildContext context) => [
    DashboardGridCard(
      title: "Clients contrat entretien",
      icon: Icons.business,
      color: Colors.green,
      countStream: _db.getClients().map(
        (list) => list.where((c) => !c.horsContrat).toList(),
      ),
      countLabelFromList: clientsSitesLabel,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClientListScreen(
            filterHorsContrat: false,
            title: "Clients contrat entretien",
            color: Colors.green,
          ),
        ),
      ),
    ),
    DashboardGridCard(
      title: "Clients hors contrat",
      icon: Icons.business_center_outlined,
      color: Colors.orange[700]!,
      countStream: _db.getClients().map(
        (list) => list.where((c) => c.horsContrat).toList(),
      ),
      countLabelFromList: clientsSitesLabel,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClientListScreen(
            filterHorsContrat: true,
            title: "Clients hors contrat",
            color: Colors.orange[700]!,
          ),
        ),
      ),
    ),
    DashboardGridCard(
      title: "Fournisseurs",
      icon: Icons.local_shipping,
      color: Colors.blueGrey,
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
      countStream: _userService.getUsers().map((snap) => snap.docs),
      countLabel: (c) => "$c collaborateur(s)",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AnnuaireColleguesScreen(),
        ),
      ),
    ),
  ];

  List<DashboardGridCard> _administrationCards(BuildContext context) => [
    DashboardGridCard(
      title: "Gérer les Utilisateurs",
      icon: Icons.people,
      color: Colors.purple,
      countStream: _userService.getUsers().map((snap) => snap.docs),
      countLabel: (c) => "$c utilisateur(s)",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const UserManagementScreen(),
        ),
      ),
    ),
    DashboardGridCard(
      title: "Outils de Données",
      icon: Icons.settings_suggest,
      color: Colors.orange,
      subtitle: "Import / export",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AdminToolsScreen()),
      ),
    ),
    DashboardGridCard(
      title: "GMAO — Référentiel équipements",
      icon: Icons.precision_manufacturing_outlined,
      color: Colors.teal,
      subtitle: "Bêta — Lot 1 en cours",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const TypesEquipementListScreen(),
        ),
      ),
    ),
    DashboardGridCard(
      title: "GMAO — Heures de référence",
      icon: Icons.schedule_outlined,
      color: Colors.teal,
      subtitle: "Barème Tech/Assistant par équipement",
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ReferencesHorairesListScreen(),
        ),
      ),
    ),
  ];
}
