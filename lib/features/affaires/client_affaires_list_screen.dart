import 'package:flutter/material.dart';
import '../annuaire/clients/client_model.dart';
import 'affaire_form_screen.dart';
import 'data/affaire_constants.dart';
import 'data/affaire_model.dart';
import 'data/affaire_service.dart';
import 'travaux_clients_screen.dart' show travauxAccent;

/// Affaires (travaux sur devis) d'un client/site donné — consultées et
/// corrigées par le bureau. Pas de création manuelle ici : les affaires
/// arrivent uniquement par import (voir [[ImportAffairesScreen]]).
///
/// Sert aussi de picker pour le Bon d'intervention Petits travaux
/// ([modeSelection]) : plutôt qu'un écran de sélection dédié, l'assistant
/// BI réutilise directement cet écran — un tap sur une affaire renvoie
/// le résultat au lieu d'ouvrir sa fiche.
class ClientAffairesListScreen extends StatelessWidget {
  final ClientModel client;
  final bool modeSelection;
  const ClientAffairesListScreen({super.key, required this.client, this.modeSelection = false});

  @override
  Widget build(BuildContext context) {
    final service = AffaireService();
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          [client.nom, client.site].where((s) => s.isNotEmpty).join(' — '),
        ),
        backgroundColor: travauxAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<AffaireModel>>(
        stream: service.getAffairesForClient(client.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final affaires = snapshot.data!..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (affaires.isEmpty) {
            return Center(
              child: Text(
                'Aucune affaire pour ce site pour l\'instant',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: affaires.length,
            itemBuilder: (context, index) {
              final a = affaires[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(
                    a.numeroDevis.isEmpty ? '(sans n° de devis)' : a.numeroDevis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    a.designationPrestations.isEmpty ? '—' : a.designationPrestations,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: a.nature.isEmpty
                      ? const Icon(Icons.chevron_right)
                      : Chip(
                          label: Text(NatureAffaire.label(a.nature), style: const TextStyle(fontSize: 11)),
                          backgroundColor: travauxAccent.withValues(alpha: 0.12),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                  onTap: () {
                    if (modeSelection) {
                      Navigator.pop(context, a);
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AffaireFormScreen(client: client, affaire: a),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
