import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import '../../../core/data/liste_techniciens.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/user_service.dart';
import '../../annuaire/clients/client_model.dart';
import '../data/bi_constants.dart';
import '../data/bi_format.dart';
import '../data/bi_model.dart';
import '../data/bi_service.dart';

const Color biAccent = Colors.deepPurple;

class _NumeroReserve {
  final int chrono;
  final String numero;
  final bool provisoire;
  _NumeroReserve(this.chrono, this.numero, this.provisoire);
}

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
  final DatabaseService _db = DatabaseService();
  final UserService _userService = UserService();

  int _etape = 0;
  static const _totalEtapes = 6;
  bool _enregistrementEnCours = false;

  // ---------- Étape 0 : Pôle + Client ----------
  String _pole = '';
  int _chrono = 0;
  String _numero = '';
  bool _numeroProvisoire = false;
  final Map<String, _NumeroReserve> _numerosReserves = {};
  bool _allocationEnCours = false;

  ClientModel? _client;
  final _rechercheClientController = TextEditingController();
  final _emailController = TextEditingController();

  // ---------- Étape 1 : Dates / heures ----------
  String _dateDebut = BiFormat.today();
  String _dateFin = BiFormat.today();
  String _dateIntervention = BiFormat.today();
  String _heureDebut = '';
  String _heureFin = '';
  final _tempsPasseController = TextEditingController();
  bool _tempsManuel = false;

  // ---------- Étape 2 : Techniciens + nature ----------
  final List<String> _techniciens = [];
  final Map<String, bool> _nature = {};
  final _natureAutreController = TextEditingController();

  // ---------- Étape 3 : Compte rendu ----------
  final _compteRenduController = TextEditingController();
  final _obsTechController = TextEditingController();
  final _obsClientController = TextEditingController();

  // ---------- Étape 4 : Prestations + photos ----------
  final List<Presta> _prestas = [Presta()];
  final List<PhotoBI> _photos = [];
  final Map<int, Uint8List> _apercusPhotos = {};

  // ---------- Étape 5 : Signatures ----------
  final _signataireController = TextEditingController();
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
    _rechercheClientController.dispose();
    _emailController.dispose();
    _tempsPasseController.dispose();
    _natureAutreController.dispose();
    _compteRenduController.dispose();
    _obsTechController.dispose();
    _obsClientController.dispose();
    _signataireController.dispose();
    _sigTechController.dispose();
    _sigClientController.dispose();
    super.dispose();
  }

  // ==================== Logique métier ====================

  Future<void> _choisirPole(String pole) async {
    if (_pole == pole) return;
    setState(() => _pole = pole);
    _majTempsStandard();

    final deja = _numerosReserves[pole];
    if (deja != null) {
      setState(() {
        _chrono = deja.chrono;
        _numero = deja.numero;
        _numeroProvisoire = deja.provisoire;
      });
      return;
    }

    setState(() => _allocationEnCours = true);
    final annee = BiFormat.currentYear();
    try {
      final n = await _biService.allouerChrono(pole, annee);
      setState(() {
        _chrono = n;
        _numeroProvisoire = false;
        _numero = BiFormat.numeroBI(pole, annee, n);
      });
    } catch (_) {
      final n = DateTime.now().millisecondsSinceEpoch % 900000;
      setState(() {
        _chrono = n;
        _numeroProvisoire = true;
        _numero = BiFormat.numeroBI(pole, annee, n);
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
    _numerosReserves[pole] = _NumeroReserve(_chrono, _numero, _numeroProvisoire);
    if (mounted) setState(() => _allocationEnCours = false);
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
    // maxWidth/imageQuality compressent dès la capture : la seule copie
    // durable de la photo est le base64 stocké sur le document Firestore
    // (pas de Storage/Drive avant la Phase 4), il faut rester loin de la
    // limite de 1 Mo par document avec 4 photos possibles.
    final xfile = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1280);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    setState(() {
      final index = _photos.length;
      _photos.add(
        PhotoBI(localPath: xfile.path, horodatage: BiFormat.now(), data: base64Encode(bytes)),
      );
      _apercusPhotos[index] = bytes;
    });
  }

  bool get _peutTransmettre =>
      _pole.isNotEmpty &&
      _client != null &&
      _techniciens.isNotEmpty &&
      _sigTechController.isNotEmpty &&
      _sigClientController.isNotEmpty &&
      _signataireController.text.trim().isNotEmpty;

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
      dateDebut: _dateDebut,
      dateFin: _dateFin,
      dateIntervention: _dateIntervention,
      tempsPasse: _tempsPasseController.text.trim(),
      heureDebut: _heureDebut,
      heureFin: _heureFin,
      techniciens: List.from(_techniciens),
      nature: Map.from(_nature),
      natureAutre: _natureAutreController.text.trim(),
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
      dateSignature: BiFormat.now(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _enregistrerBrouillon() async {
    setState(() => _enregistrementEnCours = true);
    try {
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
        return _etapeTechniciensNature();
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
          ),
        if (_numero.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'N° $_numero${_numeroProvisoire ? ' (provisoire)' : ''}',
              style: TextStyle(fontWeight: FontWeight.bold, color: biAccent),
            ),
          ),
        _sectionTitle('Client'),
        TextField(
          controller: _rechercheClientController,
          decoration: const InputDecoration(
            hintText: 'Rechercher un client ou un site...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        if (_client != null)
          Card(
            color: biAccent.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: biAccent),
              title: Text('${_client!.nom} — ${_client!.site}'),
              subtitle: Text(_client!.commune),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _client = null),
              ),
            ),
          )
        else
          StreamBuilder<List<ClientModel>>(
            stream: _db.getClients(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final q = _rechercheClientController.text.trim().toLowerCase();
              final resultats = q.isEmpty
                  ? const <ClientModel>[]
                  : snapshot.data!
                        .where(
                          (c) =>
                              c.nom.toLowerCase().contains(q) ||
                              c.site.toLowerCase().contains(q) ||
                              c.commune.toLowerCase().contains(q),
                        )
                        .take(20)
                        .toList();
              if (resultats.isEmpty) return const SizedBox.shrink();
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: resultats.length,
                    itemBuilder: (context, i) {
                      final c = resultats[i];
                      return ListTile(
                        dense: true,
                        title: Text('${c.nom} — ${c.site}'),
                        subtitle: Text(c.commune),
                        onTap: () => setState(() {
                          _client = c;
                          _rechercheClientController.clear();
                        }),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 10),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email client (pour envoi du bon)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
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
  Widget _etapeTechniciensNature() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Techniciens intervenus'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: listeTechniciens.map((t) {
            final selectionne = _techniciens.contains(t);
            return FilterChip(
              label: Text(t),
              selected: selectionne,
              onSelected: (v) => setState(() {
                if (v) {
                  _techniciens.add(t);
                } else {
                  _techniciens.remove(t);
                }
              }),
              selectedColor: biAccent.withValues(alpha: 0.15),
            );
          }).toList(),
        ),
        _sectionTitle('Nature de l\'intervention'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: natures.entries.map((e) {
            return FilterChip(
              label: Text(e.value),
              selected: _nature[e.key] == true,
              onSelected: (v) => setState(() => _nature[e.key] = v),
              selectedColor: biAccent.withValues(alpha: 0.15),
            );
          }).toList(),
        ),
        if (_nature[natureAutre] == true) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _natureAutreController,
            decoration: const InputDecoration(
              labelText: 'Préciser',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
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
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                  onPressed: () => setState(() {
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
        const SizedBox(height: 16),
        _padSignature('Signature technicien', _sigTechController),
        const SizedBox(height: 16),
        _padSignature('Signature client', _sigClientController),
      ],
    );
  }
}
