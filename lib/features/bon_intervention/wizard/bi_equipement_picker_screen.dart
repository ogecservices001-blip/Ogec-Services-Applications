import 'package:flutter/material.dart';
import '../../annuaire/clients/client_model.dart';
import '../../gmao/equipements/equipement_model.dart';
import '../../gmao/gmao_database_service.dart';
import 'bi_wizard_screen.dart' show biAccent;

const List<Color> _couleursGroupes = [
  Colors.teal,
  Colors.indigo,
  Colors.orange,
  Colors.purple,
  Colors.brown,
  Colors.cyan,
  Colors.deepOrange,
  Colors.green,
];

/// Sélection d'un équipement du parc GMAO d'un site — Maintenance et
/// Dépannage uniquement, optionnelle (le cas où l'équipement n'existe
/// pas encore dans le parc n'est pas géré ici, à traiter plus tard).
/// Même regroupement par "Groupe" que `ClientEquipementsListScreen`.
class BiEquipementPickerScreen extends StatelessWidget {
  final ClientModel client;
  const BiEquipementPickerScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final gmaoDb = GmaoDatabaseService();
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Parc GMAO — ${[client.nom, client.site].where((s) => s.isNotEmpty).join(' — ')}',
        ),
        backgroundColor: biAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<EquipementModel>>(
        stream: gmaoDb.getEquipementsForClient(client.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final equipements = snapshot.data!;
          if (equipements.isEmpty) {
            return Center(
              child: Text(
                'Aucun équipement enregistré pour ce site',
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }

          final parGroupe = <String, List<EquipementModel>>{};
          for (final eq in equipements) {
            final groupe = eq.groupe.trim().isEmpty ? 'Sans groupe' : eq.groupe.trim();
            parGroupe.putIfAbsent(groupe, () => []).add(eq);
          }
          for (final liste in parGroupe.values) {
            liste.sort((a, b) => a.nom.compareTo(b.nom));
          }
          final groupesTries = parGroupe.keys.toList()
            ..sort((a, b) {
              if (a == 'Sans groupe') return 1;
              if (b == 'Sans groupe') return -1;
              return a.compareTo(b);
            });

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (var i = 0; i < groupesTries.length; i++)
                _etiquetteGroupe(
                  context,
                  groupe: groupesTries[i],
                  couleur: groupesTries[i] == 'Sans groupe'
                      ? Colors.blueGrey
                      : _couleursGroupes[i % _couleursGroupes.length],
                  ouvertParDefaut: groupesTries.length == 1,
                  equipements: parGroupe[groupesTries[i]]!,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _etiquetteGroupe(
    BuildContext context, {
    required String groupe,
    required Color couleur,
    required bool ouvertParDefaut,
    required List<EquipementModel> equipements,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          elevation: 1,
          child: ExpansionTile(
            initiallyExpanded: ouvertParDefaut,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            iconColor: couleur,
            collapsedIconColor: couleur,
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.precision_manufacturing_outlined, color: couleur),
            ),
            title: Text(groupe, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${equipements.length} équipement(s)'),
            children: [
              for (final eq in equipements)
                ListTile(
                  title: Text(eq.nom),
                  subtitle: Text(
                    [
                      eq.numeroEquipement,
                      eq.localisation,
                    ].where((s) => s.isNotEmpty).join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, eq),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
