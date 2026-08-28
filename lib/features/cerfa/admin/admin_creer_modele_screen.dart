import 'package:flutter/material.dart';
import '../../../core/auth/admin_google_session.dart';
import '../models/equipement_model.dart';
import '../services/sheets_service.dart';
import '../services/admin_drive_service.dart';
import 'admin_creer_modele_site_screen.dart';

class AdminCreerModeleScreen extends StatefulWidget {
  const AdminCreerModeleScreen({super.key});

  @override
  State<AdminCreerModeleScreen> createState() => _AdminCreerModeleScreenState();
}

class _AdminCreerModeleScreenState extends State<AdminCreerModeleScreen> {
  final SheetsService _sheetsService = SheetsService();
  final AdminDriveService _driveService = AdminDriveService();

  bool _isLoadingEquipements = true;
  bool _isTraitement = false;
  List<Equipement> _equipements = [];

  ResultatCreationModeles? _dernierResultat;

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

  List<String> get _clients {
    return _equipements.map((e) => e.client).toSet().toList()..sort();
  }

  Future<void> _lancerPourTousLesClients() async {
    setState(() {
      _isTraitement = true;
      _dernierResultat = null;
    });

    try {
      final account = await AdminGoogleSession.instance.ensureSignedIn(context);
      final resultat = await _driveService.creerModelesPourEquipements(
        adminAccount: account,
        equipements: _equipements,
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

  void _ouvrirClient(String client) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminCreerModeleSiteScreen(
          client: client,
          equipements: _equipements,
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
        title: const Text(
          'Créer modèle CERFA',
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
                      'Choisissez le périmètre de création des modèles. '
                      'À chaque étape, vous pouvez tout traiter d\'un coup '
                      'ou affiner en choisissant un client, puis un site, '
                      'puis un équipement.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isTraitement
                            ? null
                            : _lancerPourTousLesClients,
                        icon: const Icon(Icons.done_all),
                        label: Text(
                          'Tous les clients (${_equipements.length} équipement(s))',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const Divider(height: 40),
                    const Text(
                      'Ou affiner par client',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Autocomplete<String>(
                      optionsBuilder: (value) {
                        if (value.text.isEmpty) return _clients;
                        final q = value.text.toLowerCase();
                        return _clients.where(
                          (c) => c.toLowerCase().contains(q),
                        );
                      },
                      onSelected: _ouvrirClient,
                      fieldViewBuilder: (context, controller, focusNode, _) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Client',
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
