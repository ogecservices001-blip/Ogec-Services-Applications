import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';
import '../../../core/services/user_service.dart';
import '../../affaires/client_affaires_list_screen.dart';
import '../../affaires/data/affaire_model.dart';
import '../../affaires/travaux_clients_screen.dart';
import '../../annuaire/clients/client_model.dart';
import '../../gmao/equipements/equipement_model.dart';
import '../../gmao/gmao_database_service.dart';
import '../../gmao/types_equipement/type_equipement_model.dart';
import '../data/bi_constants.dart';
import '../data/bi_format.dart';
import '../data/bi_model.dart';
import '../data/bi_photo_service.dart';
import '../data/bi_service.dart';
import '../pdf/bi_pdf_generator.dart';
import 'bi_client_picker_screen.dart';
import 'bi_equipement_picker_screen.dart';
import 'bi_technicien_picker_screen.dart';

const Color biAccent = Colors.deepPurple;

/// Assistant technicien en 5 étapes pour créer un bon d'intervention —
/// porté depuis re.ogec.bi (WizardScreens.kt/AppViewModel.kt). Phase 1 :
/// pas encore de génération PDF ni d'archivage Drive, seulement la
/// saisie et la transmission au bureau.
class BiWizardScreen extends StatefulWidget {
  const BiWizardScreen({super.key});

  @override
  State<BiWizardScreen> createState() => _BiWizardScreenState();
}

class _BiWizardScreenState extends State<BiWizardScreen> {
  final BiService _biService = BiService();
  final UserService _userService = UserService();
  final BiPhotoService _photoService = BiPhotoService();
  final GmaoDatabaseService _gmaoDb = GmaoDatabaseService();

  int _etape = 0;
  static const _totalEtapes = 5;
  bool _enregistrementEnCours = false;
  bool _apercuEnCours = false;

  // ---------- Étape 0 : Pôle + Client ----------
  String _pole = '';
  int _chrono = 0;
  String _numero = '';
  bool _numeroProvisoire = false;
  bool _allocationEnCours = false;

  ClientModel? _client;
  EquipementModel? _equipement;

  // Devis (Affaire) et équipement — pertinents selon le pôle choisi,
  // voir Poles.avecAffaire/avecEquipementObligatoire.
  AffaireModel? _affaire;

  // Familles du Référentiel équipements (GMAO) — chargées une fois, pour
  // le choix (Installation neuve) ou la résolution automatique
  // (Remplacement à l'identique, depuis l'équipement choisi) de la
  // famille active, dont les champs déterminent dynamiquement le
  // formulaire matériel ci-dessous (voir Poles.avecNouvelEquipement /
  // _pole == remplacementIdentique).
  List<TypeEquipementModel> _typesEquipement = [];
  TypeEquipementModel? _typeActif;
  final Map<String, dynamic> _materielChampsEnTete = {};
  final Map<String, TextEditingController> _materielControllers = {};

  // Pôle Installation neuve uniquement — identité du nouveau matériel
  // (pas d'équipement existant à choisir, voir Poles.avecNouvelEquipement).
  final _installationNomController = TextEditingController();
  final _installationLocalisationController = TextEditingController();
  final _installationGroupeController = TextEditingController();

  // Pôle Réparation diverse uniquement — équipement non répertorié dans
  // le parc GMAO, décrit à la main (voir Poles.avecEquipementLibre).
  final _equipementLibreController = TextEditingController();

  final _emailController = TextEditingController();

  // ---------- Étape 1 : Techniciens + Dates ----------
  final List<String> _techniciens = [];
  // Celui qui remplit le bon et signe réellement — distinct de la liste
  // ci-dessus (tous ceux intervenus sur place).
  String _technicienConnecte = '';
  String _dateDebut = BiFormat.today();
  String _dateFin = BiFormat.today();
  String _dateIntervention = BiFormat.today();
  final _tempsPasseController = TextEditingController();
  bool _tempsManuel = false;

  // ---------- Étape 2 : Compte rendu + photos ----------
  final _compteRenduController = TextEditingController();
  final _obsTechController = TextEditingController();
  final _obsClientController = TextEditingController();
  final List<PhotoBI> _photos = [];
  final Map<int, Uint8List> _apercusPhotos = {};
  final Set<int> _photosEnCours = {};

  // ---------- Étape 4 : Signatures ----------
  final _signataireController = TextEditingController();
  final _signataireTelPortableController = TextEditingController();
  final _signataireTelFixeController = TextEditingController();
  final SignatureController _sigTechController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final SignatureController _sigClientController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void initState() {
    super.initState();
    _preremplirTechnicien();
    _chargerTypesEquipement();
  }

  Future<void> _chargerTypesEquipement() async {
    final types = await _gmaoDb.getTypesEquipement().first;
    if (mounted) setState(() => _typesEquipement = types);
  }

  Future<void> _preremplirTechnicien() async {
    final nom = await _userService.getCurrentUserName();
    if (nom.isNotEmpty && mounted) {
      setState(() {
        _techniciens.add(nom);
        _technicienConnecte = nom;
        _majTempsStandard();
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    for (final c in _materielControllers.values) {
      c.dispose();
    }
    _installationNomController.dispose();
    _installationLocalisationController.dispose();
    _installationGroupeController.dispose();
    _equipementLibreController.dispose();
    _tempsPasseController.dispose();
    _compteRenduController.dispose();
    _obsTechController.dispose();
    _obsClientController.dispose();
    _signataireController.dispose();
    _signataireTelPortableController.dispose();
    _signataireTelFixeController.dispose();
    _sigTechController.dispose();
    _sigClientController.dispose();
    super.dispose();
  }

  // ==================== Logique métier ====================

  void _choisirPole(String pole) {
    if (_pole == pole) return;
    setState(() {
      _pole = pole;
      _affaire = null;
      _equipement = null;
      _effacerRemplacement();
      // Pas encore de numéro réservé cette session : seul le segment
      // pôle du numéro déjà affiché change (voir _assurerNumero — le
      // vrai chrono n'est tiré qu'au premier enregistrement, pour ne
      // jamais créer de trou dans la numérotation sur un bon commencé
      // puis abandonné).
      if (_chrono != 0) _numero = BiFormat.numeroBI(pole, BiFormat.currentYear(), _chrono);
      // Une tuile de pôle est un choix net — on avance directement à
      // l'étape Client plutôt que de faire apparaître la suite sur la
      // même page.
      _etape = 1;
    });
    _majTempsStandard();
    _prefillCompteRenduEntretien();
  }

  /// Réserve le numéro du bon s'il ne l'est pas déjà — appelé juste
  /// avant le tout premier enregistrement (brouillon ou transmission),
  /// jamais avant : un bon commencé puis abandonné sans être enregistré
  /// ne consomme aucun numéro.
  Future<void> _assurerNumero() async {
    if (_chrono != 0) return;
    setState(() => _allocationEnCours = true);
    final annee = BiFormat.currentYear();
    try {
      final n = await _biService.allouerChrono(annee);
      setState(() {
        _chrono = n;
        _numeroProvisoire = false;
        _numero = BiFormat.numeroBI(_pole, annee, n);
      });
    } catch (_) {
      final n = DateTime.now().millisecondsSinceEpoch % 10000;
      setState(() {
        _chrono = n;
        _numeroProvisoire = true;
        _numero = BiFormat.numeroBI(_pole, annee, n);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hors ligne : numéro provisoire réservé, confirmé à la synchronisation.',
            ),
          ),
        );
      }
    }
    if (mounted) setState(() => _allocationEnCours = false);
  }

  void _effacerRemplacement() {
    _installationNomController.clear();
    _installationLocalisationController.clear();
    _installationGroupeController.clear();
    _equipementLibreController.clear();
    _typeActif = null;
    _reconstruireMateriel(null);
  }

  /// Champs de la famille pertinents pour le BI — exclut nom
  /// technicien/fréquence/date interv. prévue (voir champsMaterielExclusBI).
  List<ChampEnTete> _champsPertinents(TypeEquipementModel? type) =>
      (type?.champsEnTeteSupplementaires ?? const [])
          .where((c) => !champsMaterielExclusBI.contains(c.cle))
          .toList();

  /// Reconstruit les contrôleurs des champs spécifiques à la famille
  /// active — même principe que AjouterEquipementScreen : les champs
  /// changent avec la famille (Installation neuve : choisie par le
  /// technicien ; Remplacement à l'identique : celle de l'équipement
  /// choisi), donc les anciens contrôleurs ne correspondent plus.
  void _reconstruireMateriel(TypeEquipementModel? type) {
    for (final c in _materielControllers.values) {
      c.dispose();
    }
    _materielControllers.clear();
    _materielChampsEnTete.clear();
    for (final champ in _champsPertinents(type)) {
      if (champ.options.isEmpty) {
        // Date de mise en service : quasi toujours le jour de
        // l'intervention — pré-remplie mais modifiable.
        final valeurDefaut = champ.cle == 'dateMES' ? BiFormat.today() : '';
        _materielControllers[champ.cle] = TextEditingController(text: valeurDefaut);
        if (valeurDefaut.isNotEmpty) _materielChampsEnTete[champ.cle] = valeurDefaut;
      }
    }
  }

  void _preremplirDepuisSite(ClientModel site) {
    // Pré-rempli depuis la fiche Répertoire — reste modifiable, le
    // technicien corrige si l'interlocuteur présent sur place n'est
    // pas celui enregistré.
    _signataireController.text = site.interlocuteurSite;
    _signataireTelPortableController.text = site.portableInterlocuteurSite;
    _signataireTelFixeController.text = site.telFixeInterlocuteurSite;
    _emailController.text = site.courrielInterlocuteurSite;
  }

  Future<void> _choisirClient() async {
    // Pôles avec devis : le client se choisit en passant directement par
    // le Répertoire Travaux Clients — c'est sa raison d'être — plutôt
    // qu'un picker dédié ; il renvoie client + affaire choisis ensemble.
    if (Poles.avecAffaire(_pole)) {
      final resultat = await Navigator.push<(ClientModel, AffaireModel)>(
        context,
        MaterialPageRoute(
          builder: (context) => TravauxClientsScreen(modeSelection: true, natureFiltre: _pole),
        ),
      );
      if (resultat != null && mounted) {
        final (site, affaire) = resultat;
        setState(() {
          _client = site;
          _affaire = affaire;
          _equipement = null;
          _effacerRemplacement();
          _preremplirDepuisSite(site);
        });
      }
      return;
    }

    final site = await Navigator.push<ClientModel>(
      context,
      MaterialPageRoute(builder: (context) => const BiClientPickerScreen()),
    );
    if (site != null && mounted) {
      setState(() {
        _client = site;
        _equipement = null;
        _affaire = null;
        _effacerRemplacement();
        _preremplirDepuisSite(site);
      });
      _prefillCompteRenduEntretien();
    }
  }

  /// Pôle Entretien sous contrat uniquement : pré-remplit le compte
  /// rendu avec un texte type ("Entretien semestriel de X climatiseurs
  /// autonomes, Y brasseurs d'air.") construit en comptant les
  /// équipements du site par famille et en retenant leur fréquence
  /// d'entretien annuelle dominante — reste ensuite librement modifiable
  /// par le technicien, jamais réécrit si déjà saisi.
  Future<void> _prefillCompteRenduEntretien() async {
    if (_pole != Poles.entretienSousContrat) return;
    final client = _client;
    if (client == null) return;
    if (_compteRenduController.text.trim().isNotEmpty) return;
    final equipements = await _gmaoDb.getEquipementsForClient(client.id).first;
    final types = await _gmaoDb.getTypesEquipement().first;
    if (!mounted) return;
    if (_pole != Poles.entretienSousContrat || _client?.id != client.id) return;
    final texte = _texteEntretienAuto(equipements, types);
    if (texte.isNotEmpty && _compteRenduController.text.trim().isEmpty) {
      setState(() => _compteRenduController.text = texte);
    }
  }

  String _texteEntretienAuto(List<EquipementModel> equipements, List<TypeEquipementModel> types) {
    if (equipements.isEmpty) return '';
    final typesById = {for (final t in types) t.id: t};
    final comptes = <String, int>{};
    final freqCount = <int, int>{};
    for (final eq in equipements) {
      final type = typesById[eq.typeEquipementId];
      final label = ((type?.typeEquipement1Fixe ?? '').isNotEmpty
              ? type!.typeEquipement1Fixe
              : (type?.nom ?? 'équipement'))
          .toLowerCase();
      comptes[label] = (comptes[label] ?? 0) + 1;
      final freq = int.tryParse(eq.champsEnTete['freqEntretienAnnuelle']?.toString() ?? '');
      if (freq != null) freqCount[freq] = (freqCount[freq] ?? 0) + 1;
    }
    if (comptes.isEmpty) return '';
    var freqLabel = '';
    if (freqCount.isNotEmpty) {
      final entries = freqCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      const labels = {1: 'annuel', 2: 'semestriel', 4: 'trimestriel', 12: 'mensuel'};
      freqLabel = labels[entries.first.key] ?? '';
    }
    final segments = comptes.entries.map((e) => '${e.value} ${e.key}${e.value > 1 ? 's' : ''}').join(', ');
    return freqLabel.isEmpty ? 'Entretien de $segments.' : 'Entretien $freqLabel de $segments.';
  }

  Future<void> _choisirAffaire() async {
    final client = _client;
    if (client == null) return;
    final affaire = await Navigator.push<AffaireModel>(
      context,
      MaterialPageRoute(
        builder: (context) => ClientAffairesListScreen(client: client, modeSelection: true, natureFiltre: _pole),
      ),
    );
    if (affaire != null && mounted) setState(() => _affaire = affaire);
  }

  Future<void> _choisirEquipement() async {
    final client = _client;
    if (client == null) return;
    final eq = await Navigator.push<EquipementModel>(
      context,
      MaterialPageRoute(builder: (context) => BiEquipementPickerScreen(client: client)),
    );
    if (eq != null && mounted) {
      setState(() {
        _equipement = eq;
        _typeActif = _typesEquipement.where((t) => t.id == eq.typeEquipementId).firstOrNull;
        _reconstruireMateriel(_typeActif);
      });
    }
  }

  Future<void> _choisirTechniciens() async {
    final resultat = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (context) => BiTechnicienPickerScreen(selectionInitiale: _techniciens)),
    );
    if (resultat != null && mounted) {
      setState(() {
        _techniciens
          ..clear()
          ..addAll(resultat);
        _majTempsStandard();
      });
    }
  }

  /// Recalcule le temps passé — journée type OGEC multipliée par le
  /// nombre de techniciens intervenus (main d'œuvre facturée, pas
  /// seulement le temps de présence sur site), sauf pour les pôles à
  /// temps libre (voir Poles.avecTempsLibre) où il n'y a pas de journée
  /// standard fiable. Une saisie manuelle coupe définitivement le
  /// calcul (voir [_saisirTemps]).
  void _majTempsStandard() {
    if (_tempsManuel) return;
    final base = Poles.avecTempsLibre(_pole) ? '' : BiFormat.tempsStandard(_dateIntervention);
    _tempsPasseController.text = base.isEmpty ? '' : BiFormat.multiplierDuree(base, _techniciens.length);
  }

  void _saisirTemps(String valeur) {
    _tempsManuel = true;
    // Rafraîchit l'aperçu du total facturé (pôles à temps libre) sans
    // reformater le champ pendant la saisie — voir [_apercuTempsDepannageWidget].
    if (Poles.avecTempsLibre(_pole)) setState(() {});
  }

  /// Pôles à temps libre (Réparation) : le champ Temps passé reste la
  /// durée telle que tapée par le technicien (jamais réécrite en
  /// direct, l'ordre dans lequel il remplit Techniciens/Temps ne doit
  /// rien casser) — seul cet aperçu, et la valeur réellement
  /// enregistrée dans [_construireBI], tiennent compte de l'effectif.
  Widget _apercuTempsDepannageWidget() {
    if (!Poles.avecTempsLibre(_pole) || _techniciens.length <= 1) return const SizedBox.shrink();
    final saisie = _tempsPasseController.text.trim();
    if (saisie.isEmpty) return const SizedBox.shrink();
    final total = BiFormat.multiplierDuree(saisie, _techniciens.length);
    if (total == saisie) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '→ $total au total pour ${_techniciens.length} techniciens',
        style: TextStyle(fontSize: 12, color: biAccent, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _choisirPhoto() async {
    if (_photos.length >= 4) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final xfile = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1280);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    final index = _photos.length;
    setState(() {
      _photos.add(PhotoBI(localPath: xfile.path, horodatage: BiFormat.now()));
      _apercusPhotos[index] = bytes;
      _photosEnCours.add(index);
    });
    try {
      final url = await _photoService.uploader(bytes);
      if (!mounted) return;
      setState(() {
        if (index < _photos.length) _photos[index].url = url;
        _photosEnCours.remove(index);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (index < _photos.length) _photos.removeAt(index);
        _apercusPhotos.remove(index);
        _photosEnCours.remove(index);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Échec de l\'envoi de la photo : $e')));
    }
  }

  /// Client obligatoire, puis devis (Affaire) et équipement du parc
  /// GMAO selon ce qu'exige le pôle choisi (voir Poles.avecAffaire/
  /// avecEquipementObligatoire).
  /// Tous les champs de la famille active renseignés — exigé pour
  /// "Remplacement à l'identique" (famille de l'équipement choisi) et
  /// "Installation neuve" (famille choisie par le technicien), jamais
  /// pour les autres pôles. Aucune famille active = incomplet.
  bool get _materielComplet {
    final type = _typeActif;
    if (type == null) return false;
    for (final champ in _champsPertinents(type)) {
      final v = _materielChampsEnTete[champ.cle]?.toString().trim() ?? '';
      if (v.isEmpty) return false;
    }
    return true;
  }

  bool get _peutAvancerEtapeClient {
    if (_client == null) return false;
    if (Poles.avecAffaire(_pole) && _affaire == null) return false;
    if (Poles.avecEquipementObligatoire(_pole) && _equipement == null) return false;
    if (_pole == Poles.remplacementIdentique && !_materielComplet) return false;
    if (Poles.avecNouvelEquipement(_pole)) {
      if (_installationNomController.text.trim().isEmpty) return false;
      if (_installationLocalisationController.text.trim().isEmpty) return false;
      if (!_materielComplet) return false;
    }
    return true;
  }

  bool get _peutTransmettre =>
      _pole.isNotEmpty &&
      _client != null &&
      _techniciens.isNotEmpty &&
      _sigTechController.isNotEmpty &&
      _sigClientController.isNotEmpty &&
      _signataireController.text.trim().isNotEmpty &&
      _photosEnCours.isEmpty;

  BonIntervention _construireBI(String statut) {
    final c = _client;
    final adresseParts = [
      c?.adresse ?? '',
      [c?.codePostal ?? '', c?.commune ?? ''].where((s) => s.isNotEmpty).join(' '),
    ].where((s) => s.trim().isNotEmpty).toList();

    // Identité de l'équipement du bon — trois origines possibles selon
    // le pôle : nouveau matériel saisi par le technicien (Installation
    // neuve), équipement existant choisi dans le parc GMAO, ou nom libre
    // (Réparation diverse, équipement non répertorié) — jamais deux à la
    // fois pour un même bon.
    String equipementNomFinal;
    String equipementGroupeFinal;
    String equipementLocalisationFinal;
    if (Poles.avecNouvelEquipement(_pole)) {
      equipementNomFinal = _installationNomController.text.trim();
      equipementGroupeFinal = _installationGroupeController.text.trim();
      equipementLocalisationFinal = _installationLocalisationController.text.trim();
    } else if (_equipement != null) {
      equipementNomFinal = _equipement!.nom;
      equipementGroupeFinal = _equipement!.groupe;
      equipementLocalisationFinal = _equipement!.localisation;
    } else if (Poles.avecEquipementLibre(_pole) && _equipementLibreController.text.trim().isNotEmpty) {
      equipementNomFinal = _equipementLibreController.text.trim();
      equipementGroupeFinal = '';
      equipementLocalisationFinal = '';
    } else {
      equipementNomFinal = '';
      equipementGroupeFinal = '';
      equipementLocalisationFinal = '';
    }

    return BonIntervention(
      pole: _pole,
      chrono: _chrono,
      numero: _numero,
      numeroProvisoire: _numeroProvisoire,
      statut: statut,
      clientId: c?.id ?? '',
      clientNom: c?.nom ?? '',
      site: c?.site ?? '',
      adresse: adresseParts.join(', '),
      email: _emailController.text.trim(),
      horsContrat: c?.horsContrat ?? false,
      equipementId: _equipement?.id ?? '',
      equipementNom: equipementNomFinal,
      equipementGroupe: equipementGroupeFinal,
      equipementLocalisation: equipementLocalisationFinal,
      affaireId: _affaire?.id ?? '',
      affaireNumeroDevis: _affaire?.numeroDevis ?? '',
      affaireNumeroCommandeClient: _affaire?.numeroCommandeClient ?? '',
      affaireDateCommandeClient: _affaire?.dateCommandeClient ?? '',
      materielTypeEquipementId: _typeActif?.id ?? '',
      materielChampsEnTete: Map<String, dynamic>.from(_materielChampsEnTete),
      dateDebut: _dateDebut,
      dateFin: _dateFin,
      dateIntervention: _dateIntervention,
      // Pôles à temps libre (Poles.avecTempsLibre) : durée saisie
      // librement, jamais recalculée en direct (voir
      // _apercuTempsDepannageWidget) — la multiplication par l'effectif
      // n'est appliquée qu'ici, une seule fois, à l'enregistrement. Les
      // autres pôles multiplient déjà en direct (journée type
      // recalculée à chaque changement, voir _majTempsStandard).
      tempsPasse: Poles.avecTempsLibre(_pole)
          ? BiFormat.multiplierDuree(_tempsPasseController.text.trim(), _techniciens.length)
          : _tempsPasseController.text.trim(),
      techniciens: List.from(_techniciens),
      technicienSignataire: _technicienConnecte,
      compteRendu: _compteRenduController.text.trim(),
      obsTech: _obsTechController.text.trim(),
      obsClient: _obsClientController.text.trim(),
      // Le technicien ne saisit plus les prestations : déjà connues du
      // devis (voir _affaire), le bureau les reprend lui-même à la
      // validation (voir "Prestations & fournitures" côté bureau).
      prestas: const [],
      photos: List.from(_photos),
      sigTech: '',
      sigClient: '',
      signataire: _signataireController.text.trim(),
      signataireTelPortable: _signataireTelPortableController.text.trim(),
      signataireTelFixe: _signataireTelFixeController.text.trim(),
      dateSignature: BiFormat.now(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _enregistrerBrouillon() async {
    if (_photosEnCours.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Envoi des photos en cours, patiente un instant...')));
      return;
    }
    setState(() => _enregistrementEnCours = true);
    try {
      await _assurerNumero();
      // Les signatures déjà tracées ne doivent pas se perdre si le
      // technicien enregistre un brouillon avant de transmettre (ex:
      // signataire pas encore rempli) — même capture que _transmettreAuBureau.
      final sigTechBytes = await _sigTechController.toPngBytes();
      final sigClientBytes = await _sigClientController.toPngBytes();
      final bi = _construireBI(Statuts.brouillon);
      bi.sigTech = sigTechBytes != null ? base64Encode(sigTechBytes) : '';
      bi.sigClient = sigClientBytes != null ? base64Encode(sigClientBytes) : '';
      await _biService.saveBI(bi);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brouillon enregistré')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _enregistrementEnCours = false);
    }
  }

  Future<void> _transmettreAuBureau() async {
    if (!_peutTransmettre) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pôle, client, technicien(s), signataire et les 2 signatures sont obligatoires.',
          ),
        ),
      );
      return;
    }
    setState(() => _enregistrementEnCours = true);
    try {
      await _assurerNumero();
      final sigTechBytes = await _sigTechController.toPngBytes();
      final sigClientBytes = await _sigClientController.toPngBytes();
      final bi = _construireBI(Statuts.aVerifier);
      bi.sigTech = sigTechBytes != null ? base64Encode(sigTechBytes) : '';
      bi.sigClient = sigClientBytes != null ? base64Encode(sigClientBytes) : '';
      final id = await _biService.saveBI(bi);
      final nom = await _userService.getCurrentUserName();
      await _biService.pushHistory(
        id,
        HistoryEntry(
          user: nom,
          date: BiFormat.now(),
          event: 'Signé client · transmis au bureau pour vérification',
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bon signé · transmis au bureau')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enregistré localement, synchronisation en attente : $e')),
      );
    } finally {
      if (mounted) setState(() => _enregistrementEnCours = false);
    }
  }

  /// Aperçu PDF avant transmission — régénéré depuis les données déjà
  /// saisies, y compris les signatures déjà tracées (vides sinon,
  /// affichées en blanc dans le PDF, sans bloquer l'aperçu). Rien n'est
  /// enregistré, ni le bon ni le PDF.
  Future<void> _apercuPdf() async {
    setState(() => _apercuEnCours = true);
    try {
      final sigTechBytes = await _sigTechController.toPngBytes();
      final sigClientBytes = await _sigClientController.toPngBytes();
      final bi = _construireBI(Statuts.brouillon);
      bi.sigTech = sigTechBytes != null ? base64Encode(sigTechBytes) : '';
      bi.sigClient = sigClientBytes != null ? base64Encode(sigClientBytes) : '';
      final bytes = await BiPdfGenerator.generer(bi);
      if (!mounted) return;
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Impossible de générer l\'aperçu : $e')));
    } finally {
      if (mounted) setState(() => _apercuEnCours = false);
    }
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Bon d\'intervention — Étape ${_etape + 1}/$_totalEtapes'),
        backgroundColor: biAccent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Retour',
          // Revient à l'étape précédente sans perdre sa saisie ; ne
          // quitte l'assistant que depuis la toute première étape.
          onPressed: () {
            if (_etape > 0) {
              setState(() => _etape--);
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_etape + 1) / _totalEtapes,
            color: biAccent,
            backgroundColor: biAccent.withValues(alpha: 0.15),
            minHeight: 4,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildEtape(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBarreBas(),
    );
  }

  Widget _buildEtape() {
    switch (_etape) {
      case 0:
        return _etapePole();
      case 1:
        return _etapeClient();
      case 2:
        return _etapeTechniciensDates();
      case 3:
        return _etapeCompteRendu();
      default:
        return _etapeSignatures();
    }
  }

  Widget _buildBarreBas() {
    // Étape Pôle : le seul geste est de taper une tuile (avance déjà
    // automatiquement) — pas de barre "Suivant" toujours désactivée.
    if (_etape == 0) return const SizedBox.shrink();
    final dernierEtape = _etape == _totalEtapes - 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_etape > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _enregistrementEnCours ? null : () => setState(() => _etape--),
                  child: const Text('Précédent'),
                ),
              ),
            if (_etape > 0) const SizedBox(width: 10),
            if (!dernierEtape)
              Expanded(
                child: ElevatedButton(
                  onPressed: (_etape == 1 && !_peutAvancerEtapeClient)
                      ? null
                      : () => setState(() => _etape++),
                  style: ElevatedButton.styleFrom(backgroundColor: biAccent, foregroundColor: Colors.white),
                  child: const Text('Suivant'),
                ),
              ),
            if (dernierEtape) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _enregistrementEnCours ? null : _enregistrerBrouillon,
                  child: const Text('Enregistrer brouillon'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _enregistrementEnCours ? null : _transmettreAuBureau,
                  style: ElevatedButton.styleFrom(backgroundColor: biAccent, foregroundColor: Colors.white),
                  child: _enregistrementEnCours
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Transmettre au bureau'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String titre) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 10),
    child: Text(
      titre.toUpperCase(),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
    ),
  );

  // Icônes référencées via switch (littéraux directs) plutôt qu'une Map
  // — le tree-shaker d'icônes de Flutter web (activé par défaut en
  // release) ne détecte pas fiablement les IconData qui ne vivent que
  // dans une Map, et les avait purement et simplement retirées de la
  // police embarquée (glyphes vides à l'écran) alors que la compilation
  // ne signalait rien.
  IconData _iconePole(String code) => switch (code) {
    Poles.depannage => Icons.bolt,
    Poles.remplacementIdentique => Icons.autorenew,
    Poles.installationNeuve => Icons.add_circle_outline,
    Poles.reparationEquipement => Icons.build_circle_outlined,
    Poles.reparationDiverse => Icons.handyman_outlined,
    Poles.entretienSousContrat => Icons.verified_outlined,
    Poles.entretienHorsContrat => Icons.receipt_long_outlined,
    Poles.miseADisposition => Icons.inventory_2_outlined,
    Poles.livraisonMateriel => Icons.local_shipping_outlined,
    _ => Icons.build_outlined,
  };

  // Une couleur bien distincte par pôle — pour repérer le bon pôle d'un
  // coup d'œil plutôt que de devoir lire chaque étiquette.
  static const Map<String, Color> _couleursPoles = {
    Poles.depannage: Color(0xFFE53935),
    Poles.remplacementIdentique: Color(0xFF1E88E5),
    Poles.installationNeuve: Color(0xFF43A047),
    Poles.reparationEquipement: Color(0xFFFB8C00),
    Poles.reparationDiverse: Color(0xFF8D6E63),
    Poles.entretienSousContrat: Color(0xFF00897B),
    Poles.entretienHorsContrat: Color(0xFF8E24AA),
    Poles.miseADisposition: Color(0xFF546E7A),
    Poles.livraisonMateriel: Color(0xFF3949AB),
  };

  /// Étiquette longue pleine largeur — même gabarit que les cartes du
  /// tableau de bord (TopMenuCard/DashboardGridCard), plus lisible et
  /// plus facile à toucher que les petits chips pour un choix aussi
  /// structurant que le pôle — et sa propre couleur/icône pour repérer
  /// le bon pôle d'un coup d'œil.
  Widget _cartePole(String code) {
    final selectionne = _pole == code;
    final couleur = _couleursPoles[code] ?? biAccent;
    return Material(
      color: selectionne ? couleur.withValues(alpha: 0.1) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _choisirPole(code),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selectionne ? couleur : Colors.grey[300]!, width: selectionne ? 2 : 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconePole(code), color: couleur, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  Poles.label(code),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: selectionne ? couleur : Colors.black87,
                  ),
                ),
              ),
              Icon(selectionne ? Icons.check_circle : Icons.chevron_right, color: selectionne ? couleur : Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Étape 0 : Pôle ----------
  Widget _etapePole() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Pôle'),
        for (final code in Poles.ordreAffichage) ...[
          _cartePole(code),
          if (code != Poles.ordreAffichage.last) const SizedBox(height: 8),
        ],
      ],
    );
  }

  // ---------- Étape 1 : Client ----------
  Widget _etapeClient() {
    final couleur = _couleursPoles[_pole] ?? biAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: couleur.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(_iconePole(_pole), color: couleur, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  Poles.label(_pole),
                  style: TextStyle(fontWeight: FontWeight.bold, color: couleur),
                ),
              ),
            ],
          ),
        ),
        if (_allocationEnCours)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Attribution du numéro…', style: TextStyle(fontSize: 12, color: Colors.grey)),
          )
        else if (_numero.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'N° $_numero${_numeroProvisoire ? ' (provisoire)' : ''}',
              style: TextStyle(fontWeight: FontWeight.bold, color: biAccent),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Le numéro sera attribué à l\'enregistrement',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        const SizedBox(height: 16),
        _sectionTitle('Client'),
        if (_client != null)
          Card(
            color: biAccent.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: biAccent),
              title: Text('${_client!.nom} — ${_client!.site}'),
              subtitle: Text(_client!.commune),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _choisirClient),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _client = null;
                      _equipement = null;
                      _affaire = null;
                      _effacerRemplacement();
                    }),
                  ),
                ],
              ),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: _choisirClient,
            icon: const Icon(Icons.search),
            label: const Text('Choisir un client'),
            style: OutlinedButton.styleFrom(foregroundColor: biAccent, side: BorderSide(color: biAccent)),
          ),
        if (_client != null) ..._blocAffaireEtEquipement(),
      ],
    );
  }

  List<Widget> _blocAffaireEtEquipement() {
    return [
      if (Poles.avecAffaire(_pole)) ...[
        _sectionTitle('Affaire'),
        if (_affaire != null)
          Card(
            color: biAccent.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: const Icon(Icons.assignment_outlined, color: biAccent),
              title: Text(_affaire!.numeroDevis.isEmpty ? '(sans n° de devis)' : _affaire!.numeroDevis),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_affaire!.designationPrestations, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (_affaire!.numeroCommandeClient.isNotEmpty)
                    Text(
                      'Commande client : ${_affaire!.numeroCommandeClient}'
                      '${_affaire!.dateCommandeClient.isNotEmpty ? ' du ${_affaire!.dateCommandeClient}' : ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _affaire = null),
              ),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: _choisirAffaire,
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('Choisir l\'affaire'),
            style: OutlinedButton.styleFrom(foregroundColor: biAccent, side: BorderSide(color: biAccent)),
          ),
      ],
      if (Poles.avecEquipementObligatoire(_pole)) ...[
        _sectionTitle('Équipement'),
        if (_equipement != null)
          Card(
            color: biAccent.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: const Icon(Icons.precision_manufacturing_outlined, color: biAccent),
              title: Text(_equipement!.nom),
              subtitle: Text(_equipement!.localisation.isEmpty ? '—' : _equipement!.localisation),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _equipement = null),
              ),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: _choisirEquipement,
            icon: const Icon(Icons.precision_manufacturing_outlined),
            label: const Text('Choisir un équipement du parc GMAO'),
            style: OutlinedButton.styleFrom(foregroundColor: biAccent, side: BorderSide(color: biAccent)),
          ),
        if (_equipement != null && _pole == Poles.remplacementIdentique) ...[
          _sectionTitle('Nouveau matériel'),
          ..._blocChampsMateriel(),
        ],
      ],
      if (Poles.avecNouvelEquipement(_pole)) ...[
        _sectionTitle('Nouvel équipement à installer'),
        TextField(
          controller: _installationNomController,
          decoration: const InputDecoration(labelText: 'Nom de l\'équipement', border: OutlineInputBorder(), isDense: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _installationLocalisationController,
          decoration: const InputDecoration(labelText: 'Localisation', border: OutlineInputBorder(), isDense: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _installationGroupeController,
          decoration: const InputDecoration(labelText: 'Groupe (optionnel)', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<TypeEquipementModel>(
          initialValue: _typeActif,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Famille d\'équipement', border: OutlineInputBorder(), isDense: true),
          items: _typesEquipement.map((t) => DropdownMenuItem(value: t, child: Text(t.nom))).toList(),
          onChanged: (t) => setState(() {
            _typeActif = t;
            _reconstruireMateriel(t);
          }),
        ),
        if (_typeActif != null) ...[
          const SizedBox(height: 10),
          _sectionTitle('Caractéristiques du matériel'),
          ..._blocChampsMateriel(),
        ],
      ],
      if (Poles.avecEquipementOptionnel(_pole)) ...[
        _sectionTitle('Équipement (optionnel)'),
        if (_equipement != null)
          Card(
            color: biAccent.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: const Icon(Icons.precision_manufacturing_outlined, color: biAccent),
              title: Text(_equipement!.nom),
              subtitle: Text(_equipement!.localisation.isEmpty ? '—' : _equipement!.localisation),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _equipement = null),
              ),
            ),
          )
        else ...[
          OutlinedButton.icon(
            onPressed: _choisirEquipement,
            icon: const Icon(Icons.precision_manufacturing_outlined),
            label: const Text('Choisir un équipement du parc GMAO'),
            style: OutlinedButton.styleFrom(foregroundColor: biAccent, side: BorderSide(color: biAccent)),
          ),
          if (Poles.avecEquipementLibre(_pole)) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _equipementLibreController,
              decoration: const InputDecoration(
                labelText: 'Ou décrire l\'équipement (ex: calorifuge, purgeur)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ],
      ],
    ];
  }

  /// Champs de la famille active (voir _typeActif/_reconstruireMateriel)
  /// — génériques, même mécanisme que AjouterEquipementScreen côté GMAO :
  /// aucun champ codé en dur, la liste vient du Référentiel équipements.
  List<Widget> _blocChampsMateriel() {
    final type = _typeActif;
    if (type == null) return [];
    return [
      for (final champ in _champsPertinents(type)) ...[
        _champMateriel(champ),
        const SizedBox(height: 10),
      ],
    ];
  }

  Widget _champMateriel(ChampEnTete champ) {
    if (champ.options.isEmpty) {
      return TextField(
        controller: _materielControllers[champ.cle],
        keyboardType: champ.numerique ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(
          labelText: champ.label,
          suffixText: champ.unite.isEmpty ? null : champ.unite,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) => setState(() => _materielChampsEnTete[champ.cle] = v),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _materielChampsEnTete[champ.cle] as String?,
      isExpanded: true,
      decoration: InputDecoration(labelText: champ.label, border: const OutlineInputBorder(), isDense: true),
      items: champ.options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: (v) => setState(() => _materielChampsEnTete[champ.cle] = v),
    );
  }

  // ---------- Étape 1 ----------
  Future<void> _choisirDate(bool Function(DateTime) appliquer) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => appliquer(d));
  }

  String _formaterDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _champDate(String label, String valeur, void Function(DateTime) onChoisi) {
    return InkWell(
      onTap: () => _choisirDate((d) {
        onChoisi(d);
        return true;
      }),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        child: Text(valeur.isEmpty ? '—' : valeur),
      ),
    );
  }


  // Techniciens d'abord : le temps passé (juste en dessous) dépend de
  // l'effectif pour son calcul, autant le connaître avant.
  Widget _etapeTechniciensDates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Techniciens intervenus'),
        if (_techniciens.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _techniciens
                .map(
                  (t) => Chip(
                    label: Text(t),
                    backgroundColor: biAccent.withValues(alpha: 0.12),
                    onDeleted: () => setState(() {
                      _techniciens.remove(t);
                      _majTempsStandard();
                    }),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _choisirTechniciens,
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('Ajouter un intervenant'),
          style: OutlinedButton.styleFrom(foregroundColor: biAccent, side: BorderSide(color: biAccent)),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Dates'),
        if (Poles.avecPeriode(_pole)) ...[
          Row(
            children: [
              Expanded(
                child: _champDate('Date de début', _dateDebut, (d) => setState(() => _dateDebut = _formaterDate(d))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _champDate('Date de fin', _dateFin, (d) => setState(() => _dateFin = _formaterDate(d))),
              ),
            ],
          ),
        ] else ...[
          _champDate(
            'Date d\'intervention',
            _dateIntervention,
            (d) => setState(() {
              _dateIntervention = _formaterDate(d);
              _majTempsStandard();
            }),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _tempsPasseController,
            decoration: const InputDecoration(
              labelText: 'Temps passé',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: _saisirTemps,
          ),
          _apercuTempsDepannageWidget(),
        ],
      ],
    );
  }

  // ---------- Étape 2 ----------
  Widget _etapeCompteRendu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Compte rendu'),
        TextField(
          controller: _compteRenduController,
          maxLines: 5,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Détail de l\'intervention...'),
        ),
        _sectionTitle('Observation technicien'),
        TextField(
          controller: _obsTechController,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        _sectionTitle('Photos (${_photos.length}/4)'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < _photos.length; i++)
              _cartePhoto(i),
            if (_photos.length < 4)
              InkWell(
                onTap: _choisirPhoto,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_a_photo_outlined, color: Colors.grey),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _cartePhoto(int i) {
    final photo = _photos[i];
    final bytes = _apercusPhotos[i];
    final enCours = _photosEnCours.contains(i);
    return SizedBox(
      width: 110,
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: bytes != null
                    ? Image.memory(bytes, width: 110, height: 110, fit: BoxFit.cover)
                    : Container(width: 110, height: 110, color: Colors.grey[200]),
              ),
              if (enCours)
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                  onPressed: enCours
                      ? null
                      : () => setState(() {
                          _photos.removeAt(i);
                          _apercusPhotos.remove(i);
                        }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          DropdownButton<String>(
            value: photo.type,
            isDense: true,
            isExpanded: true,
            items: photoTypes.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 11))))
                .toList(),
            onChanged: (v) => setState(() => photo.type = v ?? photo.type),
          ),
        ],
      ),
    );
  }

  // ---------- Étape 4 ----------
  Widget _padSignature(String titre, SignatureController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          height: 140,
          decoration: BoxDecoration(
            border: Border.all(color: biAccent.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[50],
          ),
          child: Signature(controller: controller, backgroundColor: Colors.grey[50]!),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => controller.clear()),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Effacer'),
          ),
        ),
      ],
    );
  }

  Widget _etapeSignatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Signataire client'),
        TextField(
          controller: _signataireController,
          decoration: const InputDecoration(
            labelText: 'Nom du signataire',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _signataireTelPortableController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Téléphone Portable',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _signataireTelFixeController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Téléphone fixe',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email du signataire',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 16),
        _padSignature('Signature technicien', _sigTechController),
        const SizedBox(height: 16),
        _sectionTitle('Observation client'),
        TextField(
          controller: _obsClientController,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        _padSignature('Signature client', _sigClientController),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _apercuEnCours ? null : _apercuPdf,
            icon: _apercuEnCours
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Aperçu du PDF'),
            style: OutlinedButton.styleFrom(foregroundColor: biAccent, side: BorderSide(color: biAccent)),
          ),
        ),
      ],
    );
  }
}
