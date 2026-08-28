import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cerfa_data_model.dart';
import '../models/equipement_model.dart';
import '../services/sheets_service.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import 'form_email_screen.dart';

class FormSignatureScreen extends StatefulWidget {
  final CerfaData cerfaData;

  const FormSignatureScreen({super.key, required this.cerfaData});

  @override
  State<FormSignatureScreen> createState() => _FormSignatureScreenState();
}

class _FormSignatureScreenState extends State<FormSignatureScreen> {
  final SheetsService _sheetsService = SheetsService();
  final FirestoreService _firestoreService = FirestoreService();
  final PdfService _pdfService = PdfService();

  bool _isLoadingSignataires = true;
  List<Equipement> _signatairesClient = [];
  String? _selectedSignataireKey;

  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _qualiteController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final SignatureController _sigOperateurController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final SignatureController _sigDetenteurController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _isSaving = false;
  String _etapeSauvegarde = '';
  bool _isLoadingTechnicien = true;
  String _operateurNom = '';
  String _operateurQualite = 'Frigoriste';
  final TextEditingController _operateurNomController = TextEditingController();
  bool _technicienExisteDeja = false;

  void _refreshDetenteur() => setState(() {});

  @override
  void initState() {
    super.initState();
    _nomController.addListener(_refreshDetenteur);
    _qualiteController.addListener(_refreshDetenteur);
    _loadSignataires();
    _loadTechnicien();
  }

  Future<void> _loadTechnicien() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoadingTechnicien = false);
      return;
    }
    try {
      final tech = await _firestoreService.getTechnicien(uid);
      if (tech != null && tech['nom']!.isNotEmpty) {
        setState(() {
          _operateurNom = tech['nom']!;
          _operateurQualite = tech['qualite']!;
          _technicienExisteDeja = true;
          _isLoadingTechnicien = false;
        });
      } else {
        setState(() {
          _technicienExisteDeja = false;
          _isLoadingTechnicien = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingTechnicien = false);
    }
  }

  Future<void> _saveTechnicienIfNeeded() async {
    if (_technicienExisteDeja) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final nom = _operateurNomController.text.trim();
    if (nom.isEmpty) return;
    await _firestoreService.saveTechnicien(uid, nom: nom);
    _operateurNom = nom;
  }

  Future<void> _loadSignataires() async {
    setState(() => _isLoadingSignataires = true);
    try {
      final all = await _sheetsService.getEquipements();
      final client = widget.cerfaData.equipement.client;
      final seen = <String>{};
      final result = <Equipement>[];
      for (final e in all) {
        if (e.client != client) continue;
        if (e.nomSignataireClient.trim().isEmpty) continue;
        final key = '${e.nomSignataireClient}|${e.qualiteSignataire}';
        if (seen.add(key)) result.add(e);
      }
      setState(() {
        _signatairesClient = result;
        _isLoadingSignataires = false;
      });

      final preNom = widget.cerfaData.nomSignataireClient;
      if (preNom.isNotEmpty) {
        final match = result.where((e) => e.nomSignataireClient == preNom);
        if (match.isNotEmpty) {
          final m = match.first;
          setState(() {
            _selectedSignataireKey =
                '${m.nomSignataireClient} – ${m.qualiteSignataire}';
            _nomController.text = m.nomSignataireClient;
            _qualiteController.text = m.qualiteSignataire;
            _emailController.text = m.emailSignataireClient;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoadingSignataires = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement signataires : $e')),
        );
      }
    }
  }

  void _onSignataireSelected(String? key) {
    setState(() => _selectedSignataireKey = key);
    if (key == '__new__' || key == null) {
      _nomController.clear();
      _qualiteController.clear();
      _emailController.clear();
      return;
    }
    final match = _signatairesClient.firstWhere(
      (e) => '${e.nomSignataireClient} – ${e.qualiteSignataire}' == key,
    );
    _nomController.text = match.nomSignataireClient;
    _qualiteController.text = match.qualiteSignataire;
    _emailController.text = match.emailSignataireClient;
  }

  // === Déclaration annuelle des quantités (colonnes Y/Z/AA/AB) ===
  // Une seule colonne "chargé" et une seule colonne "récupéré" reçoit une
  // valeur par finalisation. Priorité : "neufs" prime sur "maintenance"
  // pour le fluide chargé ; "maintenance" prime sur "hors d'usage" pour
  // le fluide récupéré.
  String _qteChargeesNeufs(CerfaData d) {
    if (d.caseAssemblage || d.caseMiseService) return d.quantite;
    return '';
  }

  String _qteChargeesMaintenance(CerfaData d) {
    if (d.caseAssemblage || d.caseMiseService) return '';
    if (d.caseModif || d.caseMaintenance || d.caseCtrlPerio) return d.quantite;
    return '';
  }

  String _qteRecupMaintenance(CerfaData d) {
    if (d.caseModif || d.caseMaintenance || d.caseCtrlPerio) return d.qde;
    return '';
  }

  String _qteRecupHorsUsage(CerfaData d) {
    if (d.caseModif || d.caseMaintenance || d.caseCtrlPerio) return '';
    if (d.caseDemantel) return d.qde;
    return '';
  }

  Future<void> _onValider() async {
    if (!_technicienExisteDeja && _operateurNomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner votre nom (technicien)'),
        ),
      );
      return;
    }
    if (_nomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner le nom du signataire'),
        ),
      );
      return;
    }
    if (_sigOperateurController.isEmpty || _sigDetenteurController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez effectuer la signature avant de valider'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _etapeSauvegarde = 'Attribution du numéro de CERFA...';
    });

    try {
      await _saveTechnicienIfNeeded();

      final e = widget.cerfaData.equipement;
      final chrono = await _firestoreService.incrementChrono();
      final chronoStr = _firestoreService.formatChrono(chrono);
      final ficheNo = _firestoreService.formatFicheNo(chrono);
      final nomFichier = _firestoreService.generateFileName(
        chrono: chrono,
        numeroClient: e.numeroClient,
        numeroSite: e.numeroSite,
        nomEquipement: e.nomEquipement,
      );

      final opBytes = await _sigOperateurController.toPngBytes();
      final detBytes = await _sigDetenteurController.toPngBytes();
      final now = DateTime.now();
      final today = DateFormat('dd/MM/yyyy').format(now);

      final data = widget.cerfaData
        ..chrono = chrono
        ..chronoStr = chronoStr
        ..ficheNo = ficheNo
        ..nomFichier = nomFichier
        ..nomSignataireClient = _nomController.text.trim()
        ..qualiteSignataire = _qualiteController.text.trim()
        ..emailSignataireClient = _emailController.text.trim()
        ..signOperateurNom = _operateurNom
        ..signOperateurQualite = _operateurQualite
        ..signOperateurDate = today
        ..signDetenteurNom = _nomController.text.trim()
        ..signDetenteurQualite = _qualiteController.text.trim()
        ..signDetenteurDate = today
        ..signatureOperateurImage = opBytes
        ..signatureDetenteurImage = detBytes
        ..statut = 'Finalisé';

      final chargeOriginaleVide = data.equipement.charge.trim().isEmpty;
      final chargeValue =
          double.tryParse(data.equipementCharge.replaceAll(',', '.')) ?? 0;

      final moisAAjouter = chargeValue >= 30 ? 6 : 12;
      final prochainControle = DateTime(
        now.year,
        now.month + moisAAjouter,
        now.day,
      );
      final dateProchainControle = DateFormat(
        'dd/MM/yyyy',
      ).format(prochainControle);

      final annee = now.year.toString().substring(2);
      final clientStr = data.equipement.numeroClient.padLeft(3, '0');
      final siteStr = data.equipement.numeroSite.padLeft(2, '0');
      final numeroBordereau =
          '$annee-${data.chronoStr}-$clientStr-$siteStr-${data.equipement.nomEquipement}';

      setState(
        () => _etapeSauvegarde = 'Mise à jour de la base équipements...',
      );
      try {
        await _sheetsService.updateEquipementApresFinalisation(
          rowIndex: data.equipement.rowIndex,
          marque: data.equipementMarque,
          marqueEtaitVide: data.equipement.marque.trim().isEmpty,
          dateMES: data.equipementDateMES,
          dateMESEtaitVide: data.equipement.dateMES.trim().isEmpty,
          reference: data.equipementReference,
          referenceEtaitVide: data.equipement.reference.trim().isEmpty,
          localisation: data.equipementLocalisation,
          localisationEtaitVide: data.equipement.localisation.trim().isEmpty,
          refrigerant: data.equipementFluide,
          refrigerantEtaitVide: data.equipement.refrigerants.trim().isEmpty,
          charge: data.equipementCharge,
          chargeEtaitVide: chargeOriginaleVide,
          dateDernierControle: today,
          dateProchainControle: dateProchainControle,
          numeroBordereau: numeroBordereau,
          nomSignataire: data.nomSignataireClient,
          qualiteSignataire: data.qualiteSignataire,
          emailSignataire: data.emailSignataireClient,
          operateur: _operateurNom,
          qteChargeesNeufs: _qteChargeesNeufs(data),
          qteChargeesMaintenance: _qteChargeesMaintenance(data),
          qteRecupMaintenance: _qteRecupMaintenance(data),
          qteRecupHorsUsage: _qteRecupHorsUsage(data),
        );
      } catch (sheetError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Base équipements non mise à jour ($sheetError) — le PDF va tout de même être généré.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      setState(() => _etapeSauvegarde = 'Génération du PDF CERFA...');
      await _pdfService.genererEtEnvoyerCerfa(
        data: data,
        cheminRepertoireUrl: data.equipement.lienRepertoireDrive,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => FormEmailScreen(cerfaData: data),
        ),
      );
    } catch (e) {
      setState(() {
        _isSaving = false;
        _etapeSauvegarde = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération du CERFA : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSignaturePad({
    required String titre,
    required SignatureController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titre,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue.shade200),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade50,
          ),
          child: Signature(
            controller: controller,
            backgroundColor: Colors.grey.shade50,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => controller.clear(),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Effacer'),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nomController.removeListener(_refreshDetenteur);
    _qualiteController.removeListener(_refreshDetenteur);
    _nomController.dispose();
    _qualiteController.dispose();
    _emailController.dispose();
    _operateurNomController.dispose();
    _sigOperateurController.dispose();
    _sigDetenteurController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final e = widget.cerfaData.equipement;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Écran 5b : Signature',
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
                      'Identification du signataire client',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingSignataires)
                      const Center(child: CircularProgressIndicator())
                    else
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Signataire connu',
                          border: OutlineInputBorder(),
                        ),
                        initialValue: _selectedSignataireKey,
                        items: [
                          ..._signatairesClient.map((s) {
                            final key =
                                '${s.nomSignataireClient} – ${s.qualiteSignataire}';
                            return DropdownMenuItem(
                              value: key,
                              child: Text(key),
                            );
                          }),
                          const DropdownMenuItem(
                            value: '__new__',
                            child: Text('+ Nouveau signataire'),
                          ),
                        ],
                        onChanged: _onSignataireSelected,
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nomController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du signataire',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _qualiteController,
                      decoration: const InputDecoration(
                        labelText: 'Qualité du signataire',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Je soussigné certifie que l\'opération ci-dessus a été effectuée.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Opérateur',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingTechnicien)
                      const Center(child: CircularProgressIndicator())
                    else if (_technicienExisteDeja) ...[
                      Text('Nom : $_operateurNom'),
                      Text('Qualité : $_operateurQualite'),
                    ] else ...[
                      const Text(
                        'Première utilisation : renseignez votre nom (sera mémorisé)',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _operateurNomController,
                        decoration: const InputDecoration(
                          labelText: 'Votre nom complet',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Qualité : Frigoriste'),
                    ],
                    Text('Date : $today'),
                    const SizedBox(height: 8),
                    _buildSignaturePad(
                      titre: 'Signature Opérateur',
                      controller: _sigOperateurController,
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Détenteur',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${e.client} – ${e.site}'),
                    Text(
                      _nomController.text.trim().isEmpty
                          ? 'Nom : —'
                          : 'Nom : ${_nomController.text}',
                    ),
                    Text(
                      _qualiteController.text.trim().isEmpty
                          ? 'Qualité : —'
                          : 'Qualité : ${_qualiteController.text}',
                    ),
                    Text('Date : $today'),
                    const SizedBox(height: 8),
                    _buildSignaturePad(
                      titre: 'Signature Détenteur',
                      controller: _sigDetenteurController,
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.red, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Retour',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _onValider,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                                if (_etapeSauvegarde.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      _etapeSauvegarde,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : const Text(
                              'Valider',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
