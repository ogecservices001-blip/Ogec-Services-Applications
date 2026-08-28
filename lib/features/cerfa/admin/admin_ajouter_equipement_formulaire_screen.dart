import 'package:flutter/material.dart';
import '../../../core/auth/admin_google_session.dart';
import '../models/equipement_model.dart';
import '../services/sheets_service.dart';
import '../services/admin_drive_service.dart';

class AdminAjouterEquipementFormulaireScreen extends StatefulWidget {
  final bool clientNouveau;
  final bool siteNouveau;
  final String? clientExistant;
  final String? siteExistant;
  final Equipement? equipementExemple;

  const AdminAjouterEquipementFormulaireScreen({
    super.key,
    required this.clientNouveau,
    required this.siteNouveau,
    this.clientExistant,
    this.siteExistant,
    this.equipementExemple,
  });

  @override
  State<AdminAjouterEquipementFormulaireScreen> createState() =>
      _AdminAjouterEquipementFormulaireScreenState();
}

class _AdminAjouterEquipementFormulaireScreenState
    extends State<AdminAjouterEquipementFormulaireScreen> {
  final SheetsService _sheetsService = SheetsService();
  final AdminDriveService _driveService = AdminDriveService();

  final _clientController = TextEditingController();
  final _siteController = TextEditingController();
  final _numeroClientController = TextEditingController();
  final _numeroSiteController = TextEditingController();
  final _numeroChantierController = TextEditingController();
  final _nomEquipementController = TextEditingController();
  final _marqueController = TextEditingController();
  final _dateMESController = TextEditingController();
  final _referenceController = TextEditingController();
  final _localisationController = TextEditingController();
  final _refrigerantsController = TextEditingController();
  final _chargeController = TextEditingController();
  final _adresseController = TextEditingController();
  final _complementAdresseController = TextEditingController();
  final _codePostalController = TextEditingController();
  final _communeController = TextEditingController();
  final _nomSignataireController = TextEditingController();
  final _qualiteSignataireController = TextEditingController();
  final _emailSignataireController = TextEditingController();

  /// Lien Drive : automatique, jamais saisi à la main.
  String _lienDrive = '';

  bool _isSaving = false;
  String _etape = '';

  bool get _dossierAuCree => widget.clientNouveau || widget.siteNouveau;

  @override
  void initState() {
    super.initState();
    if (widget.clientExistant != null) {
      _clientController.text = widget.clientExistant!;
    }
    if (widget.siteExistant != null) {
      _siteController.text = widget.siteExistant!;
    }
    final ex = widget.equipementExemple;
    if (ex != null) {
      _numeroClientController.text = ex.numeroClient;
      _numeroSiteController.text = ex.numeroSite;
      _adresseController.text = ex.adresse;
      _complementAdresseController.text = ex.complementAdresse;
      _codePostalController.text = ex.codePostal;
      _communeController.text = ex.commune;
      _nomSignataireController.text = ex.nomSignataireClient;
      _qualiteSignataireController.text = ex.qualiteSignataire;
      _emailSignataireController.text = ex.emailSignataireClient;
      _lienDrive = ex.lienRepertoireDrive;
    }
  }

  @override
  void dispose() {
    _clientController.dispose();
    _siteController.dispose();
    _numeroClientController.dispose();
    _numeroSiteController.dispose();
    _numeroChantierController.dispose();
    _nomEquipementController.dispose();
    _marqueController.dispose();
    _dateMESController.dispose();
    _referenceController.dispose();
    _localisationController.dispose();
    _refrigerantsController.dispose();
    _chargeController.dispose();
    _adresseController.dispose();
    _complementAdresseController.dispose();
    _codePostalController.dispose();
    _communeController.dispose();
    _nomSignataireController.dispose();
    _qualiteSignataireController.dispose();
    _emailSignataireController.dispose();
    super.dispose();
  }

  Widget _champ(
    TextEditingController c,
    String label, {
    bool required = false,
    TextInputType? type,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Future<void> _creer() async {
    if (_clientController.text.trim().isEmpty ||
        _siteController.text.trim().isEmpty ||
        _numeroClientController.text.trim().isEmpty ||
        _numeroSiteController.text.trim().isEmpty ||
        _numeroChantierController.text.trim().isEmpty ||
        _nomEquipementController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Merci de remplir au minimum : Client, Site, Numéro Client, '
            'Numéro Site, Numéro Chantier et Nom Équipement.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String lienDrive = _lienDrive;

      // Les deux appels Drive (création du dossier de site et dépôt du
      // modèle CERFA) nécessitent le compte Google admin — contrairement
      // à l'écriture dans le Sheet ci-dessous, qui reste sur le compte de
      // service et ne doit jamais déclencher la connexion Google.
      final account = await AdminGoogleSession.instance.ensureSignedIn(context);

      if (_dossierAuCree) {
        setState(() => _etape = 'Création du dossier Drive...');
        lienDrive = await _driveService.obtenirOuCreerDossierSite(
          adminAccount: account,
          numeroChantier: _numeroChantierController.text.trim(),
          client: _clientController.text.trim(),
          site: _siteController.text.trim(),
        );
        setState(() => _lienDrive = lienDrive);
      }

      if (lienDrive.isEmpty) {
        throw Exception(
          'Aucun dossier Drive disponible pour ce site — impossible de continuer.',
        );
      }

      setState(() => _etape = 'Ajout de la ligne dans le Sheet...');

      final rowIndex = await _sheetsService.ajouterEquipement(
        client: _clientController.text.trim(),
        site: _siteController.text.trim(),
        numeroClient: _numeroClientController.text.trim(),
        numeroSite: _numeroSiteController.text.trim(),
        numeroChantier: _numeroChantierController.text.trim(),
        nomEquipement: _nomEquipementController.text.trim(),
        marque: _marqueController.text.trim(),
        dateMES: _dateMESController.text.trim(),
        reference: _referenceController.text.trim(),
        localisation: _localisationController.text.trim(),
        refrigerants: _refrigerantsController.text.trim(),
        charge: _chargeController.text.trim(),
        adresse: _adresseController.text.trim(),
        complementAdresse: _complementAdresseController.text.trim(),
        codePostal: _codePostalController.text.trim(),
        commune: _communeController.text.trim(),
        lienRepertoireDrive: lienDrive,
        nomSignataireClient: _nomSignataireController.text.trim(),
        qualiteSignataire: _qualiteSignataireController.text.trim(),
        emailSignataireClient: _emailSignataireController.text.trim(),
      );

      final nouvelEquipement = Equipement(
        client: _clientController.text.trim(),
        site: _siteController.text.trim(),
        numeroClient: _numeroClientController.text.trim(),
        numeroSite: _numeroSiteController.text.trim(),
        numeroChantier: _numeroChantierController.text.trim(),
        nomEquipement: _nomEquipementController.text.trim(),
        marque: _marqueController.text.trim(),
        dateMES: _dateMESController.text.trim(),
        reference: _referenceController.text.trim(),
        localisation: _localisationController.text.trim(),
        refrigerants: _refrigerantsController.text.trim(),
        charge: _chargeController.text.trim(),
        adresse: _adresseController.text.trim(),
        complementAdresse: _complementAdresseController.text.trim(),
        codePostal: _codePostalController.text.trim(),
        commune: _communeController.text.trim(),
        dateDernierControle: '',
        dateProchainControle: '',
        numeroDernierBordereau: '',
        lienRepertoireDrive: lienDrive,
        nomSignataireClient: _nomSignataireController.text.trim(),
        qualiteSignataire: _qualiteSignataireController.text.trim(),
        emailSignataireClient: _emailSignataireController.text.trim(),
        operateur: '',
        rowIndex: rowIndex,
      );

      setState(() => _etape = 'Création du modèle CERFA sur Drive...');

      final resultat = await _driveService.creerModelesPourEquipements(
        adminAccount: account,
        equipements: [nouvelEquipement],
      );

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _etape = '';
      });

      final okModele = resultat.erreurs == 0;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(okModele ? 'Équipement créé' : 'Créé avec un problème'),
          content: Text(
            'Ligne ajoutée au Sheet (ligne $rowIndex).\n'
            'Dossier Drive : $lienDrive\n\n'
            '${resultat.messages.join('\n')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _etape = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientVerrouille = !widget.clientNouveau;
    final siteVerrouille = !widget.siteNouveau && !widget.clientNouveau;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Nouvel équipement',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Identification',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _clientController,
                      enabled: !clientVerrouille,
                      decoration: const InputDecoration(
                        labelText: 'Client *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _siteController,
                      enabled: !siteVerrouille,
                      decoration: const InputDecoration(
                        labelText: 'Site *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _champ(
                      _numeroClientController,
                      'Numéro Client',
                      required: true,
                    ),
                    _champ(
                      _numeroSiteController,
                      'Numéro Site',
                      required: true,
                    ),
                    _champ(
                      _numeroChantierController,
                      'Numéro Chantier',
                      required: true,
                    ),
                    _champ(
                      _nomEquipementController,
                      'Nom Équipement',
                      required: true,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Caractéristiques équipement',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _champ(_marqueController, 'Marque'),
                    _champ(_dateMESController, 'Date M.E.S. (jj/mm/aaaa)'),
                    _champ(_referenceController, 'Référence'),
                    _champ(_localisationController, 'Localisation'),
                    _champ(_refrigerantsController, 'Réfrigérant (ex: R-410A)'),
                    _champ(
                      _chargeController,
                      'Charge (kg)',
                      type: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Adresse du site',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _champ(_adresseController, 'Adresse'),
                    _champ(
                      _complementAdresseController,
                      'Complément d\'adresse',
                    ),
                    _champ(_codePostalController, 'Code Postal'),
                    _champ(_communeController, 'Commune'),
                    const SizedBox(height: 12),
                    const Text(
                      'Drive & signataire',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_outlined, color: Colors.blue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _dossierAuCree
                                  ? 'Le dossier Drive sera créé automatiquement '
                                        '(Numéro Chantier-Client-Site) à la '
                                        'validation.'
                                  : (_lienDrive.isEmpty
                                        ? 'Aucun dossier Drive trouvé pour ce site.'
                                        : 'Dossier existant réutilisé :\n$_lienDrive'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _champ(_nomSignataireController, 'Nom Signataire client'),
                    _champ(
                      _qualiteSignataireController,
                      'Qualité du Signataire',
                    ),
                    _champ(
                      _emailSignataireController,
                      'Email Signataire client',
                      type: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _creer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            if (_etape.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  _etape,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        )
                      : const Text(
                          'Créer l\'équipement',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
