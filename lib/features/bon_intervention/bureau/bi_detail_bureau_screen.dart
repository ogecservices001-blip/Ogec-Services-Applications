import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/auth/admin_google_session.dart';
import '../../../core/services/user_service.dart';
import '../../gmao/equipements/equipement_model.dart';
import '../../gmao/gmao_database_service.dart';
import '../../gmao/types_equipement/type_equipement_model.dart';
import '../data/bi_constants.dart';
import '../data/bi_format.dart';
import '../data/bi_model.dart';
import '../data/bi_service.dart';
import '../pdf/bi_drive_service.dart';
import '../pdf/bi_pdf_generator.dart';
import '../wizard/bi_technicien_picker_screen.dart';
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

  /// Génère le PDF et l'archive sur Drive si ce n'est pas déjà fait —
  /// appelée automatiquement à la validation (voir _valider) pour que le
  /// document existe sans étape manuelle supplémentaire ; sert aussi de
  /// filet de sécurité si un bon plus ancien n'a jamais été archivé.
  Future<void> _archiverPdfSiBesoin(BonIntervention b) async {
    if (b.pdfDriveUrl.isNotEmpty || !mounted) return;
    final bytes = await BiPdfGenerator.generer(b);
    if (!mounted) return;
    final compte = await AdminGoogleSession.instance.ensureSignedIn(context);
    final resultat = await _driveService.archiverBI(adminAccount: compte, bi: b, pdfBytes: bytes);
    await _biService.updateBI(b.id, {
      'statut': Statuts.pretEnvoi,
      'driveBiFolderId': resultat.biFolderId,
      'pdfDriveUrl': resultat.pdfLink,
      'jsonDriveUrl': resultat.jsonLink,
    });
  }

  Future<void> _voirPdf(BonIntervention b) async {
    setState(() => _pdfEnCours = true);
    try {
      final bytes = await BiPdfGenerator.generer(b);
      await Printing.layoutPdf(onLayout: (format) async => bytes);
      await _archiverPdfSiBesoin(b);
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
  }

  @override
  void dispose() {
    if (_initialise) {
      _compteRenduController.dispose();
      _obsTechController.dispose();
      _noteInterneController.dispose();
      _emailController.dispose();
    }
    super.dispose();
  }

  Future<void> _choisirTechniciens() async {
    final resultat = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (context) => BiTechnicienPickerScreen(selectionInitiale: _techniciens)),
    );
    if (resultat != null && mounted) {
      final ancienEffectif = _techniciens.length;
      setState(() {
        _techniciens
          ..clear()
          ..addAll(resultat);
        if (Poles.avecTempsLibre(_pole)) {
          _tempsPasse = BiFormat.ajusterDureeEffectif(_tempsPasse, ancienEffectif, _techniciens.length);
        }
      });
    }
  }

  Future<void> _ajouterTechnicienConnecte() async {
    final nom = await _userService.getCurrentUserName();
    if (nom.isEmpty || !mounted || _techniciens.contains(nom)) return;
    final ancienEffectif = _techniciens.length;
    setState(() {
      _techniciens.add(nom);
      if (Poles.avecTempsLibre(_pole)) {
        _tempsPasse = BiFormat.ajusterDureeEffectif(_tempsPasse, ancienEffectif, _techniciens.length);
      }
    });
  }

  bool get _emailValide => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_emailController.text.trim());

  bool _peutValider(BonIntervention original) {
    if (!_emailValide) return false;
    if (original.pole == Poles.installationNeuve) {
      // Normalement déjà garanti côté technicien (voir
      // Poles.avecNouvelEquipement dans l'assistant BI) — filet de
      // sécurité pour un bon plus ancien qui n'en disposerait pas.
      return original.equipementNom.trim().isNotEmpty &&
          original.materielTypeEquipementId.isNotEmpty;
    }
    return true;
  }

  /// Automatisation GMAO déclenchée par la validation bureau d'un bon,
  /// selon le pôle (nature du travail — voir affaires/BI Étape C) — ne
  /// doit jamais bloquer la validation du bon elle-même si elle échoue,
  /// appelée après le `saveBI` réussi.
  Future<void> _executerAutomatisationGmao(BonIntervention bi) async {
    final date = BiFormat.now();
    switch (bi.pole) {
      case Poles.reparationEquipement:
        if (bi.equipementId.isEmpty) return;
        await _gmaoDb.ajouterRemarqueEquipement(
          bi.equipementId,
          'Réparé le $date via ${bi.numero} : ${bi.compteRendu}',
        );
        break;
      case Poles.entretienHorsContrat:
        if (bi.equipementId.isEmpty) return;
        await _gmaoDb.ajouterRemarqueEquipement(
          bi.equipementId,
          'Entretien effectué le $date via ${bi.numero} : ${bi.compteRendu}',
        );
        break;
      case Poles.entretienSousContrat:
        // Un ou plusieurs groupes plutôt qu'un équipement unique (voir
        // Poles.avecGroupesEntretien) — la remarque est reportée sur
        // chaque équipement des groupes cochés, sauf ceux marqués non
        // entretenus (voir entretienNonDesservis).
        if (bi.entretienGroupes.isEmpty) return;
        final equipementsSite = await _gmaoDb.getEquipementsForClient(bi.clientId).first;
        final nomsNonDesservis = bi.entretienNonDesservis.map((e) => e['nom']).toSet();
        for (final eq in equipementsSite) {
          if (!bi.entretienGroupes.contains(eq.groupe) || nomsNonDesservis.contains(eq.nom)) continue;
          await _gmaoDb.ajouterRemarqueEquipement(
            eq.id,
            'Entretien effectué le $date via ${bi.numero} : ${bi.compteRendu}',
          );
        }
        break;
      case Poles.remplacementIdentique:
        if (bi.equipementId.isEmpty) return;
        await _gmaoDb.ajouterRemarqueEquipement(
          bi.equipementId,
          'Remplacé le $date via ${bi.numero} : ${bi.compteRendu}',
        );
        final data = <String, dynamic>{
          for (final entry in bi.materielChampsEnTete.entries)
            if (!champsMaterielExclusBI.contains(entry.key) &&
                entry.value != null &&
                entry.value.toString().trim().isNotEmpty)
              'champsEnTete.${entry.key}': entry.value,
        };
        if (data.isNotEmpty) await _gmaoDb.updateEquipement(bi.equipementId, data);
        break;
      case Poles.installationNeuve:
        if (bi.equipementNom.trim().isEmpty || bi.materielTypeEquipementId.isEmpty) return;
        final champsEnTete = <String, dynamic>{
          for (final entry in bi.materielChampsEnTete.entries)
            if (!champsMaterielExclusBI.contains(entry.key) &&
                entry.value != null &&
                entry.value.toString().trim().isNotEmpty)
              entry.key: entry.value,
        };
        await _gmaoDb.addEquipement(
          EquipementModel(
            id: '',
            clientId: bi.clientId,
            typeEquipementId: bi.materielTypeEquipementId,
            nom: bi.equipementNom,
            localisation: bi.equipementLocalisation,
            groupe: bi.equipementGroupe,
            horsContrat: bi.horsContrat,
            champsEnTete: champsEnTete,
            remarqueTechnicien:
                'Installé le $date via ${bi.numero} : ${bi.compteRendu} — Hors contrat d\'entretien.',
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
      diff('Email client', original.email, _emailController.text.trim());
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
        equipementGroupe: original.equipementGroupe,
        equipementLocalisation: original.equipementLocalisation,
        affaireId: original.affaireId,
        affaireNumeroDevis: original.affaireNumeroDevis,
        affaireNumeroCommandeClient: original.affaireNumeroCommandeClient,
        affaireDateCommandeClient: original.affaireDateCommandeClient,
        materielTypeEquipementId: original.materielTypeEquipementId,
        materielChampsEnTete: original.materielChampsEnTete,
        entretienGroupes: original.entretienGroupes,
        entretienNonDesservis: original.entretienNonDesservis,
        dateDebut: _dateDebut,
        dateFin: _dateFin,
        dateIntervention: _dateIntervention,
        tempsPasse: _tempsPasse,
        heureDebut: _heureDebut,
        heureFin: _heureFin,
        techniciens: _techniciens,
        technicienSignataire: original.technicienSignataire,
        compteRendu: _compteRenduController.text.trim(),
        obsTech: _obsTechController.text.trim(),
        obsClient: original.obsClient,
        prestas: original.prestas,
        photos: original.photos,
        sigTech: original.sigTech,
        sigClient: original.sigClient,
        signataire: original.signataire,
        signataireTelPortable: original.signataireTelPortable,
        signataireTelFixe: original.signataireTelFixe,
        dateSignature: original.dateSignature,
        numeroDevis: original.numeroDevis,
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
      try {
        await _archiverPdfSiBesoin(bi);
      } catch (_) {
        // Idem : l'archivage PDF ne doit jamais bloquer la validation —
        // le bouton "Voir PDF" reste un filet de sécurité si ça échoue ici.
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
                    if (_statutsAvecPdf.contains(b.statut)) ...[
                      OutlinedButton.icon(
                        onPressed: _pdfEnCours ? null : () => _voirPdf(b),
                        icon: _pdfEnCours
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red[700]),
                              )
                            : Icon(Icons.picture_as_pdf_outlined, size: 16, color: Colors.red[700]),
                        label: const Text('Voir PDF'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[700],
                          side: BorderSide(color: Colors.red[700]!),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
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
        if (b.affaireNumeroCommandeClient.isNotEmpty) _infoLigne('N° commande client', b.affaireNumeroCommandeClient),
        if (b.affaireDateCommandeClient.isNotEmpty) _infoLigne('Date commande client', b.affaireDateCommandeClient),
        if (b.equipementNom.isNotEmpty) _infoLigne('Équipement', BiFormat.equipementLabel(b)),
        if (b.entretienGroupes.isNotEmpty) _infoLigne('Groupes entretenus', b.entretienGroupes.join(', ')),
        ..._lignesDates(b).map((e) => _infoLigne(e.key, e.value)),
      ]),
      _sectionCard('Compte rendu', [Text(b.compteRendu.isEmpty ? '—' : b.compteRendu)]),
      if (b.entretienNonDesservis.isNotEmpty)
        _sectionCard('Équipements non entretenus', [
          for (final e in b.entretienNonDesservis) _infoLigne(e['nom'] ?? '', e['motif'] ?? ''),
        ]),
      // Plus personne ne saisit de prestations sur devis (ni le
      // technicien, ni le bureau) : le devis fait foi. Dépannage seul y
      // échappe (voir Poles.avecFournitureMateriel) ; ne reste sinon
      // visible que sur un bon antérieur qui en porte déjà.
      if (prestas.isNotEmpty)
        _sectionCard('Prestations & fournitures', [
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
        ]),
    ];
  }

  List<Widget> _vueCorrection(BonIntervention original) {
    // Les heures d'arrivée/départ ne sont plus saisies par le technicien
    // (retirées de l'assistant) — ce bloc ne reste visible que pour
    // corriger un bon plus ancien qui en porte déjà.
    final avecHeuresHeritees = original.heureDebut.isNotEmpty || original.heureFin.isNotEmpty;
    final mesure = BiFormat.dureeEntre(_heureDebut, _heureFin);
    return [
      if (original.equipementNom.isNotEmpty) ...[
        if (original.pole == Poles.installationNeuve)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.orange[800]),
                const SizedBox(width: 6),
                Text(
                  'Nouvel équipement — à confirmer avant validation',
                  style: TextStyle(fontSize: 12, color: Colors.orange[800], fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        _sectionCard('Équipement', [
          _infoLigne(
            'Nom',
            original.pole == Poles.installationNeuve ? '${original.equipementNom} (à confirmer)' : original.equipementNom,
          ),
          if (original.equipementGroupe.isNotEmpty)
            _infoLigne(
              'Groupe',
              original.pole == Poles.installationNeuve
                  ? '${original.equipementGroupe} (à confirmer)'
                  : original.equipementGroupe,
            ),
          if (original.equipementLocalisation.isNotEmpty) _infoLigne('Localisation', original.equipementLocalisation),
          if ((original.pole == Poles.remplacementIdentique || original.pole == Poles.installationNeuve) &&
              original.materielChampsEnTete.isNotEmpty)
            _blocMaterielLectureSeule(original),
        ]),
      ],
      if (original.entretienGroupes.isNotEmpty)
        _sectionCard('Groupes entretenus', [
          _infoLigne('Groupes', original.entretienGroupes.join(', ')),
        ]),
      if (original.entretienNonDesservis.isNotEmpty)
        _sectionCard('Équipements non entretenus', [
          for (final e in original.entretienNonDesservis) _infoLigne(e['nom'] ?? '', e['motif'] ?? ''),
        ]),
      _sectionCard('Vérification & correction (bureau)', [
        _deroulantPole(),
        const SizedBox(height: 10),
        _champTechniciens(),
        const SizedBox(height: 10),
        if (Poles.avecPeriode(_pole))
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
                  'Date d\'intervention',
                  _dateIntervention,
                  (v) => _dateIntervention = v,
                ),
              ),
              // Pôles liés à un devis (Poles.sansTempsPasse) : le temps
              // est déjà couvert par le devis, jamais saisi côté BI.
              if (!Poles.sansTempsPasse(_pole)) ...[
                const SizedBox(width: 10),
                Expanded(child: _champTexte('Temps passé', _tempsPasse, (v) => _tempsPasse = v)),
              ],
            ],
          ),
          if (avecHeuresHeritees) ...[
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
        if (original.equipementId.isNotEmpty) ...[
          const SizedBox(height: 6),
          // Report effectif sur la fiche équipement pas encore branché —
          // voulu comme un second temps, ce bouton n'est qu'un
          // emplacement pour l'instant.
          OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Report sur la fiche équipement — disponible prochainement')),
            ),
            icon: const Icon(Icons.precision_manufacturing_outlined, size: 18),
            label: const Text('Reporter sur la fiche équipement'),
            style: OutlinedButton.styleFrom(foregroundColor: biAccent, side: BorderSide(color: biAccent)),
          ),
        ],
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

  /// Caractéristiques du matériel (Installation neuve/Remplacement à
  /// l'identique) — clés génériques (voir BonIntervention.materielChampsEnTete),
  /// affichées avec le libellé humain de leur famille d'équipement plutôt
  /// que la clé technique brute.
  Widget _blocMaterielLectureSeule(BonIntervention original) {
    return StreamBuilder<List<TypeEquipementModel>>(
      stream: _gmaoDb.getTypesEquipement(),
      builder: (context, snapshot) {
        final type = (snapshot.data ?? const <TypeEquipementModel>[])
            .where((t) => t.id == original.materielTypeEquipementId)
            .firstOrNull;
        final labelParCle = {
          for (final champ in type?.champsEnTeteSupplementaires ?? const []) champ.cle: champ.label,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in original.materielChampsEnTete.entries)
              if (!champsMaterielExclusBI.contains(entry.key) &&
                  entry.value != null &&
                  entry.value.toString().trim().isNotEmpty)
                _infoLigne(labelParCle[entry.key] ?? entry.key, entry.value.toString()),
          ],
        );
      },
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_techniciens.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _techniciens.map((t) {
              return Chip(
                label: Text(t, style: const TextStyle(fontSize: 12)),
                backgroundColor: biAccent.withValues(alpha: 0.12),
                onDeleted: () => setState(() {
                  final ancienEffectif = _techniciens.length;
                  _techniciens.remove(t);
                  if (Poles.avecTempsLibre(_pole)) {
                    _tempsPasse = BiFormat.ajusterDureeEffectif(_tempsPasse, ancienEffectif, _techniciens.length);
                  }
                }),
              );
            }).toList(),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _choisirTechniciens,
              icon: const Icon(Icons.group_add_outlined, size: 18),
              label: const Text('Ajouter un intervenant'),
              style: OutlinedButton.styleFrom(foregroundColor: biAccent, side: BorderSide(color: biAccent)),
            ),
            TextButton.icon(
              onPressed: _ajouterTechnicienConnecte,
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('M\'ajouter'),
            ),
          ],
        ),
      ],
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
    if (Poles.avecPeriode(b.pole)) {
      if (b.dateDebut.isNotEmpty && b.dateFin.isNotEmpty && b.dateDebut != b.dateFin) {
        return [MapEntry('Période d\'intervention', 'du ${b.dateDebut} au ${b.dateFin}')];
      }
      return [MapEntry('Date d\'intervention', b.dateDebut.isEmpty ? '—' : b.dateDebut)];
    }
    final lignes = <MapEntry<String, String>>[
      MapEntry('Date d\'intervention', b.dateIntervention.isEmpty ? '—' : b.dateIntervention),
    ];
    if (b.heureDebut.isNotEmpty || b.heureFin.isNotEmpty) {
      lignes.add(MapEntry('Horaires', [b.heureDebut, b.heureFin].where((s) => s.isNotEmpty).join(' → ')));
    }
    if (!Poles.sansTempsPasse(b.pole)) {
      lignes.add(MapEntry('Temps passé', b.tempsPasse.isEmpty ? '—' : b.tempsPasse));
    }
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
