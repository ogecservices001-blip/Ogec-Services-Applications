import 'package:flutter/material.dart';
import 'gmao_clients_screen.dart';
import 'gmao_database_service.dart';
import 'equipements/equipement_export_service.dart';
import 'equipements/import_equipements_screen.dart';
import '../../core/services/database_service.dart';
import '../../core/services/user_service.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../annuaire/clients/client_model.dart';
import '../home/widgets/dashboard_grid_card.dart';
import 'equipements/equipement_model.dart';
import 'references_horaires/references_horaires_service.dart';
import 'references_horaires/calcul_heures_visite.dart';

/// Point d'entrée GMAO depuis l'accueil : Contrat entretien / Hors
/// contrat → Client (regroupé par nom) → Site → Parc d'équipements
/// (groupé par Groupe). Section "Global" (admin) : export / import /
/// suppression de tout le parc équipements, tous clients confondus.
class GmaoHomeScreen extends StatefulWidget {
  const GmaoHomeScreen({super.key});

  @override
  State<GmaoHomeScreen> createState() => _GmaoHomeScreenState();
}

class _GmaoHomeScreenState extends State<GmaoHomeScreen> {
  final DatabaseService _db = DatabaseService();
  final GmaoDatabaseService _gmaoDb = GmaoDatabaseService();
  final ReferencesHorairesService _referencesService =
      ReferencesHorairesService();
  final UserService _userService = UserService();
  bool _isAdmin = false;
  bool _exportEnCours = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final isAdmin = await _userService.isCurrentUserAdmin();
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  Future<void> _exporterTout() async {
    setState(() => _exportEnCours = true);
    try {
      final sites = await _db.getClients().first;
      final types = await _gmaoDb.getTypesEquipement().first;
      final typesById = {for (final t in types) t.id: t};

      final lignes = <EquipementAvecSite>[];
      for (final site in sites) {
        final equipements = await _gmaoDb
            .getEquipementsForClient(site.id)
            .first;
        lignes.addAll(equipements.map((eq) => EquipementAvecSite(eq, site)));
      }

      await EquipementExportService().exporter(
        lignes: lignes,
        typesById: typesById,
        nomFichier: 'GMAO_tous_clients_equipements.xlsx',
      );
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  Future<void> _importerTout() async {
    final sites = await _db.getClients().first;
    final types = await _gmaoDb.getTypesEquipement().first;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ImportEquipementsScreen(sites: sites, types: types),
      ),
    );
  }

  Future<void> _supprimerTout() async {
    final confirme = await confirmerSuppressionMasse(
      context: context,
      titre: 'Supprimer tous les équipements',
      message:
          'Supprime tous les équipements de tous les clients, tous sites '
          'confondus — action irréversible.',
      motConfirmation: 'SUPPRIMER TOUT',
    );
    if (!confirme || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final sites = await _db.getClients().first;
    final total = await _gmaoDb.supprimerEquipementsPourClients(
      sites.map((s) => s.id).toList(),
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('$total équipement(s) supprimé(s)')),
    );
  }

  Future<HeuresVisite> _calculerHeuresGlobal() async {
    final sites = await _db.getClients().first;
    final references = await _referencesService.getReferences().first;
    final equipements = <EquipementModel>[];
    for (final site in sites) {
      equipements.addAll(await _gmaoDb.getEquipementsForClient(site.id).first);
    }
    return sommeHeuresVisite(equipements, references);
  }

  Widget _compteurHeuresGlobal() {
    return FutureBuilder<HeuresVisite>(
      future: _calculerHeuresGlobal(),
      builder: (context, snapshot) {
        final total = snapshot.data;
        if (total == null ||
            (total.heuresTech == 0 && total.heuresAssistant == 0)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Card(
            color: Colors.teal[50],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Heures prévues (tous clients) : ${total.heuresTech}h Tech / '
                '${total.heuresAssistant}h Assistant',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[800],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('GMAO'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardGrid(
              cards: [
                DashboardGridCard(
                  title: 'Clients contrat entretien',
                  icon: Icons.business,
                  color: Colors.teal[700]!,
                  countStream: db.getClients().map(
                    (list) => list.where((c) => !c.horsContrat).toList(),
                  ),
                  countLabelFromList: clientsSitesLabel,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GmaoClientsScreen(
                        filterHorsContrat: false,
                        title: 'GMAO — Contrat entretien',
                        color: Colors.teal,
                      ),
                    ),
                  ),
                ),
                DashboardGridCard(
                  title: 'Clients hors contrat',
                  icon: Icons.business_center_outlined,
                  color: Colors.orange[700]!,
                  countStream: db.getClients().map(
                    (list) => list.where((c) => c.horsContrat).toList(),
                  ),
                  countLabelFromList: clientsSitesLabel,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GmaoClientsScreen(
                        filterHorsContrat: true,
                        title: 'GMAO — Hors contrat',
                        color: Colors.orange[700]!,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            _compteurHeuresGlobal(),
            if (_isAdmin) ...[
              const SizedBox(height: 24),
              const Text(
                'GLOBAL — TOUS CLIENTS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              DashboardGrid(
                cards: [
                  DashboardGridCard(
                    title: 'Exporter tous les équipements',
                    icon: Icons.download,
                    color: Colors.blueGrey,
                    subtitle: _exportEnCours
                        ? 'Export en cours...'
                        : 'Tous clients, tous sites',
                    onTap: _exportEnCours ? () {} : _exporterTout,
                  ),
                  DashboardGridCard(
                    title: 'Importer des équipements',
                    icon: Icons.upload_file,
                    color: Colors.blueGrey,
                    subtitle: 'Répartition automatique par Client/Site',
                    onTap: _importerTout,
                  ),
                  DashboardGridCard(
                    title: 'Supprimer tous les équipements',
                    icon: Icons.delete_outline,
                    color: Colors.red,
                    subtitle: 'Action irréversible',
                    onTap: _supprimerTout,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
