import 'package:flutter/material.dart';
import 'dashboard_grid_card.dart';

/// Page de sous-menu générique : grille 2 colonnes de [DashboardGridCard]
/// sous un AppBar, utilisée pour les sections CERFA / Répertoire /
/// Administration des tableaux de bord admin et technicien.
class DashboardSectionScreen extends StatelessWidget {
  const DashboardSectionScreen({
    super.key,
    required this.title,
    required this.cards,
    this.appBarColor = Colors.blue,
    this.appBarForegroundColor = Colors.white,
  });

  final String title;
  final List<DashboardGridCard> cards;
  final Color appBarColor;
  final Color appBarForegroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(title),
        backgroundColor: appBarColor,
        foregroundColor: appBarForegroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: DashboardGrid(cards: cards),
      ),
    );
  }
}
