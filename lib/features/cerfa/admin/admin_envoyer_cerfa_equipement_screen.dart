import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/auth/admin_google_session.dart';
import '../models/equipement_model.dart';
import '../services/admin_drive_service.dart';
import '../services/admin_mail_service.dart';

class AdminEnvoyerCerfaEquipementScreen extends StatefulWidget {
  final String client;
  final String site;
  final List<Equipement> equipements; // liste complète, non filtrée

  const AdminEnvoyerCerfaEquipementScreen({
    super.key,
    required this.client,
    required this.site,
    required this.equipements,
  });

  @override
  State<AdminEnvoyerCerfaEquipementScreen> createState() =>
      _AdminEnvoyerCerfaEquipementScreenState();
}

class _AdminEnvoyerCerfaEquipementScreenState
    extends State<AdminEnvoyerCerfaEquipementScreen> {
  final AdminDriveService _driveService = AdminDriveService();
  final AdminMailService _mailService = AdminMailService();

  Equipement? _selectedEquipement;
  bool _isRecherche = false;
  String? _envoiEnCours;
  List<DriveFileInfo> _fichiers = [];

  List<Equipement> get _equipementsDuSite => widget.equipements
      .where((e) => e.client == widget.client && e.site == widget.site)
      .toList();

  Future<void> _selectionnerEquipement(Equipement e) async {
    setState(() {
      _selectedEquipement = e;
      _fichiers = [];
      _isRecherche = true;
    });

    try {
      final account = await AdminGoogleSession.instance.ensureSignedIn(context);
      final fichiers = await _driveService.listerCerfaFinalises(
        adminAccount: account,
        equipement: e,
      );
      setState(() {
        _fichiers = fichiers;
        _isRecherche = false;
      });
    } catch (e) {
      setState(() => _isRecherche = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de recherche : $e')));
      }
    }
  }

  Future<void> _ouvrirDialogueEnvoi(DriveFileInfo fichier) async {
    final e = _selectedEquipement!;
    final destinataireController = TextEditingController(
      text: e.emailSignataireClient,
    );

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Envoyer ce CERFA'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fichier.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: destinataireController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Adresse destinataire',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    if (confirme != true) return;
    final destinataire = destinataireController.text.trim();
    if (destinataire.isEmpty) return;

    await _envoyer(fichier, destinataire);
  }

  Future<void> _envoyer(DriveFileInfo fichier, String destinataire) async {
    final e = _selectedEquipement!;
    setState(() => _envoiEnCours = fichier.id);

    try {
      final account = await AdminGoogleSession.instance.ensureSignedIn(context);
      final bytes = await _driveService.telechargerFichier(
        adminAccount: account,
        fileId: fichier.id,
      );

      final objet = 'CERFA 15497 – ${e.site} – ${e.nomEquipement}';
      final corps =
          'Bonjour,\n\n'
          'Nous vous prions de bien vouloir trouver en pièce jointe votre '
          'certificat de contrôle d\'étanchéité pour votre équipement '
          'suivant :\n\n'
          'Site : ${e.site}\n'
          'Équipement : ${e.nomEquipement}\n\n'
          'Cordialement,\n\n'
          'L\'équipe OGEC Services';

      await _mailService.envoyerMailAvecPieceJointe(
        compte: account,
        destinataire: destinataire,
        objet: objet,
        corps: corps,
        nomFichier: fichier.name,
        pieceJointe: bytes,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('CERFA envoyé à $destinataire')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec de l\'envoi : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _envoiEnCours = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipements = _equipementsDuSite;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.site,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.client} — ${widget.site}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${equipements.length} équipement(s) sur ce site',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              const Text(
                'Équipement',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              ...equipements.map((e) {
                final selectionne =
                    _selectedEquipement?.nomEquipement == e.nomEquipement;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: selectionne ? Colors.blue.shade50 : null,
                  child: ListTile(
                    title: Text(e.nomEquipement),
                    subtitle: Text(e.reference.isEmpty ? '—' : e.reference),
                    onTap: () => _selectionnerEquipement(e),
                  ),
                );
              }),
              const SizedBox(height: 12),
              if (_selectedEquipement != null) ...[
                const Divider(),
                Text(
                  'CERFA finalisés — ${_selectedEquipement!.nomEquipement}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: _isRecherche
                    ? const Center(child: CircularProgressIndicator())
                    : (_selectedEquipement == null)
                    ? const SizedBox.shrink()
                    : _fichiers.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun CERFA trouvé pour cet équipement.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _fichiers.length,
                        itemBuilder: (context, index) {
                          final f = _fichiers[index];
                          final dateStr = f.modifiedTime != null
                              ? DateFormat('dd/MM/yyyy').format(f.modifiedTime!)
                              : '';
                          final enCours = _envoiEnCours == f.id;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(f.name),
                              subtitle: Text('Modifié le $dateStr'),
                              trailing: enCours
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : IconButton(
                                      icon: const Icon(
                                        Icons.send,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () => _ouvrirDialogueEnvoi(f),
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
