import 'package:flutter/material.dart';
import '../data/bi_constants.dart';
import '../data/bi_model.dart';
import '../data/bi_service.dart';
import '../widgets/statut_badge.dart';
import '../wizard/bi_wizard_screen.dart';
import 'bi_detail_bureau_screen.dart';

/// Suivi bureau : liste des bons d'intervention, avec les bons "à
/// vérifier" mis en avant. Porté depuis re.ogec.bi/ui/screens/HomeScreen.kt
/// (fonction SuiviBureauScreen).
class BiListScreen extends StatelessWidget {
  const BiListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final biService = BiService();
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Bons d'intervention"),
        backgroundColor: biAccent,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BiWizardScreen()),
        ),
        backgroundColor: biAccent,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau BI'),
      ),
      body: StreamBuilder<List<BonIntervention>>(
        stream: biService.bisFlow(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final bis = snapshot.data!;
          if (bis.isEmpty) {
            return const Center(
              child: Text(
                'Aucun bon pour l\'instant.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          final aVerifier = bis.where((b) => b.statut == Statuts.aVerifier).toList();
          final autres = bis.where((b) => b.statut != Statuts.aVerifier).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              if (aVerifier.isNotEmpty) ...[
                Text(
                  'À vérifier (${aVerifier.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                for (final b in aVerifier) _BiCard(bi: b),
                const SizedBox(height: 20),
              ],
              const Text(
                'Tous les bons',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              for (final b in autres) _BiCard(bi: b),
            ],
          );
        },
      ),
    );
  }
}

class _BiCard extends StatelessWidget {
  final BonIntervention bi;
  const _BiCard({required this.bi});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BiDetailBureauScreen(biId: bi.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bi.numero.isEmpty ? 'BI (brouillon)' : bi.numero,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  StatutBadge(statut: bi.statut),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                bi.site.isNotEmpty ? '${bi.clientNom} — ${bi.site}' : bi.clientNom,
              ),
              const SizedBox(height: 2),
              Text(
                'Pôle ${bi.pole} · ${Poles.label(bi.pole)}',
                style: TextStyle(fontSize: 12, color: biAccent, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
