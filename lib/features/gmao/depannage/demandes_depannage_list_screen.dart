import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'demande_depannage_model.dart';
import 'demande_depannage_service.dart';

/// Suivi Dépannage (Tableau de bord) : liste des demandes de dépannage
/// reçues depuis les pages publiques équipement (QR code scanné par un
/// client, email vérifié côté serveur) — voir aussi la notification par
/// email automatique envoyée en parallèle par la Cloud Function.
class DemandesDepannageListScreen extends StatelessWidget {
  const DemandesDepannageListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = DemandeDepannageService();
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Suivi Dépannage'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<DemandeDepannageModel>>(
        stream: service.getDemandes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final demandes = snapshot.data!;
          if (demandes.isEmpty) {
            return Center(
              child: Text(
                'Aucune demande de dépannage reçue',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: demandes.length,
            itemBuilder: (context, i) =>
                _carteDemande(context, service, demandes[i]),
          );
        },
      ),
    );
  }

  Widget _carteDemande(
    BuildContext context,
    DemandeDepannageService service,
    DemandeDepannageModel d,
  ) {
    final nouvelle = d.statut != 'traitee';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: nouvelle
            ? const BorderSide(color: Colors.red, width: 1.5)
            : BorderSide.none,
      ),
      color: nouvelle ? Colors.red.withValues(alpha: 0.05) : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    [d.clientNom, d.clientSite]
                        .where((s) => s.isNotEmpty)
                        .join(' — '),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (nouvelle ? Colors.red : Colors.green).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    nouvelle ? 'Nouvelle' : 'Traitée',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: nouvelle ? Colors.red[800] : Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(d.equipementNom, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            Text(d.message, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Text(
              'Demandé par ${d.email}'
              '${d.dateCreation != null ? ' — ${DateFormat('dd/MM/yyyy HH:mm').format(d.dateCreation!)}' : ''}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            if (nouvelle) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => service.marquerTraitee(d.id),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Marquer comme traitée'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
