import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/auth/admin_google_session.dart';
import '../../../core/services/user_service.dart';
import '../../affaires/data/affaire_constants.dart';
import '../../gmao/equipements/equipement_model.dart';
import '../../gmao/gmao_database_service.dart';
import '../../gmao/types_equipement/type_equipement_model.dart';
import '../data/bi_constants.dart';
import '../data/bi_format.dart';
import '../data/bi_model.dart';
import '../data/bi_service.dart';
import '../pdf/bi_drive_service.dart';
import '../pdf/bi_pdf_generator.dart';
import '../wizard/bi_wizard_screen.dart' show biAccent;
import '../widgets/statut_badge.dart';

/// Détail d'un bon d'intervention côté bureau. Sur un bon "À vérifier" :
/// correction des champs autorisés + saisie des prix unitaires HT (jamais
/// saisis par le technicien). Les données client et la signature restent
/// verrouillées après signature. Porté depuis
/// re.ogec.bi/ui/screens/DetailBureauScreen.kt — l'envoi de l'email au
/// client reste manuel pour l'instant (pas encore construit).
class BiDetailBureauScreen extends StatefulWidget {
  final String biId;
  const BiDetailBureauScreen({super.key, required this.biId});

  @override
  State<BiDetailBureauScreen> createState() => _BiDetailBureauScreenState();
}

class _BiDetailBureauScreenState extends State<BiDetailBureauScreen> {
  final BiService _biService = BiService();
  final UserService _userService = UserService();
  final BiDriveService _driveService = BiDriveService();
  final GmaoDatabaseService _gmaoDb = GmaoDatabaseService();
  bool _validationEnCours = false;
  bool _pdfEnCours = false;

  // Petits travaux · Installation uniquement — le BI ne collecte encore
  // aucune info sur le nouveau matériel (voir Étape B), le bureau les
  // saisit ici juste avant de valider, pour créer une fiche minimale
  // dans le parc GMAO plutôt que rien du tout.
  final _installationNomController = TextEditingController();
  final _installationLocalisationController = TextEditingController();
  String? _installationTypeEquipementId;

  Future<void> _voirPdf(BonIntervention b) async {
    setState(() => _pdfEnCours = true);
    try {
      final bytes = await BiPdfGenerator.generer(b);
      await Printing.layoutPdf(onLayout: (format) async => bytes);

      if (b.pdfDriveUrl.isEmpty) {
        if (!mounted) return;
        final compte = await AdminGoogleSession.instance.ensureSignedIn(context);
        final resultat = await _driveService.archiverBI(adminAccount: compte, bi: b, pdfBytes: bytes);
        await _biService.updateBI(b.id, {
          'statut': Statuts.pretEnvoi,
          'driveBiFolderId': resultat.biFolderId,
          'pdfDriveUrl': resultat.pdfLink,
          'jsonDriveUrl': resultat.jsonLink,
        });
      } else if (b.statut == Statuts.valide) {
        await _biService.updateBI(b.id, {'statut': Statuts.pdfGenere});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF affiché, mais l\'archivage Drive a échoué : $e')),
      );
    } finally {
      if (mounted) setState(() => _pdfEnCours = false);
    }
  }

  Future<void> _ouvrirSurDrive(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d\'ouvrir Drive : $e')));
    }
  }

  // Copie de travail pour la correction bureau — initialisée une fois le
  // bon chargé (voir _initierCorrection).
  bool _initialise = false;
  late String _pole;
  late List<String> _techniciens;
  late String _dateDebut;
  late String _dateFin;
  late String _dateIntervention;
  late String _tempsPasse;
  late String _heureDebut;
  late String _heureFin;
  late TextEditingController _compteRenduController;
  late TextEditingController _obsTechController;
  late TextEditingController _noteInterneController;
  late TextEditingController _emailController;
  late TextEditingController _numeroDevisController;
  late List<Presta> _prestas;

  void _initierCorrection(BonIntervention b) {
    if (_initialise) return;
    _initialise = true;
    _pole = b.pole;
    _techniciens = List.from(b.techniciens);
    _dateDebut = b.dateDebut;
    _dateFin = b.dateFin;
    _dateIntervention = b.dateIntervention;
    _tempsPasse = b.tempsPasse;
    _heureDebut = b.heureDebut;
    _heureFin = b.heureFin;
    _compteRenduController = TextEditingController(text: b.compteRendu);
    _obsTechController = TextEditingController(text: b.obsTech);
    _noteInterneController = TextEditingController(text: b.noteInterne);
    _emailController = TextEditingController(text: b.email);
    _numeroDevisController = TextEditingController(text: b.numeroDevis);
    _prestas = b.prestas.isEmpty
        ? [Presta()]
        : b.prestas.map((p) => Presta(designation: p.designation, quantite: p.quantite, pu: p.pu)).toList();
  }

  @override
  void dispose() {
    if (_initialise) {
      _compteRenduController.dispose();
      _obsTechController.dispose();
      _noteInterneController.dispose();
      _emailController.dispose();
      _numeroDevisController.dispose();
    }
    _installationNomController.dispose();
    _installationLocalisationController.dispose();
    super.dispose();
  }

  bool get _emailValide => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_emailController.text.trim());

  bool _peutValider(BonIntervention original) {
    if (!_emailValide) return false;
    if (original.pole == Poles.petitsTravaux && original.natureTravaux == NatureAffaire.installation) {
      return _installationNomController.text.trim().isNotEmpty && _installationTypeEquipementId != null;
    }
    return true;
  }

  /// Automatisation GMAO déclenchée par la validation bureau d'un bon
  /// Petits travaux, selon la nature du travail (voir affaires/BI Étape
  /// C) — ne doit jamais bloquer la validation du bon elle-même si elle
  /// échoue, appelée après le `saveBI` réussi.
  Future<void> _executerAutomatisationGmao(BonIntervention bi) async {
    if (bi.pole != Poles.petitsTravaux) return;
    final date = BiFormat.now();
    switch (bi.natureTravaux) {
      case NatureAffaire.reparation:
        if (bi.equipementId.isEmpty) return;
        await _gmaoDb.ajouterRemarqueEquipement(
          bi.equipementId,
          'Réparé le $date via ${bi.numero} : ${bi.compteRendu}',
        );
        break;
      case NatureAffaire.remplacement:
        if (bi.equipementId.isEmpty) return;
        await _gmaoDb.ajouterRemarqueEquipement(
          bi.equipementId,
          'Remplacé le $date via ${bi.numero} : ${bi.compteRendu}',
        );
        final data = <String, dynamic>{};
        if (bi.remplacementMarque.isNotEmpty) data['champsEnTete.marque'] = bi.remplacementMarque;
        if (bi.remplacementReferenceUInt.isNotEmpty) data['champsEnTete.referenceUInt'] = bi.remplacementReferenceUInt;
        if (bi.remplacementNumSerieUInt.isNotEmpty) data['champsEnTete.numSerieUInt'] = bi.remplacementNumSerieUInt;
        if (bi.remplacementReferenceUExt.isNotEmpty) data['champsEnTete.referenceUExt'] = bi.remplacementReferenceUExt;
        if (bi.remplacementNumSerieUExt.isNotEmpty) data['champsEnTete.numSerieUExt'] = bi.remplacementNumSerieUExt;
        if (bi.remplacementDateMES.isNotEmpty) data['champsEnTete.dateMES'] = bi.remplacementDateMES;
        if (data.isNotEmpty) await _gmaoDb.updateEquipement(bi.equipementId, data);
        break;
      case NatureAffaire.installation:
        if (_installationTypeEquipementId == null || _installationNomController.text.trim().isEmpty) return;
        await _gmaoDb.addEquipement(
          EquipementModel(
            id: '',
            clientId: bi.clientId,
            typeEquipementId: _installationTypeEquipementId!,
            nom: _installationNomController.text.trim(),
            localisation: _installationLocalisationController.text.trim(),
            horsContrat: !bi.horsContrat,
            remarqueTechnicien: 'Installé le $date via ${bi.numero} : ${bi.compteRendu}',
          ),
        );
        break;
    }
  }

  Future<void> _valider(BonIntervention original) async {
    setState(() => _validationEnCours = true);
    try {
      final changes = <Map<String, String>>[];
      void diff(String label, String avant, String apres) {
        if (avant != apres) {
          changes.add({'champ': label, 'avant': avant, 'apres': apres});
        }
      }

      diff('Pôle', original.pole, _pole);
      diff('Techniciens', original.techniciens.join(', '), _techniciens.join(', '));
      diff('Date de début', original.dateDebut, _dateDebut);
      diff('Date de fin', original.dateFin, _dateFin);
      diff('Date d\'intervention', original.dateIntervention, _dateIntervention);
      diff(
        'Horaires',
        [original.heureDebut, original.heureFin].where((s) => s.isNotEmpty).join(' → '),
        [_heureDebut, _heureFin].where((s) => s.isNotEmpty).join(' → '),
      );
      diff('Temps passé', original.tempsPasse, _tempsPasse);
      diff('Compte rendu', original.compteRendu, _compteRenduController.text.trim());
      final prestasFiltrees = _prestas.where((p) => p.designation.trim().isNotEmpty).toList();
      diff('Prestations & fournitures', BiFormat.prestaSummary(original.prestas), BiFormat.prestaSummary(prestasFiltrees));
      diff('Email client', original.email, _emailController.text.trim());
      diff('N° devis lié', original.numeroDevis, _numeroDevisController.text.trim());
      diff('Remarque interne', original.noteInterne, _noteInterneController.text.trim());

      final corrige = BonIntervention(
        id: original.id,
        pole: _pole,
        chrono: original.chrono,
        numero: original.numero,
        numeroProvisoire: original.numeroProvisoire,
        statut: Statuts.valide,
        clientId: original.clientId,
        clientNom: original.clientNom,
        site: original.site,
        adresse: original.adresse,
        email: _emailController.text.trim(),
        horsContrat: original.horsContrat,
        equipementId: original.equipementId,
        equipementNom: original.equipementNom,
        affaireId: original.affaireId,
        affaireNumeroDevis: original.affaireNumeroDevis,
        natureTravaux: original.natureTravaux,
        remplacementMarque: original.remplacementMarque,
        remplacementReferenceUInt: original.remplacementReferenceUInt,
        remplacementNumSerieUInt: original.remplacementNumSerieUInt,
        remplacementReferenceUExt: original.remplacementReferenceUExt,
        remplacementNumSerieUExt: original.remplacementNumSerieUExt,
        remplacementDateMES: original.remplacementDateMES,
        dateDebut: _dateDebut,
        dateFin: _dateFin,
        dateIntervention: _dateIntervention,
        tempsPasse: _tempsPasse,
        heureDebut: _heureDebut,
        heureFin: _heureFin,
        techniciens: _techniciens,
        compteRendu: _compteRenduController.text.trim(),
        obsTech: _obsTechController.text.trim(),
        obsClient: original.obsClient,
        prestas: prestasFiltrees,
        photos: original.photos,
        sigTech: original.sigTech,
        sigClient: original.sigClient,
        signataire: original.signataire,
        signataireTelPortable: original.signataireTelPortable,
        signataireTelFixe: original.signataireTelFixe,
        dateSignature: original.dateSignature,
        numeroDevis: _numeroDevisController.text.trim(),
        noteInterne: _noteInterneController.text.trim(),
        history: original.history,
        createdBy: original.createdBy,
        createdAt: original.createdAt,
      );

      final bi = await _biService.resoudreDoublonSiBesoin(corrige);
      await _biService.saveBI(bi);
      if (changes.isNotEmpty) {
        final nom = await _userService.getCurrentUserName();
        await _biService.pushHistory(bi.id, HistoryEntry(user: nom, date: BiFormat.now(), changes: changes));
      }
      try {
        await _executerAutomatisationGmao(bi);
      } catch (_) {
        // L'automatisation GMAO ne doit jamais empêcher la validation du
        // bon lui-même — une erreur ici reste silencieuse pour l'usager.
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bon validé')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _validationEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Bon d\'intervention'),
        backgroundColor: biAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<BonIntervention>>(
        stream: _biService.bisFlow(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final b = snapshot.data!.where((x) => x.id == widget.biId).firstOrNull;
          if (b == null) {
            return const Center(child: Text('Bon introuvable.'));
          }
          final enCorrection = b.statut == Statuts.aVerifier;
          _initierCorrection(b);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        b.numero.isEmpty ? 'BI (brouillon)' : b.numero,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    StatutBadge(statut: b.statut),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  'Le client',
                  [
                    Row(
                      children: [
                        Icon(Icons.lock_outline, size: 15, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Données client et signature verrouillées après signature.',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _infoLigne('Client', b.site.isNotEmpty ? '${b.clientNom} — ${b.site}' : b.clientNom),
                    _infoLigne('Adresse', b.adresse.isEmpty ? '—' : b.adresse),
                    if (b.horsContrat) _infoLigne('⚑', 'Client hors contrat'),
                    _infoLigne('Signataire', '${b.signataire}  ·  ${b.dateSignature}'),
                  ],
                ),
                if (!enCorrection) ..._vueLectureSeule(b) else ..._vueCorrection(b),
                if (b.history.isNotEmpty) _sectionCard('Historique des corrections', _historiqueWidgets(b)),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  static const _statutsAvecPdf = {
    Statuts.valide,
    Statuts.pdfGenere,
    Statuts.pretEnvoi,
    Statuts.envoye,
  };

  List<Widget> _vueLectureSeule(BonIntervention b) {
    final prestas = b.prestas.where((p) => p.designation.trim().isNotEmpty).toList();
    final total = BiFormat.totalHT(prestas);
    return [
      if (_statutsAvecPdf.contains(b.statut))
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _pdfEnCours ? null : () => _voirPdf(b),
              icon: _pdfEnCours
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Voir le PDF'),
              style: OutlinedButton.styleFrom(foregroundColor: biAccent, side: BorderSide(color: biAccent)),
            ),
          ),
        ),
      if (b.pdfDriveUrl.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextButton.icon(
            onPressed: () => _ouvrirSurDrive(b.pdfDriveUrl),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Ouvrir sur Drive'),
          ),
        ),
      _sectionCard('Intervention', [
        _infoLigne('Pôle', '${b.pole} · ${Poles.label(b.pole)}'),
        _infoLigne('Technicien(s)', b.techniciens.join(', ')),
        if (b.affaireNumeroDevis.isNotEmpty) _infoLigne('Affaire', b.affaireNumeroDevis),
        if (b.natureTravaux.isNotEmpty) _infoLigne('Nature', NatureAffaire.label(b.natureTravaux)),
        if (b.equipementNom.isNotEmpty) _infoLigne('Équipement', b.equipementNom),
        ..._lignesDates(b).map((e) => _infoLigne(e.key, e.value)),
        if (b.numeroDevis.isNotEmpty) _infoLigne('N° devis lié', b.numeroDevis),
      ]),
      _sectionCard('Compte rendu', [Text(b.compteRendu.isEmpty ? '—' : b.compteRendu)]),
      _sectionCard('Prestations & fournitures', [
        if (prestas.isEmpty)
          const Text('—')
        else ...[
          for (final p in prestas)
            _infoLigne(
              p.designation,
              '× ${p.quantite}   PU ${BiFormat.parsePu(p.pu) != null ? BiFormat.eur(BiFormat.parsePu(p.pu)!) : "—"}   '
              'Montant ${BiFormat.montantLigne(p) != null ? BiFormat.eur(BiFormat.montantLigne(p)!) : "—"}',
            ),
          if (total > 0) ...[
            const SizedBox(height: 4),
            _infoLigne('Total HT', BiFormat.eur(total)),
          ],
        ],
      ]),
    ];
  }

  List<Widget> _vueCorrection(BonIntervention original) {
    final avecHeures = Poles.avecHeures(_pole);
    final mesure = BiFormat.dureeEntre(_heureDebut, _heureFin);
    return [
      _sectionCard('Vérification & correction (bureau)', [
        _deroulantPole(),
        const SizedBox(height: 10),
        _champTechniciens(),
        const SizedBox(height: 10),
        if (_pole == Poles.maintenance)
          Row(
            children: [
              Expanded(child: _champTexte('Date de début', _dateDebut, (v) => _dateDebut = v)),
              const SizedBox(width: 10),
              Expanded(child: _champTexte('Date de fin', _dateFin, (v) => _dateFin = v)),
            ],
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: _champTexte(
                  _pole == Poles.depannage ? 'Date d\'intervention' : 'Date',
                  _dateIntervention,
                  (v) => _dateIntervention = v,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _champTexte('Temps passé', _tempsPasse, (v) => _tempsPasse = v)),
            ],
          ),
          if (avecHeures) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _champTexte('Arrivée sur site', _heureDebut, (v) => _heureDebut = v)),
                const SizedBox(width: 10),
                Expanded(child: _champTexte('Départ du site', _heureFin, (v) => _heureFin = v)),
              ],
            ),
            if (mesure.isNotEmpty && mesure != _tempsPasse)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TextButton(
                  onPressed: () => setState(() => _tempsPasse = mesure),
                  child: Text('Les horaires donnent $mesure — appliquer au temps passé'),
                ),
              ),
          ],
        ],
        const SizedBox(height: 10),
        TextFormField(
          controller: _compteRenduController,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Compte rendu', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _obsTechController,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Observations technicien', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _numeroDevisController,
          decoration: const InputDecoration(labelText: 'N° devis lié (optionnel)', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _noteInterneController,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Remarque interne (non imprimée)', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email du client', border: OutlineInputBorder(), isDense: true),
          onChanged: (_) => setState(() {}),
        ),
      ]),
      if (original.pole == Poles.petitsTravaux && original.natureTravaux == NatureAffaire.installation)
        _sectionCard('Nouveau matériel installé — fiche GMAO', [
          Text(
            'Le bon ne décrit pas le matériel posé : saisis ici de quoi créer sa fiche dans le parc.',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _installationNomController,
            decoration: const InputDecoration(labelText: 'Nom de l\'équipement', border: OutlineInputBorder(), isDense: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<TypeEquipementModel>>(
            stream: _gmaoDb.getTypesEquipement(),
            builder: (context, snapshot) {
              final types = snapshot.data ?? const <TypeEquipementModel>[];
              return DropdownButtonFormField<String>(
                initialValue: _installationTypeEquipementId,
                decoration: const InputDecoration(labelText: 'Famille d\'équipement', border: OutlineInputBorder(), isDense: true),
                items: types.map((t) => DropdownMenuItem(value: t.id, child: Text(t.nom))).toList(),
                onChanged: (v) => setState(() => _installationTypeEquipementId = v),
              );
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _installationLocalisationController,
            decoration: const InputDecoration(labelText: 'Localisation (optionnel)', border: OutlineInputBorder(), isDense: true),
          ),
        ]),
      _sectionCard('Prestations & fournitures — prix unitaires HT (bureau)', [
        for (var i = 0; i < _prestas.length; i++) _lignePrestaBureau(i),
        TextButton.icon(
          onPressed: () => setState(() => _prestas.add(Presta())),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter une ligne'),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Total HT : ${BiFormat.totalHT(_prestas) > 0 ? BiFormat.eur(BiFormat.totalHT(_prestas)) : "—"}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: (_validationEnCours || !_peutValider(original)) ? null : () => _valider(original),
            style: ElevatedButton.styleFrom(backgroundColor: biAccent, foregroundColor: Colors.white),
            child: _validationEnCours
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('✓ Valider', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    ];
  }

  Widget _lignePrestaBureau(int i) {
    final p = _prestas[i];
    final montant = BiFormat.montantLigne(p);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: p.designation,
                  decoration: const InputDecoration(labelText: 'Désignation', isDense: true, border: OutlineInputBorder()),
                  onChanged: (v) => setState(() => p.designation = v),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: TextFormField(
                  initialValue: p.quantite,
                  decoration: const InputDecoration(labelText: 'Qté', isDense: true, border: OutlineInputBorder()),
                  onChanged: (v) => setState(() => p.quantite = v),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextFormField(
                  initialValue: p.pu,
                  decoration: const InputDecoration(labelText: 'PU HT €', isDense: true, border: OutlineInputBorder()),
                  onChanged: (v) => setState(() => p.pu = v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red, size: 20),
                onPressed: () => setState(() {
                  _prestas.removeAt(i);
                  if (_prestas.isEmpty) _prestas.add(Presta());
                }),
              ),
            ],
          ),
          Text(
            'Montant : ${montant != null ? BiFormat.eur(montant) : "—"}',
            style: TextStyle(fontSize: 11, color: biAccent),
          ),
        ],
      ),
    );
  }

  Widget _deroulantPole() {
    return DropdownButtonFormField<String>(
      initialValue: _pole,
      decoration: const InputDecoration(labelText: 'Pôle', border: OutlineInputBorder(), isDense: true),
      items: Poles.all.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text('Pôle ${e.key} · ${e.value}')))
          .toList(),
      onChanged: (v) => setState(() => _pole = v ?? _pole),
    );
  }

  Widget _champTechniciens() {
    return StreamBuilder<List<String>>(
      stream: _userService.getTechnicienNames(),
      builder: (context, snapshot) {
        final noms = snapshot.data ?? const <String>[];
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: noms.map((t) {
            final selectionne = _techniciens.contains(t);
            return FilterChip(
              label: Text(t, style: const TextStyle(fontSize: 12)),
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
        );
      },
    );
  }

  Widget _champTexte(String label, String valeur, void Function(String) onChanged) {
    return TextFormField(
      initialValue: valeur,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      onChanged: (v) => setState(() => onChanged(v)),
    );
  }

  List<MapEntry<String, String>> _lignesDates(BonIntervention b) {
    if (b.pole == Poles.maintenance) {
      if (b.dateDebut.isNotEmpty && b.dateFin.isNotEmpty && b.dateDebut != b.dateFin) {
        return [MapEntry('Période d\'intervention', 'du ${b.dateDebut} au ${b.dateFin}')];
      }
      return [MapEntry('Date d\'intervention', b.dateDebut.isEmpty ? '—' : b.dateDebut)];
    }
    final lignes = <MapEntry<String, String>>[
      MapEntry(b.pole == Poles.depannage ? 'Date d\'intervention' : 'Date', b.dateIntervention.isEmpty ? '—' : b.dateIntervention),
    ];
    if (b.heureDebut.isNotEmpty || b.heureFin.isNotEmpty) {
      lignes.add(MapEntry('Horaires', [b.heureDebut, b.heureFin].where((s) => s.isNotEmpty).join(' → ')));
    }
    lignes.add(MapEntry('Temps passé', b.tempsPasse.isEmpty ? '—' : b.tempsPasse));
    return lignes;
  }

  List<Widget> _historiqueWidgets(BonIntervention b) {
    final widgets = <Widget>[];
    for (final h in b.history) {
      final user = h['user']?.toString() ?? '';
      final date = h['date']?.toString() ?? '';
      final event = h['event']?.toString() ?? '';
      widgets.add(Text('$date · $user', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)));
      if (event.isNotEmpty) widgets.add(Text(event));
      final changes = h['changes'];
      if (changes is List) {
        for (final ch in changes) {
          if (ch is Map) {
            widgets.add(
              Text(
                '• ${ch['champ']} : « ${ch['avant']} » → « ${ch['apres']} »',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            );
          }
        }
      }
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  Widget _infoLigne(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(k, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  Widget _sectionCard(String titre, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
