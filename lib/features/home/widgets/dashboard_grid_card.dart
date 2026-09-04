import 'package:flutter/material.dart';

/// Carte d'action pleine largeur utilisée dans les pages de sous-menu des
/// tableaux de bord (admin et technicien) : même format que les grandes
/// étiquettes de premier niveau ([TopMenuCard]) — badge icône coloré,
/// titre, sous-titre optionnel (texte statique ou dérivé d'un flux de
/// comptage), chevron.
class DashboardGridCard extends StatelessWidget {
  const DashboardGridCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.subtitle,
    this.countStream,
    this.countLabel,
    this.countLabelFromList,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  /// Sous-titre statique (ignoré si [countStream] est fourni).
  final String? subtitle;

  /// Flux dont la longueur alimente [countLabel] pour un sous-titre
  /// dynamique (ex: "158 client(s)").
  final Stream<List<dynamic>>? countStream;
  final String Function(int count)? countLabel;

  /// Variante de [countLabel] qui reçoit la liste complète plutôt que sa
  /// seule longueur (ex: pour compter les clients uniques en plus des
  /// sites). Prioritaire sur [countLabel] si fourni.
  final String Function(List<dynamic> items)? countLabelFromList;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildSubtitle(),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    if (countStream != null && countLabelFromList != null) {
      return StreamBuilder<List<dynamic>>(
        stream: countStream,
        builder: (context, snapshot) {
          return Text(
            countLabelFromList!(snapshot.data ?? const []),
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          );
        },
      );
    }
    if (countStream != null && countLabel != null) {
      return StreamBuilder<List<dynamic>>(
        stream: countStream,
        builder: (context, snapshot) {
          final count = snapshot.data?.length ?? 0;
          return Text(
            countLabel!(count),
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          );
        },
      );
    }
    if (subtitle != null) {
      return Text(
        subtitle!,
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Liste verticale pleine largeur (destinée à être posée dans une
/// [SingleChildScrollView]) pour les cartes [DashboardGridCard] d'une
/// section du tableau de bord.
class DashboardGrid extends StatelessWidget {
  const DashboardGrid({super.key, required this.cards});

  final List<DashboardGridCard> cards;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final card in cards) ...[
          card,
          if (card != cards.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}
