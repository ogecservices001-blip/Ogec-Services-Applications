import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/bi_constants.dart';
import '../data/bi_format.dart';
import '../data/bi_model.dart';

/// PDF officiel du bon d'intervention — A4, fidèle au bon papier OGEC.
/// Porté depuis re.ogec.bi/pdf/PdfGenerator.kt, avec les mêmes règles :
/// dates affichées selon le pôle, tableau prestations avec PU/Montant HT
/// (« — » si non renseigné par le bureau), pages suivantes réservées aux
/// photos justificatives (4 max, récupérées depuis Firebase Storage).
/// Régénéré à la volée depuis les données Firestore à chaque
/// consultation — rien n'est stocké (l'archivage Drive reste la Phase 4).
class BiPdfGenerator {
  static const _bleu = PdfColor.fromInt(0xFF1375D0);
  static const _encre = PdfColor.fromInt(0xFF14202E);
  static const _gris = PdfColor.fromInt(0xFF697382);
  static const _ligne = PdfColor.fromInt(0xFFCBD3DD);
  static const _fondSection = PdfColor.fromInt(0xFFE2EEFB);

  static const _mentionLegale =
      "La société OGEC SERVICES est titulaire de l'autorisation préfectorale N°1139819-R2, "
      "conformément à l'article R.543-106, délivrée par l'organisme bureau VERITAS "
      "CERTIFICATIONS et MINISTERE DE L'ENVIRONNEMENT, relative aux travaux de manipulation "
      "des fluides frigorigènes.";

  static Future<Uint8List> generer(BonIntervention b) async {
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/images/logo.jpg');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      logo = null;
    }

    final doc = pw.Document();
    final style = pw.TextStyle(font: regular, fontSize: 9.5, color: _encre);
    final styleBold = pw.TextStyle(font: bold, fontSize: 9.5, color: _encre);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        header: (context) => context.pageNumber == 1 ? _entete(b, logo, bold, regular) : pw.SizedBox(),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Center(
            child: pw.Text(
              _mentionLegale.toLowerCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: regular, fontSize: 6.5, color: _gris),
            ),
          ),
        ),
        build: (context) => [
          _section('LE CLIENT', bold),
          _kv('Client', b.site.isNotEmpty ? '${b.clientNom} — ${b.site}' : b.clientNom, styleBold, style),
          _kv('Adresse d\'intervention', b.adresse.isEmpty ? '—' : b.adresse, styleBold, style),
          if (b.horsContrat) _kv('Statut', 'Client hors contrat', styleBold, style),
          pw.SizedBox(height: 8),
          _section('OGEC', bold),
          _kv('Technicien(s)', b.techniciens.join(', ').isEmpty ? '—' : b.techniciens.join(', '), styleBold, style),
          if (b.affaireNumeroDevis.isNotEmpty) _kv('Affaire', b.affaireNumeroDevis, styleBold, style),
          if (b.affaireNumeroCommandeClient.isNotEmpty)
            _kv('Réf commande client', b.affaireNumeroCommandeClient, styleBold, style),
          if (b.affaireDateCommandeClient.isNotEmpty)
            _kv('Date commande client', b.affaireDateCommandeClient, styleBold, style),
          if (b.equipementNom.isNotEmpty) ...[
            if (_descriptionEquipement(b.pole) != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2, bottom: 1),
                child: pw.Text(_descriptionEquipement(b.pole)!, style: style),
              ),
            _kv('Équipement', BiFormat.equipementLabel(b), styleBold, style),
          ],
          if (b.entretienGroupes.isNotEmpty)
            _kv('Groupes entretenus', b.entretienGroupes.join(', '), styleBold, style),
          for (final ligne in _lignesDates(b)) _kv(ligne.key, ligne.value, styleBold, style),
          if (b.numeroDevis.isNotEmpty) _kv('N° devis lié', b.numeroDevis, styleBold, style),
          pw.SizedBox(height: 10),
          _section("DESCRIPTION DE L'INTERVENTION", bold),
          pw.Text(b.compteRendu.isEmpty ? '—' : b.compteRendu, style: style),
          pw.SizedBox(height: 10),
          if (b.entretienNonDesservis.isNotEmpty) ...[
            _section('ÉQUIPEMENTS NON ENTRETENUS', bold),
            for (final e in b.entretienNonDesservis) _kv(e['nom'] ?? '', e['motif'] ?? '', styleBold, style),
            pw.SizedBox(height: 10),
          ],
          // Plus personne ne saisit de prestations (ni le technicien, ni
          // le bureau) : le devis fait foi. Cette rubrique n'apparaît
          // donc plus que sur un bon antérieur qui en porte déjà.
          if (b.prestas.any((p) => p.designation.trim().isNotEmpty)) ...[
            _section('DÉTAIL DES PRESTATIONS ET FOURNITURES', bold),
            _tablePrestas(b, bold, regular),
            pw.SizedBox(height: 6),
          ],
          if (b.obsTech.isNotEmpty || b.obsClient.isNotEmpty) ...[
            _section('OBSERVATIONS', bold),
            if (b.obsTech.isNotEmpty) _kv('Technicien', b.obsTech, styleBold, style),
            if (b.obsClient.isNotEmpty) _kv('Client', b.obsClient, styleBold, style),
            pw.SizedBox(height: 8),
          ],
          pw.SizedBox(height: 24),
          pw.Divider(color: _ligne, thickness: 0.8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _blocSignature(
                  // Seul le technicien connecté signe — pas la liste de
                  // tous ceux intervenus (voir "Technicien(s)" plus haut).
                  // Repli sur cette liste pour les bons antérieurs à ce champ.
                  'Pour la Société OGEC Services\n'
                  '${b.technicienSignataire.isNotEmpty ? b.technicienSignataire : b.techniciens.join(', ')}',
                  b.sigTech,
                  styleBold,
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: _blocSignature(
                  'Pour le client - ${b.clientNom}\n${b.signataire}'
                  '${b.dateSignature.isNotEmpty ? '  (signé le ${b.dateSignature})' : ''}',
                  b.sigClient,
                  styleBold,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // pw.Page.build est synchrone : les octets des photos (fichiers
    // Firebase Storage, plus de base64 dans le document) sont
    // récupérés à l'avance. Une photo dont le téléchargement échoue
    // est simplement omise plutôt que de faire échouer tout le PDF.
    final candidats = b.photos.where((p) => p.url.isNotEmpty).take(4).toList();
    final octetsParUrl = <String, Uint8List>{};
    for (final p in candidats) {
      try {
        final reponse = await http.get(Uri.parse(p.url));
        if (reponse.statusCode == 200) octetsParUrl[p.url] = reponse.bodyBytes;
      } catch (_) {
        // omise, voir commentaire ci-dessus.
      }
    }
    final photos = candidats.where((p) => octetsParUrl.containsKey(p.url)).toList();

    for (var i = 0; i < photos.length; i += 2) {
      final paire = photos.sublist(i, i + 2 > photos.length ? photos.length : i + 2);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Annexes photos — ${b.numero}',
                style: pw.TextStyle(font: bold, fontSize: 12, color: _bleu),
              ),
              pw.SizedBox(height: 12),
              for (final p in paire) ...[
                pw.Image(pw.MemoryImage(octetsParUrl[p.url]!), fit: pw.BoxFit.contain, height: 320),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${photoTypes[p.type] ?? p.type}'
                  '${p.legende.isNotEmpty ? ' — ${p.legende}' : ''}'
                  '${p.horodatage.isNotEmpty ? '  (${p.horodatage})' : ''}',
                  style: pw.TextStyle(font: regular, fontSize: 9, color: _encre),
                ),
                pw.SizedBox(height: 16),
              ],
            ],
          ),
        ),
      );
    }

    return doc.save();
  }

  static pw.Widget _entete(BonIntervention b, pw.MemoryImage? logo, pw.Font bold, pw.Font regular) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null) ...[
              pw.Container(width: 90, child: pw.Image(logo)),
              pw.SizedBox(width: 12),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SARL OGEC SERVICES', style: pw.TextStyle(font: bold, fontSize: 12, color: _encre)),
                  pw.Text(
                    '918, Chemin Tour des Roches — 97460 Saint-Paul',
                    style: pw.TextStyle(font: regular, fontSize: 8, color: _gris),
                  ),
                  pw.Text(
                    'Tél. 0262 26 00 86 · ogec.services@orange.fr',
                    style: pw.TextStyle(font: regular, fontSize: 8, color: _gris),
                  ),
                ],
              ),
            ),
            pw.Container(
              width: 130,
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: const pw.BoxDecoration(color: _fondSection),
              child: pw.Text(
                b.numero,
                style: pw.TextStyle(font: bold, fontSize: 13, color: _encre),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text("BON D'INTERVENTION", style: pw.TextStyle(font: bold, fontSize: 18, color: _bleu)),
            pw.Text(
              'Pôle ${b.pole} · ${Poles.label(b.pole)}',
              style: pw.TextStyle(font: bold, fontSize: 9.5, color: _encre),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _section(String titre, pw.Font bold) => pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(bottom: 4),
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
    color: _bleu,
    child: pw.Text(titre, style: pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.white)),
  );

  static pw.Widget _kv(String k, String v, pw.TextStyle keyStyle, pw.TextStyle valStyle) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Assez large pour les libellés les plus longs (ex: "Date
        // d'intervention :") — sinon le mot de fin retombe seul à la
        // ligne suivante, sans sa valeur à côté.
        pw.SizedBox(width: 135, child: pw.Text('$k :', style: keyStyle)),
        pw.Expanded(child: pw.Text(v, style: valStyle)),
      ],
    ),
  );

  /// Phrase affichée juste avant la ligne "Équipement" — précise la
  /// nature de l'intervention sur cet équipement selon le pôle ; null si
  /// le pôle ne le justifie pas (l'équipement reste alors simplement
  /// informatif, sans besoin de contexte supplémentaire).
  static String? _descriptionEquipement(String pole) => switch (pole) {
    Poles.installationNeuve => 'Équipement complémentaire',
    Poles.remplacementIdentique => 'Remplacement d\'un équipement existant',
    Poles.reparationEquipement => 'Réparation d\'un équipement existant',
    Poles.reparationDiverse => 'Réparation diverse sur équipement existant',
    Poles.entretienSousContrat => 'Entretien d\'un équipement sous contrat',
    Poles.entretienHorsContrat => 'Entretien d\'un équipement hors contrat',
    _ => null,
  };

  static List<MapEntry<String, String>> _lignesDates(BonIntervention b) {
    if (Poles.avecPeriode(b.pole)) {
      if (b.dateDebut.isNotEmpty && b.dateFin.isNotEmpty && b.dateDebut != b.dateFin) {
        return [MapEntry("Période d'intervention", 'du ${b.dateDebut} au ${b.dateFin}')];
      }
      return [MapEntry("Date d'intervention", b.dateDebut.isEmpty ? '—' : b.dateDebut)];
    }
    final lignes = <MapEntry<String, String>>[
      MapEntry("Date d'intervention", b.dateIntervention.isEmpty ? '—' : b.dateIntervention),
    ];
    if (b.heureDebut.isNotEmpty || b.heureFin.isNotEmpty) {
      lignes.add(MapEntry('Horaires', [b.heureDebut, b.heureFin].where((s) => s.isNotEmpty).join(' → ')));
    }
    // Temps passé retiré du PDF — sert au calcul interne, pas à
    // apparaître sur le document remis au client.
    return lignes;
  }

  static pw.Widget _tablePrestas(BonIntervention b, pw.Font bold, pw.Font regular) {
    final prestas = b.prestas.where((p) => p.designation.trim().isNotEmpty).take(10).toList();
    final lignes = prestas.isEmpty ? [Presta(designation: '—')] : prestas;
    final total = BiFormat.totalHT(prestas);
    final hasPrix = prestas.any((p) => BiFormat.montantLigne(p) != null);

    final headerStyle = pw.TextStyle(font: bold, fontSize: 9, color: _encre);
    final cellStyle = pw.TextStyle(font: regular, fontSize: 9, color: _encre);

    pw.Widget cellule(String texte, pw.TextStyle s, {pw.Alignment align = pw.Alignment.centerLeft}) => pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(texte, style: s),
    );

    return pw.Table(
      border: pw.TableBorder(horizontalInside: pw.BorderSide(color: _ligne, width: 0.6)),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(0.8),
        2: pw.FlexColumnWidth(1.1),
        3: pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _fondSection),
          children: [
            cellule('Désignation', headerStyle),
            cellule('Nb', headerStyle),
            cellule('PU HT', headerStyle),
            cellule('Montant HT', headerStyle),
          ],
        ),
        for (final p in lignes)
          pw.TableRow(
            children: [
              cellule(p.designation, cellStyle),
              cellule(p.quantite, cellStyle),
              cellule(BiFormat.parsePu(p.pu) != null ? BiFormat.eur(BiFormat.parsePu(p.pu)!) : '—', cellStyle),
              cellule(BiFormat.montantLigne(p) != null ? BiFormat.eur(BiFormat.montantLigne(p)!) : '—', cellStyle),
            ],
          ),
        if (hasPrix)
          pw.TableRow(
            children: [
              cellule('', cellStyle),
              cellule('', cellStyle),
              cellule('Total HT', headerStyle),
              cellule(BiFormat.eur(total), headerStyle),
            ],
          ),
      ],
    );
  }

  static pw.Widget _blocSignature(String titre, String sigBase64, pw.TextStyle titreStyle) {
    Uint8List? bytes;
    if (sigBase64.isNotEmpty) {
      try {
        bytes = base64Decode(sigBase64);
      } catch (_) {
        bytes = null;
      }
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(titre, style: titreStyle),
        pw.SizedBox(height: 6),
        if (bytes != null)
          pw.Image(pw.MemoryImage(bytes), height: 70, fit: pw.BoxFit.contain)
        else
          pw.SizedBox(height: 70),
      ],
    );
  }
}
