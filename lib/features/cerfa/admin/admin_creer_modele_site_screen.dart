import 'package:flutter/material.dart';
import '../../../core/auth/admin_google_session.dart';
import '../models/equipement_model.dart';
import '../services/admin_drive_service.dart';
import 'admin_creer_modele_equipement_screen.dart';

class AdminCreerModeleSiteScreen extends StatefulWidget {
  final String client;
  final List<Equipement> equipements; // liste complète, non filtrée

  const AdminCreerModeleSiteScreen({
    super.key,
    required this.client,
    required this.equipements,
  });

  @override
  State<AdminCreerModeleSiteScreen> createState() =>
      _AdminCreerModeleSiteScreenState();
}

class _AdminCreerModeleSiteScreenState
    extends State<AdminCreerModeleSiteScreen> {
  final AdminDriveService _driveService = AdminDriveService();

  bool _isTraitement = false;
  ResultatCreationModeles? _dernierResultat;

  List<Equipement> get _equipementsDuClient =>
      widget.equipements.where((e) => e.client == widget.client).toList();

  List<String> get _sites {
    return _equipementsDuClient.map((e) => e.site).toSet().toList()..sort();
  }

  Future<void> _lancerPourTousLesSites() async {
    setState(() {
      _isTraitement = true;
      _dernierResultat = null;
    });

    try {
      final account = await AdminGoogleSession.instance.ensureSignedIn(context);
      final resultat = await _driveService.creerModelesPourEquipements(
        adminAccount: account,
        equipements: _equipementsDuClient,
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

  void _ouvrirSite(String site) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminCreerModeleEquipementScreen(
          client: widget.client,
          site: site,
          equipements: widget.equipements,
        ),
      ),
    );
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.client,
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
                '${_equipementsDuClient.length} équipement(s) pour ${widget.client}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isTraitement ? null : _lancerPourTousLesSites,
                  icon: const Icon(Icons.done_all),
                  label: Text('Tout le client ${widget.client}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const Divider(height: 40),
              const Text(
                'Ou affiner par site',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              Autocomplete<String>(
                optionsBuilder: (value) {
                  if (value.text.isEmpty) return _sites;
                  final q = value.text.toLowerCase();
                  return _sites.where((s) => s.toLowerCase().contains(q));
                },
                onSelected: _ouvrirSite,
                fieldViewBuilder: (context, controller, focusNode, _) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Site',
                      hintText: 'Tapez pour rechercher...',
                      border: OutlineInputBorder(),
                    ),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              dense: true,
                              title: Text(option),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
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
