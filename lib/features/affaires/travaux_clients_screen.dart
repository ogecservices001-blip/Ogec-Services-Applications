import 'package:flutter/material.dart';
import '../../core/services/database_service.dart';
import '../annuaire/clients/client_list_screen.dart';
import '../annuaire/clients/client_model.dart';
import 'client_affaires_list_screen.dart';
import 'data/affaire_export_service.dart';
import 'data/affaire_model.dart';
import 'data/affaire_service.dart';
import 'import_affaires_screen.dart';

const Color travauxAccent = Colors.brown;

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

/// Suivi des travaux sur devis (Affaires) — regroupe les sites par
/// client (même champ `nom`, sans nouvelle collection côté Répertoire —
/// même logique que [[ClientGroupesListScreen]]/GmaoClientsScreen), mais
/// ne montre que les clients ayant déjà au moins une affaire (sinon la
/// liste noierait les quelques clients concernés parmi tout le
/// Répertoire). Pas de création manuelle : les affaires arrivent
/// uniquement par import (voir [[ImportAffairesScreen]]).
///
/// Sert aussi de picker pour le Bon d'intervention Petits travaux
/// ([modeSelection]) : c'est la raison d'être de cet écran — plutôt
/// qu'un picker dédié, l'assistant BI choisit son client/affaire en
/// passant directement par le Répertoire Travaux Clients.
class TravauxClientsScreen extends StatefulWidget {
  final bool modeSelection;

  /// Quand renseigné (picker du Bon d'intervention), ne montre que les
  /// clients/sites ayant au moins une affaire de cette nature, et ne
  /// propose ensuite que ces affaires-là dans [ClientAffairesListScreen].
  final String? natureFiltre;

  const TravauxClientsScreen({super.key, this.modeSelection = false, this.natureFiltre});

  @override
  State<TravauxClientsScreen> createState() => _TravauxClientsScreenState();
}

class _TravauxClientsScreenState extends State<TravauxClientsScreen> {
  final DatabaseService _db = DatabaseService();
  final AffaireService _affaireService = AffaireService();
  final AffaireExportService _exportService = AffaireExportService();
  String _recherche = '';
  bool _exportEnCours = false;
  bool _horsContrat = false;

  Future<void> _ouvrirAffairesDuSite(ClientModel site) async {
    if (widget.modeSelection) {
      final affaire = await Navigator.push<AffaireModel>(
        context,
        MaterialPageRoute(
          builder: (context) => ClientAffairesListScreen(
            client: site,
            modeSelection: true,
            natureFiltre: widget.natureFiltre,
          ),
        ),
      );
      if (affaire != null && mounted) {
        Navigator.pop(context, (site, affaire));
      }
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ClientAffairesListScreen(client: site)),
    );
  }

  Future<void> _exporterTout(List<AffaireModel> affaires) async {
    setState(() => _exportEnCours = true);
    try {
      await _exportService.exporter(affaires: affaires, nomFichier: 'toutes_les_affaires.xlsx');
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  Future<void> _exporterPourClient(String nom, List<AffaireModel> affaires) async {
    await _exportService.exporter(affaires: affaires, nomFichier: '${nom}_affaires.xlsx');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AffaireModel>>(
      stream: _affaireService.getAllAffaires(),
      builder: (context, affSnapshot) {
        final toutesAffaires = affSnapshot.data ?? const <AffaireModel>[];

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: Text(widget.modeSelection ? 'Choisir un client' : 'Travaux Clients'),
            backgroundColor: travauxAccent,
            foregroundColor: Colors.white,
            actions: widget.modeSelection
                ? const []
                : [
                    _exportEnCours
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.download),
                            tooltip: 'Exporter toutes les affaires',
                            onPressed: toutesAffaires.isEmpty ? null : () => _exporterTout(toutesAffaires),
                          ),
                    IconButton(
                      icon: const Icon(Icons.upload_file),
                      tooltip: 'Importer des affaires',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ImportAffairesScreen()),
                      ),
                    ),
                  ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(70),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  onChanged: (v) => setState(() => _recherche = v.toLowerCase().trim()),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un client...',
                    prefixIcon: Icon(Icons.search, color: travauxAccent),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Contrat entretien'),
                        selected: !_horsContrat,
                        onSelected: (_) => setState(() => _horsContrat = false),
                        selectedColor: travauxAccent.withValues(alpha: 0.15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Hors contrat'),
                        selected: _horsContrat,
                        onSelected: (_) => setState(() => _horsContrat = true),
                        selectedColor: travauxAccent.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<ClientModel>>(
                  stream: _db.getClients(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !affSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // N'affiche que les clients ayant déjà au moins une
                    // affaire (une site vaut par son id de document
                    // `clients`), pour la catégorie contrat choisie — et,
                    // si un pôle BI est en cours, uniquement de la nature
                    // correspondante.
                    final affairesRetenues = widget.natureFiltre == null
                        ? toutesAffaires
                        : toutesAffaires.where((a) => a.nature == widget.natureFiltre).toList();
                    final affairesParSite = <String, List<AffaireModel>>{};
                    for (final a in affairesRetenues) {
                      affairesParSite.putIfAbsent(a.clientId, () => []).add(a);
                    }

                    final sitesParClient = <String, List<ClientModel>>{};
                    for (final s in snapshot.data!.where((s) => s.horsContrat == _horsContrat)) {
                      if (!affairesParSite.containsKey(s.id)) continue;
                      sitesParClient.putIfAbsent(s.nom, () => []).add(s);
                    }
                    final nomsTries = sitesParClient.keys
                        .where((nom) => nom.toLowerCase().contains(_recherche))
                        .toList()
                      ..sort();

                    if (nomsTries.isEmpty) {
                      return Center(
                        child: Text(
                          _recherche.isEmpty
                              ? 'Aucune affaire pour l\'instant — "Importer" pour commencer'
                              : "Aucun résultat pour '$_recherche'",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                      itemCount: nomsTries.length,
                      itemBuilder: (context, index) {
                        final nom = nomsTries[index];
                        final sitesClient = sitesParClient[nom]!;
                        final affairesClient = <AffaireModel>[
                          for (final s in sitesClient) ...?affairesParSite[s.id],
                        ];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _couleursGroupes[index % _couleursGroupes.length].withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.assignment_outlined,
                                color: _couleursGroupes[index % _couleursGroupes.length],
                              ),
                            ),
                            title: Text(nom, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              '${sitesClient.length} site(s) · ${affairesClient.length} affaire(s)',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!widget.modeSelection)
                                  IconButton(
                                    icon: const Icon(Icons.download, size: 20),
                                    tooltip: 'Exporter les affaires de ce client',
                                    onPressed: () => _exporterPourClient(nom, affairesClient),
                                  ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () async {
                              if (sitesClient.length == 1) {
                                _ouvrirAffairesDuSite(sitesClient.first);
                                return;
                              }
                              // Le choix du site doit d'abord refermer cet
                              // écran intermédiaire (comme le fait
                              // BiClientPickerScreen) avant d'ouvrir les
                              // affaires du site — sinon, en mode sélection,
                              // le pop final de _ouvrirAffairesDuSite
                              // referme le mauvais écran et ramène ici au
                              // lieu de continuer le BI.
                              final site = await Navigator.push<ClientModel>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ClientListScreen(
                                    filterNom: nom,
                                    filterIds: sitesClient.map((s) => s.id).toSet(),
                                    title: nom,
                                    color: travauxAccent,
                                    onClientTap: (s) => Navigator.pop(context, s),
                                    countLabel: (site) {
                                      final n = affairesParSite[site.id]?.length ?? 0;
                                      return n == 0 ? null : '$n affaire(s)';
                                    },
                                  ),
                                ),
                              );
                              if (site != null) await _ouvrirAffairesDuSite(site);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
