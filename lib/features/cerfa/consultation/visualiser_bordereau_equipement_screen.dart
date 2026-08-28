import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/equipement_model.dart';
import '../services/technicien_drive_service.dart';

class VisualiserBordereauEquipementScreen extends StatefulWidget {
  final String client;
  final String site;
  final List<Equipement> equipements;

  const VisualiserBordereauEquipementScreen({
    super.key,
    required this.client,
    required this.site,
    required this.equipements,
  });

  @override
  State<VisualiserBordereauEquipementScreen> createState() =>
      _VisualiserBordereauEquipementScreenState();
}

class _VisualiserBordereauEquipementScreenState
    extends State<VisualiserBordereauEquipementScreen> {
  final TechnicienDriveService _driveService = TechnicienDriveService();

  Equipement? _selectedEquipement;
  bool _isRecherche = false;
  String? _ouvertureEnCours;
  List<FichierCerfa> _fichiers = [];

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
      final fichiers = await _driveService.listerCerfaFinalises(e);
      setState(() {
        _fichiers = fichiers;
        _isRecherche = false;
      });
    } catch (err) {
      setState(() => _isRecherche = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de recherche : $err')));
      }
    }
  }

  Future<void> _ouvrirFichier(FichierCerfa fichier) async {
    setState(() => _ouvertureEnCours = fichier.id);
    try {
      final bytes = await _driveService.telechargerFichier(fichier.id);
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'ouvrir le fichier : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _ouvertureEnCours = null);
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
                          final enCours = _ouvertureEnCours == f.id;
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
                                        Icons.visibility_outlined,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () => _ouvrirFichier(f),
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
