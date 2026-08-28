import 'package:flutter/material.dart';
import '../../../core/auth/admin_google_session.dart';
import '../models/equipement_model.dart';
import '../services/admin_drive_service.dart';

class AdminCreerModeleEquipementScreen extends StatefulWidget {
  final String client;
  final String site;
  final List<Equipement> equipements; // liste complète, non filtrée

  const AdminCreerModeleEquipementScreen({
    super.key,
    required this.client,
    required this.site,
    required this.equipements,
  });

  @override
  State<AdminCreerModeleEquipementScreen> createState() =>
      _AdminCreerModeleEquipementScreenState();
}

class _AdminCreerModeleEquipementScreenState
    extends State<AdminCreerModeleEquipementScreen> {
  final AdminDriveService _driveService = AdminDriveService();

  bool _isTraitement = false;
  ResultatCreationModeles? _dernierResultat;

  List<Equipement> get _equipementsDuSite => widget.equipements
      .where((e) => e.client == widget.client && e.site == widget.site)
      .toList();

  Future<void> _lancer(List<Equipement> cible) async {
    setState(() {
      _isTraitement = true;
      _dernierResultat = null;
    });

    try {
      final account = await AdminGoogleSession.instance.ensureSignedIn(context);
      final resultat = await _driveService.creerModelesPourEquipements(
        adminAccount: account,
        equipements: cible,
      );

      if (mounted) {
        setState(() {
          _isTraitement = false;
          _dernierResultat = resultat;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTraitement = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildResultat() {
    final r = _dernierResultat;
    if (r == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Créés : ${r.crees}  •  Remplacés : ${r.remplaces}  •  Erreurs : ${r.erreurs}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...r.messages.map(
            (m) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(m, style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
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
        child: SingleChildScrollView(
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isTraitement ? null : () => _lancer(equipements),
                  icon: const Icon(Icons.done_all),
                  label: Text('Tout le site ${widget.site}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const Divider(height: 40),
              const Text(
                'Ou choisir un équipement précis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              ...equipements.map((e) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(e.nomEquipement),
                    subtitle: Text(e.reference.isEmpty ? '—' : e.reference),
                    trailing: _isTraitement
                        ? null
                        : IconButton(
                            icon: const Icon(
                              Icons.note_add_outlined,
                              color: Colors.blue,
                            ),
                            onPressed: () => _lancer([e]),
                            tooltip: 'Créer le modèle pour cet équipement',
                          ),
                  ),
                );
              }),
              if (_isTraitement)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              _buildResultat(),
            ],
          ),
        ),
      ),
    );
  }
}
