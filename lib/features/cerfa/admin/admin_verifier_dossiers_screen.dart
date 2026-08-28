import 'package:flutter/material.dart';
import '../models/equipement_model.dart';
import '../services/sheets_service.dart';
import '../services/admin_drive_service.dart';

class AdminVerifierDossiersScreen extends StatefulWidget {
  const AdminVerifierDossiersScreen({super.key});

  @override
  State<AdminVerifierDossiersScreen> createState() =>
      _AdminVerifierDossiersScreenState();
}

class _AdminVerifierDossiersScreenState
    extends State<AdminVerifierDossiersScreen> {
  final SheetsService _sheetsService = SheetsService();
  final AdminDriveService _driveService = AdminDriveService();

  bool _isLoadingEquipements = true;
  bool _isVerification = false;
  List<Equipement> _equipements = [];

  int _progresActuel = 0;
  int _progresTotal = 0;

  List<VerificationDossier>? _resultats;

  @override
  void initState() {
    super.initState();
    _chargerEquipements();
  }

  Future<void> _chargerEquipements() async {
    setState(() => _isLoadingEquipements = true);
    try {
      final data = await _sheetsService.getEquipements();
      setState(() {
        _equipements = data;
        _isLoadingEquipements = false;
      });
    } catch (e) {
      setState(() => _isLoadingEquipements = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de chargement : $e')));
      }
    }
  }

  Future<void> _lancerVerification() async {
    setState(() {
      _isVerification = true;
      _resultats = null;
      _progresActuel = 0;
      _progresTotal = _equipements.length;
    });

    final resultats = await _driveService.verifierDossiersServiceAccount(
      equipements: _equipements,
      onProgress: (actuel, total) {
        if (mounted) {
          setState(() {
            _progresActuel = actuel;
            _progresTotal = total;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isVerification = false;
        _resultats = resultats;
      });
    }
  }

  Widget _buildResultats() {
    final resultats = _resultats;
    if (resultats == null) return const SizedBox.shrink();

    final problematiques = resultats.where((r) => !r.ok).toList();
    final okCount = resultats.length - problematiques.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: problematiques.isEmpty
                ? Colors.green.shade50
                : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: problematiques.isEmpty
                  ? Colors.green.shade300
                  : Colors.orange.shade300,
            ),
          ),
          child: Row(
            children: [
              Icon(
                problematiques.isEmpty
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_outlined,
                color: problematiques.isEmpty ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  problematiques.isEmpty
                      ? 'Tous les dossiers sont en ordre ($okCount équipement(s)).'
                      : '$okCount en ordre  •  ${problematiques.length} avec un problème',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...problematiques.map((r) {
          final e = r.equipement;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.red.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${e.client} / ${e.site} / ${e.nomEquipement}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ...r.problemes.map(
                    (p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 16,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              p,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Vérifier les dossiers clients',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoadingEquipements
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vérifie, pour chaque équipement, le lien Drive, la '
                      'présence du modèle PDF, et les informations de '
                      'signataire (nom/email).',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${_equipements.length} équipement(s) à vérifier',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isVerification ? null : _lancerVerification,
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Lancer la vérification'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    if (_isVerification) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: _progresTotal == 0
                            ? null
                            : _progresActuel / _progresTotal,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vérification $_progresActuel / $_progresTotal...',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                    _buildResultats(),
                  ],
                ),
              ),
      ),
    );
  }
}
