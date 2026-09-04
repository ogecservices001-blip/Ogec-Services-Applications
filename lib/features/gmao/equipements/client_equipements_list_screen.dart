import 'package:flutter/material.dart';
import '../../annuaire/clients/client_model.dart';
import '../../../core/services/user_service.dart';
import '../gmao_database_service.dart';
import '../types_equipement/type_equipement_model.dart';
import '../releve/dynamic_releve_form_screen.dart';
import 'equipement_model.dart';
import 'ajouter_equipement_screen.dart';
import 'import_equipements_screen.dart';
import 'equipement_export_service.dart';
import '../references_horaires/references_horaires_service.dart';
import '../references_horaires/reference_horaire_model.dart';
import '../references_horaires/calcul_heures_visite.dart';

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
                  icon: const Icon(Icons.upload_file),
                  tooltip: 'Importer un fichier équipements',
                  onPressed: () async {
                    final types = await gmaoDb.getTypesEquipement().first;
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ImportEquipementsScreen(
                          client: client,
                          types: types,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Exporter le parc en Excel',
                  onPressed: () async {
                    final types = await gmaoDb.getTypesEquipement().first;
                    final equipements = await gmaoDb
                        .getEquipementsForClient(client.id)
                        .first;
                    EquipementExportService().exporter(
                      lignes: equipements
                          .map((eq) => EquipementAvecSite(eq, client))
                          .toList(),
                      typesById: {for (final t in types) t.id: t},
                      nomFichier: '${client.nom}_${client.site}_equipements.xlsx',
                    );
                  },
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
                      client: client,
                      readOnly: readOnly,
                    ),
                ],
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
            subtitle: Text(
              '${equipements.length} équipement(s)',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              for (final eq in equipements)
                _carteEquipement(
                  context,
                  eq,
                  typesById[eq.typeEquipementId],
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
                _heuresPrevues(eq),
              ],
            ),
          ),
          if (!readOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
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
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Démarrer Entretien'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal[700],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _heuresPrevues(EquipementModel eq) {
    if (eq.referenceHoraireId.isEmpty) return const SizedBox.shrink();
    final freqAnnuelle = int.tryParse(
      eq.champsEnTete['freqEntretienAnnuelle']?.toString() ?? '',
    );
    final freqCourante = int.tryParse(
      eq.champsEnTete['freqCourante']?.toString() ?? '',
    );
    if (freqAnnuelle == null || freqCourante == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<ReferenceHoraireModel?>(
      future: _referencesService.getReferenceById(eq.referenceHoraireId),
      builder: (context, snapshot) {
        final reference = snapshot.data;
        if (reference == null) return const SizedBox.shrink();
        final heures = calculerHeuresVisite(
          freqEntretienAnnuelle: freqAnnuelle,
          freqCourante: freqCourante,
          reference: reference,
        );
        if (heures == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Heures prévues : ${heures.heuresTech}h Tech / ${heures.heuresAssistant}h Assistant',
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
