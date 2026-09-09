import 'package:flutter/material.dart';
import '../../annuaire/clients/client_model.dart';
import '../../../core/services/user_service.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../gmao_database_service.dart';
import '../types_equipement/type_equipement_model.dart';
import '../releve/dynamic_releve_form_screen.dart';
import 'equipement_model.dart';
import 'ajouter_equipement_screen.dart';
import 'visualiser_donnees_screen.dart';
import 'import_equipements_screen.dart';
import 'equipement_export_service.dart';
import '../references_horaires/references_horaires_service.dart';
import '../references_horaires/reference_horaire_model.dart';
import '../references_horaires/calcul_heures_visite.dart';
import '../references_horaires/suggestion_reference_horaire.dart';
import '../releve/releve_service.dart';

/// Parc d'équipements GMAO d'un client : liste les équipements déjà
/// enregistrés, permet d'en ajouter et ouvre le relevé pré-rempli pour
/// un équipement donné. La modification des infos équipement se fait
/// pendant l'entretien (relevé), pas ici — pas de bouton dédié.
///
/// Import/export réservés aux admins. En [readOnly] (ex: consultation
/// depuis la fiche client du Répertoire), c'est une simple liste
/// consultable : pas d'ajout, pas d'ouverture du relevé — la
/// maintenance passe uniquement par l'entrée GMAO dédiée de l'accueil.
class ClientEquipementsListScreen extends StatefulWidget {
  final ClientModel client;
  final bool readOnly;

  const ClientEquipementsListScreen({
    super.key,
    required this.client,
    this.readOnly = false,
  });

  @override
  State<ClientEquipementsListScreen> createState() =>
      _ClientEquipementsListScreenState();
}

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

class _ClientEquipementsListScreenState
    extends State<ClientEquipementsListScreen> {
  final UserService _userService = UserService();
  final ReferencesHorairesService _referencesService =
      ReferencesHorairesService();
  final ReleveService _releveService = ReleveService();
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final isAdmin = await _userService.isCurrentUserAdmin();
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  Future<void> _supprimerToutLeParc(GmaoDatabaseService gmaoDb) async {
    final confirme = await confirmerSuppressionMasse(
      context: context,
      titre: 'Supprimer tout le parc de ce site',
      message:
          'Supprime tous les équipements de ce site — action irréversible.',
      motConfirmation: widget.client.nom,
    );
    if (!confirme || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final total = await gmaoDb.supprimerEquipementsPourClients([
      widget.client.id,
    ]);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('$total équipement(s) supprimé(s)')),
    );
  }

  Future<void> _supprimerEquipement(
    GmaoDatabaseService gmaoDb,
    EquipementModel eq,
  ) async {
    final confirme = await confirmerSuppression(
      context: context,
      titre: 'Supprimer cet équipement',
      message: 'Supprimer "${eq.nom}" ? Action irréversible.',
    );
    if (!confirme || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    await gmaoDb.deleteEquipement(eq.id);
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Équipement supprimé')));
  }

  @override
  Widget build(BuildContext context) {
    final gmaoDb = GmaoDatabaseService();
    final client = widget.client;
    final readOnly = widget.readOnly;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Parc GMAO — '
          '${[client.nom, client.site].where((s) => s.isNotEmpty).join(' — ')}',
        ),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        actions: (readOnly || !_isAdmin)
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  tooltip: 'Importer un fichier équipements',
                  onPressed: () async {
                    final types = await gmaoDb.getTypesEquipement().first;
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ImportEquipementsScreen(
                          sites: [client],
                          types: types,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  tooltip: 'Exporter le parc en Excel',
                  onPressed: () async {
                    final types = await gmaoDb.getTypesEquipement().first;
                    final equipements = await gmaoDb
                        .getEquipementsForClient(client.id)
                        .first;
                    await EquipementExportService().exporter(
                      lignes: equipements
                          .map((eq) => EquipementAvecSite(eq, client))
                          .toList(),
                      typesById: {for (final t in types) t.id: t},
                      nomFichier: '${client.nom}_${client.site}_equipements.xlsx',
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  tooltip: 'Supprimer tout le parc de ce site',
                  onPressed: () => _supprimerToutLeParc(gmaoDb),
                ),
              ],
      ),
      body: StreamBuilder<List<TypeEquipementModel>>(
        stream: gmaoDb.getTypesEquipement(),
        builder: (context, typesSnapshot) {
          if (!typesSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final types = typesSnapshot.data!;
          final typesById = {for (final t in types) t.id: t};

          return StreamBuilder<List<ReferenceHoraireModel>>(
            stream: _referencesService.getReferences(),
            builder: (context, refSnapshot) {
              final references = refSnapshot.data ?? const [];

              return StreamBuilder<List<EquipementModel>>(
                stream: gmaoDb.getEquipementsForClient(client.id),
                builder: (context, equipSnapshot) {
                  if (!equipSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final equipements = equipSnapshot.data!;

                  if (equipements.isEmpty) {
                    return Center(
                      child: Text(
                        'Aucun équipement enregistré pour ce client',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }

                  final parGroupe = <String, List<EquipementModel>>{};
                  for (final eq in equipements) {
                    final groupe = eq.groupe.trim().isEmpty
                        ? 'Sans groupe'
                        : eq.groupe.trim();
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
                      _compteurHeures(
                        'Heures prévues (ce site)',
                        equipements,
                        references,
                      ),
                      for (var i = 0; i < groupesTries.length; i++)
                        _etiquetteGroupe(
                          context,
                          groupe: groupesTries[i],
                          couleur: groupesTries[i] == 'Sans groupe'
                              ? Colors.blueGrey
                              : _couleursGroupes[i % _couleursGroupes.length],
                          ouvertParDefaut: groupesTries.length == 1,
                          equipements: parGroupe[groupesTries[i]]!,
                          typesById: typesById,
                          references: references,
                          client: client,
                          readOnly: readOnly,
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: readOnly
          ? null
          : StreamBuilder<List<TypeEquipementModel>>(
              stream: gmaoDb.getTypesEquipement(),
              builder: (context, snapshot) {
                final types = snapshot.data ?? [];
                return FloatingActionButton(
                  backgroundColor: Colors.teal[700],
                  onPressed: types.isEmpty
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AjouterEquipementScreen(
                              clientId: client.id,
                              typesDisponibles: types,
                            ),
                          ),
                        ),
                  child: const Icon(Icons.add, color: Colors.white),
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
    required Map<String, TypeEquipementModel> typesById,
    required List<ReferenceHoraireModel> references,
    required ClientModel client,
    required bool readOnly,
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            iconColor: couleur,
            collapsedIconColor: couleur,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.label_outline, color: couleur, size: 26),
            ),
            title: Text(
              groupe,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${equipements.length} équipement(s)',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                _compteurHeures(null, equipements, references, compact: true),
              ],
            ),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              for (final eq in equipements)
                _carteEquipement(
                  context,
                  eq,
                  typesById[eq.typeEquipementId],
                  references,
                  client,
                  readOnly,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _carteEquipement(
    BuildContext context,
    EquipementModel eq,
    TypeEquipementModel? type,
    List<ReferenceHoraireModel> references,
    ClientModel client,
    bool readOnly,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              Icons.precision_manufacturing_outlined,
              color: Colors.teal,
            ),
            title: Text(eq.nom),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    type?.code ?? 'Famille inconnue',
                    eq.numeroEquipement,
                    eq.localisation,
                  ].where((s) => s.isNotEmpty).join(' — '),
                ),
                if (concatTypeEquipement(eq.champsEnTete).isNotEmpty)
                  Text(
                    concatTypeEquipement(eq.champsEnTete),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                _heuresPrevues(eq, references),
              ],
            ),
            trailing: (!readOnly && _isAdmin)
                ? IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () =>
                        _supprimerEquipement(GmaoDatabaseService(), eq),
                  )
                : null,
          ),
          if (!readOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: type == null
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        VisualiserDonneesScreen(
                                      equipement: eq,
                                      type: type,
                                      client: client,
                                    ),
                                  ),
                                ),
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('Visualiser Données'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blueGrey[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: type == null
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DynamicReleveFormScreen(
                                      type: type,
                                      equipement: eq,
                                      client: client,
                                    ),
                                  ),
                                ),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Démarrer Entretien'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.build_outlined, size: 18),
                          label: const Text('Démarrer Dépannage'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.handyman_outlined, size: 18),
                          label: const Text('Démarrer Réparation'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Compteur d'heures Tech/Assistant additionnées pour [equipements] —
  /// réutilisé pour le total du site et pour chaque Groupe. [titre]
  /// null : version compacte (une ligne, sans carte, pour un sous-titre
  /// de Groupe) ; sinon carte pleine largeur avec [titre].
  Widget _compteurHeures(
    String? titre,
    List<EquipementModel> equipements,
    List<ReferenceHoraireModel> references, {
    bool compact = false,
  }) {
    return FutureBuilder<HeuresVisite>(
      future: sommeHeuresVisite(equipements, references),
      builder: (context, snapshot) {
        final total = snapshot.data;
        if (total == null || (total.heuresTech == 0 && total.heuresAssistant == 0)) {
          return const SizedBox.shrink();
        }
        final texte =
            '${titre ?? 'Heures prévues'} : ${total.heuresTech}h Tech / '
            '${total.heuresAssistant}h Assistant';
        if (compact) {
          return Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              texte,
              style: TextStyle(
                fontSize: 12,
                color: Colors.teal[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.teal[50],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              texte,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[800]),
            ),
          ),
        );
      },
    );
  }

  Widget _heuresPrevues(EquipementModel eq, List<ReferenceHoraireModel> references) {
    final reference = trouverReferenceExacte(
      champsEnTete: eq.champsEnTete,
      references: references,
    );
    if (reference == null) return const SizedBox.shrink();
    final freqAnnuelle = int.tryParse(
      eq.champsEnTete['freqEntretienAnnuelle']?.toString() ?? '',
    );
    if (freqAnnuelle == null) return const SizedBox.shrink();

    return FutureBuilder<int?>(
      future: _releveService.freqCouranteCalculee(eq.id),
      builder: (context, snapshot) {
        final freqCourante = snapshot.data;
        if (freqCourante == null) return const SizedBox.shrink();
        final heures = calculerHeuresVisite(
          freqEntretienAnnuelle: freqAnnuelle,
          freqCourante: freqCourante,
          reference: reference,
        );
        if (heures == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Heures prévues : ${heures.heuresTech}h Tech / ${heures.heuresAssistant}h Assistant '
            '(visite $freqCourante de $freqAnnuelle ${DateTime.now().year})',
            style: TextStyle(
              fontSize: 11,
              color: Colors.teal[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}
