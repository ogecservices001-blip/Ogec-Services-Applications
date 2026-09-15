import 'package:flutter/material.dart';
import '../../core/services/database_service.dart';
import 'data/affaire_constants.dart';
import 'data/affaire_import_service.dart';
import 'data/affaire_model.dart';
import 'data/affaire_service.dart';
import 'travaux_clients_screen.dart' show travauxAccent;

/// Écran récapitulatif d'un import de l'onglet AFFAIRES : montre les
/// lignes résolues vers un client/site du Répertoire (une case à cocher
/// chacune, tout coché par défaut) et les lignes ignorées faute de
/// correspondance, avant toute écriture en base.
class ImportAffairesScreen extends StatefulWidget {
  const ImportAffairesScreen({super.key});

  @override
  State<ImportAffairesScreen> createState() => _ImportAffairesScreenState();
}

class _ImportAffairesScreenState extends State<ImportAffairesScreen> {
  final DatabaseService _db = DatabaseService();
  final AffaireImportService _importService = AffaireImportService();
  final AffaireService _affaireService = AffaireService();

  bool _chargementEnCours = true;
  bool _importEnCours = false;
  ResultatImportAffaires? _resultat;
  final Set<int> _lignesCochees = {};

  @override
  void initState() {
    super.initState();
    _chargerEtResoudre();
  }

  Future<void> _chargerEtResoudre() async {
    final clients = await _db.getClients().first;
    final affairesExistantes = await _affaireService.getAllAffaires().first;
    final resultat = await _importService.pickParseEtResoudre(clients, affairesExistantes);
    if (resultat == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() {
      _resultat = resultat;
      _lignesCochees.addAll(List.generate(resultat.lignes.length, (i) => i));
      _chargementEnCours = false;
    });
  }

  Future<void> _importer() async {
    final resultat = _resultat;
    if (resultat == null) return;

    setState(() => _importEnCours = true);
    var crees = 0;
    var misesAJour = 0;
    try {
      for (var i = 0; i < resultat.lignes.length; i++) {
        if (!_lignesCochees.contains(i)) continue;
        final ligne = resultat.lignes[i];
        final existante = ligne.existante;
        // Une cellule vide dans le fichier ne doit pas écraser une valeur
        // déjà saisie côté app (colonnes ajoutées après coup, pas encore
        // renseignées pour toutes les lignes du classeur) — seule une
        // valeur non vide du fichier prend le dessus.
        String depuisFichierOuExistant(String depuisFichier, String? existant) =>
            depuisFichier.isNotEmpty ? depuisFichier : (existant ?? '');
        await _affaireService.saveAffaire(
          AffaireModel(
            id: existante?.id ?? '',
            clientId: ligne.client.id,
            clientNom: ligne.client.nom,
            site: ligne.client.site,
            numeroDevis: ligne.numeroDevis,
            designationPrestations: ligne.designationPrestations,
            emailResponsableContrat: ligne.client.courrielResponsable,
            numeroCommandeClient: depuisFichierOuExistant(ligne.numeroCommandeClient, existante?.numeroCommandeClient),
            dateCommandeClient: depuisFichierOuExistant(ligne.dateCommandeClient, existante?.dateCommandeClient),
            nature: depuisFichierOuExistant(ligne.nature, existante?.nature),
            createdAt: existante?.createdAt ?? 0,
          ),
        );
        if (existante != null) {
          misesAJour++;
        } else {
          crees++;
        }
      }
      if (!mounted) return;
      final resume = [
        if (crees > 0) '$crees nouvelle(s)',
        if (misesAJour > 0) '$misesAJour mise(s) à jour',
      ].join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resume.isEmpty ? 'Rien à importer' : 'Import terminé : $resume')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur pendant l\'import ($crees créée(s), $misesAJour mise(s) à jour) : $e')),
      );
    } finally {
      if (mounted) setState(() => _importEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Importer des affaires'),
        backgroundColor: travauxAccent,
        foregroundColor: Colors.white,
      ),
      body: _chargementEnCours
          ? const Center(child: CircularProgressIndicator())
          : _buildContenu(),
    );
  }

  Widget _buildContenu() {
    final resultat = _resultat!;
    if (resultat.lignes.isEmpty && resultat.avertissements.isEmpty) {
      return const Center(child: Text('Aucune ligne trouvée dans ce fichier.'));
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            children: [
              if (resultat.lignes.isNotEmpty) ...[
                Text(
                  '${resultat.lignes.length} affaire(s) à importer',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < resultat.lignes.length; i++) _ligneTile(i, resultat.lignes[i]),
              ],
              if (resultat.avertissements.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '${resultat.avertissements.length} ligne(s) ignorée(s)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange[800]),
                ),
                const SizedBox(height: 8),
                for (final a in resultat.avertissements)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_outlined, size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Expanded(child: Text(a, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_importEnCours || _lignesCochees.isEmpty) ? null : _importer,
                style: ElevatedButton.styleFrom(backgroundColor: travauxAccent, foregroundColor: Colors.white),
                child: _importEnCours
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text('Importer ${_lignesCochees.length} affaire(s)'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ligneTile(int index, LigneAffaireImport ligne) {
    final coche = _lignesCochees.contains(index);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: CheckboxListTile(
        value: coche,
        onChanged: (v) => setState(() {
          if (v == true) {
            _lignesCochees.add(index);
          } else {
            _lignesCochees.remove(index);
          }
        }),
        activeColor: travauxAccent,
        controlAffinity: ListTileControlAffinity.leading,
        title: Row(
          children: [
            Flexible(
              child: Text(
                ligne.numeroDevis.isEmpty ? '(sans n° de devis)' : ligne.numeroDevis,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (ligne.existante != null) ...[
              const SizedBox(width: 6),
              Chip(
                label: const Text('Mise à jour', style: TextStyle(fontSize: 10)),
                backgroundColor: travauxAccent.withValues(alpha: 0.12),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ],
        ),
        subtitle: Text(_sousTitre(ligne)),
        isThreeLine: true,
      ),
    );
  }

  String _sousTitre(LigneAffaireImport ligne) {
    final lignes = [
      ligne.siteApproximatif
          ? '${ligne.client.nom} — ${ligne.client.site} (site non précisé, rattaché au 1er site connu)'
          : '${ligne.client.nom} — ${ligne.client.site}',
      ligne.designationPrestations,
      if (ligne.numeroCommandeClient.isNotEmpty) 'Réf. commande client : ${ligne.numeroCommandeClient}',
      if (ligne.dateCommandeClient.isNotEmpty) 'Date commande : ${ligne.dateCommandeClient}',
      if (ligne.nature.isNotEmpty) 'Nature : ${NatureAffaire.label(ligne.nature)}',
    ];
    return lignes.join('\n');
  }
}
