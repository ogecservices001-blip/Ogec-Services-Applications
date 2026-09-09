import 'package:flutter/material.dart';
import '../data/bi_constants.dart';

Color _couleurStatut(String statut) {
  switch (statut) {
    case Statuts.brouillon:
      return Colors.grey;
    case Statuts.aVerifier:
      return Colors.orange;
    case Statuts.valide:
      return Colors.teal;
    case Statuts.pdfGenere:
      return Colors.blue;
    case Statuts.pretEnvoi:
      return Colors.indigo;
    case Statuts.envoye:
      return Colors.green;
    case Statuts.erreurSync:
      return Colors.red;
    default:
      return Colors.grey;
  }
}

class StatutBadge extends StatelessWidget {
  final String statut;
  const StatutBadge({super.key, required this.statut});

  @override
  Widget build(BuildContext context) {
    final couleur = _couleurStatut(statut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: couleur.withValues(alpha: 0.4)),
      ),
      child: Text(
        Statuts.label(statut),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: couleur),
      ),
    );
  }
}
