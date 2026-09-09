import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';
import '../../../core/services/user_service.dart';
import '../../annuaire/clients/client_model.dart';
import '../../gmao/equipements/equipement_model.dart';
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

/// Assistant technicien en 6 étapes pour créer un bon d'intervention —
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

  int _etape = 0;
  static const _totalEtapes = 6;
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
  final _emailController = TextEditingController();

  // ---------- Étape 1 : Dates / heures ----------
  String _dateDebut = BiFormat.today();
  String _dateFin = BiFormat.today();
  String _dateIntervention = BiFormat.today();
  String _heureDebut = '';
  String _heureFin = '';
  final _tempsPasseController = TextEditingController();
  bool _tempsManuel = false;

  // ---------- Étape 2 : Techniciens ----------
  final List<String> _techniciens = [];

  // ---------- Étape 3 : Compte rendu ----------
  final _compteRenduController = TextEditingController();
  final _obsTechController = TextEditingController();
  final _obsClientController = TextEditingController();

  // ---------- Étape 4 : Prestations + photos ----------
  final List<Presta> _prestas = [Presta()];
  final List<PhotoBI> _photos = [];
  final Map<int, Uint8List> _apercusPhotos = {};
  final Set<int> _photosEnCours = {};

  // ---------- Étape 5 : Signatures ----------
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
  }

  Future<void> _preremplirTechnicien() async {
    final nom = await _userService.getCurrentUserName();
    if (nom.isNotEmpty && mounted) {
      setState(() => _techniciens.add(nom));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
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
      if (!Poles.avecEquipement(pole)) _equipement = null;
      // Pas encore de numéro réservé cette session : seul le segment
      // pôle du numéro déjà affiché change (voir _assurerNumero — le
      // vrai chrono n'est tiré qu'au premier enregistrement, pour ne
      // jamais créer de trou dans la numérotation sur un bon commencé
      // puis abandonné).
      if (_chrono != 0) _numero = BiFormat.numeroBI(pole, BiFormat.currentYear(), _chrono);
    });
    _majTempsStandard();
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

  Future<void> _choisirClient() async {
    final site = await Navigator.push<ClientModel>(
      context,
      MaterialPageRoute(builder: (context) => const BiClientPickerScreen()),
    );
    if (site != null && mounted) {
      setState(() {
        _client = site;
        _equipement = null;
        // Pré-rempli depuis la fiche Répertoire — reste modifiable, le
        // technicien corrige si l'interlocuteur présent sur place n'est
        // pas celui enregistré.
        _signataireController.text = site.interlocuteurSite;
        _signataireTelPortableController.text = site.portableInterlocuteurSite;
        _signataireTelFixeController.text = site.telFixeInterlocuteurSite;
        _emailController.text = site.courrielInterlocuteurSite;
      });
    }
  }

  Future<void> _choisirEquipement() async {
    final client = _client;
    if (client == null) return;
    final eq = await Navigator.push<EquipementModel>(
      context,
      MaterialPageRoute(builder: (context) => BiEquipementPickerScreen(client: client)),
    );
    if (eq != null && mounted) setState(() => _equipement = eq);
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
      });
    }
  }

  /// Recalcule le temps passé — les horaires priment, sinon la journée
  /// type OGEC, sauf au SAV. Une saisie manuelle coupe définitivement
  /// le calcul (voir [_saisirTemps]).
  void _majTempsStandard() {
    if (_tempsManuel) return;
    final mesure = BiFormat.dureeEntre(_heureDebut, _heureFin);
    final valeur = mesure.isNotEmpty
        ? mesure
        : (_pole == Poles.depannage ? '' : BiFormat.tempsStandard(_dateIntervention));
    _tempsPasseController.text = valeur;
  }

  void _saisirTemps(String valeur) {
    _tempsManuel = true;
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
      equipementNom: _equipement?.nom ?? '',
      dateDebut: _dateDebut,
      dateFin: _dateFin,
      dateIntervention: _dateIntervention,
      tempsPasse: _tempsPasseController.text.trim(),
      heureDebut: _heureDebut,
      heureFin: _heureFin,
      techniciens: List.from(_techniciens),
      compteRendu: _compteRenduController.text.trim(),
      obsTech: _obsTechController.text.trim(),
      obsClient: _obsClientController.text.trim(),
      // Le technicien ne saisit jamais de prix — la ligne pu reste vide.
      prestas: _prestas
          .where((p) => p.designation.trim().isNotEmpty)
          .map((p) => Presta(designation: p.designation, quantite: p.quantite))
          .toList(),
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
      await _biService.saveBI(_construireBI(Statuts.brouillon));
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
        return _etapePoleClient();
      case 1:
        return _etapeDatesHeures();
      case 2:
        return _etapeTechniciens();
      case 3:
        return _etapeCompteRendu();
      case 4:
        return _etapePrestationsPhotos();
      default:
        return _etapeSignatures();
    }
  }

  Widget _buildBarreBas() {
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
                  onPressed: (_etape == 0 && (_pole.isEmpty || _client == null))
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

  // ---------- Étape 0 ----------
  Widget _etapePoleClient() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Pôle'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: Poles.all.entries.map((e) {
            return ChoiceChip(
              label: Text(e.value),
              selected: _pole == e.key,
              onSelected: (_) => _choisirPole(e.key),
              selectedColor: biAccent.withValues(alpha: 0.15),
            );
          }).toList(),
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
        else if (_pole.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Le numéro sera attribué à l\'enregistrement',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
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
        if (_client != null && Poles.avecEquipement(_pole)) ...[
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
          else
            OutlinedButton.icon(
              onPressed: _choisirEquipement,
              icon: const Icon(Icons.precision_manufacturing_outlined),
              label: const Text('Choisir un équipement du parc GMAO'),
              style: OutlinedButton.styleFrom(foregroundColor: biAccent, side: BorderSide(color: biAccent)),
            ),
        ],
      ],
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

  Future<void> _choisirHeure(void Function(String) appliquer) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t != null) {
      setState(() {
        appliquer('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
        _majTempsStandard();
      });
    }
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

  Widget _champHeure(String label, String valeur, void Function(String) onChoisi) {
    return InkWell(
      onTap: () => _choisirHeure(onChoisi),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        child: Text(valeur.isEmpty ? '—' : valeur),
      ),
    );
  }

  Widget _etapeDatesHeures() {
    final avecHeures = Poles.avecHeures(_pole);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Dates'),
        if (_pole == Poles.maintenance) ...[
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
          if (avecHeures) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _champHeure('Heure d\'arrivée', _heureDebut, (v) => _heureDebut = v),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _champHeure('Heure de départ', _heureFin, (v) => _heureFin = v),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _tempsPasseController,
            decoration: const InputDecoration(
              labelText: 'Temps passé',
              helperText: 'Calculé automatiquement — modifiable',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: _saisirTemps,
          ),
        ],
      ],
    );
  }

  // ---------- Étape 2 ----------
  Widget _etapeTechniciens() {
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
                    onDeleted: () => setState(() => _techniciens.remove(t)),
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
      ],
    );
  }

  // ---------- Étape 3 ----------
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
        _sectionTitle('Observation client'),
        TextField(
          controller: _obsClientController,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    );
  }

  // ---------- Étape 4 ----------
  Widget _etapePrestationsPhotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Prestations & fournitures'),
        const Text(
          'Désignation et quantité uniquement — la tarification est faite par le bureau.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _prestas.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: _prestas[i].designation,
                    decoration: const InputDecoration(labelText: 'Désignation', isDense: true, border: OutlineInputBorder()),
                    onChanged: (v) => _prestas[i].designation = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: _prestas[i].quantite,
                    decoration: const InputDecoration(labelText: 'Qté', isDense: true, border: OutlineInputBorder()),
                    onChanged: (v) => _prestas[i].quantite = v,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: _prestas.length == 1
                      ? null
                      : () => setState(() => _prestas.removeAt(i)),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () => setState(() => _prestas.add(Presta())),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter une ligne'),
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

  // ---------- Étape 5 ----------
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
