import 'package:flutter/material.dart';
import 'gmao_clients_screen.dart';
import '../../core/services/database_service.dart';
import '../annuaire/clients/client_model.dart';
import '../home/widgets/dashboard_grid_card.dart';

/// Point d'entrée GMAO depuis l'accueil : Contrat entretien / Hors
/// contrat → Client (regroupé par nom) → Site → Parc d'équipements
/// (groupé par Groupe).
class GmaoHomeScreen extends StatelessWidget {
  const GmaoHomeScreen({super.key});

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
        child: DashboardGrid(
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
      ),
    );
  }
}
