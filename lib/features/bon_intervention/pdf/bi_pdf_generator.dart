import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../affaires/data/affaire_constants.dart';
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
        build: (context) => [
          _section('LE CLIENT', bold),
          _kv('Client', b.site.isNotEmpty ? '${b.clientNom} — ${b.site}' : b.clientNom, styleBold, style),
          _kv('Adresse', b.adresse.isEmpty ? '—' : b.adresse, styleBold, style),
          if (b.horsContrat) _kv('Statut', 'Client hors contrat', styleBold, style),
          pw.SizedBox(height: 4),
          _section('OGEC', bold),
          _kv('Technicien(s)', b.techniciens.join(', ').isEmpty ? '—' : b.techniciens.join(', '), styleBold, style),
          if (b.affaireNumeroDevis.isNotEmpty) _kv('Affaire', b.affaireNumeroDevis, styleBold, style),
          if (b.natureTravaux.isNotEmpty)
            _kv('Nature', NatureAffaire.label(b.natureTravaux), styleBold, style),
          if (b.equipementNom.isNotEmpty) _kv('Équipement', b.equipementNom, styleBold, style),
          for (final ligne in _lignesDates(b)) _kv(ligne.key, ligne.value, styleBold, style),
          if (b.numeroDevis.isNotEmpty) _kv('N° devis lié', b.numeroDevis, styleBold, style),
          pw.SizedBox(height: 4),
          _section("DESCRIPTION DE L'INTERVENTION", bold),
          pw.Text(b.compteRendu.isEmpty ? '—' : b.compteRendu, style: style),
          pw.SizedBox(height: 6),
          _section('DÉTAIL DES PRESTATIONS ET FOURNITURES', bold),
          _tablePrestas(b, bold, regular),
          pw.SizedBox(height: 6),
          if (b.obsTech.isNotEmpty || b.obsClient.isNotEmpty) ...[
            _section('OBSERVATIONS', bold),
            if (b.obsTech.isNotEmpty) _kv('Technicien', b.obsTech, styleBold, style),
            if (b.obsClient.isNotEmpty) _kv('Client', b.obsClient, styleBold, style),
            pw.SizedBox(height: 4),
          ],
          pw.SizedBox(height: 16),
          pw.Divider(color: _ligne, thickness: 0.8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _blocSignature('Le technicien — ${b.techniciens.join(', ')}', b.sigTech, styleBold)),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: _blocSignature(
                  'Le client — ${b.signataire}${b.dateSignature.isNotEmpty ? '  (signé le ${b.dateSignature})' : ''}',
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
        pw.SizedBox(width: 95, child: pw.Text('$k :', style: keyStyle)),
        pw.Expanded(child: pw.Text(v, style: valStyle)),
      ],
    ),
  );

  static List<MapEntry<String, String>> _lignesDates(BonIntervention b) {
    if (b.pole == Poles.maintenance) {
      if (b.dateDebut.isNotEmpty && b.dateFin.isNotEmpty && b.dateDebut != b.dateFin) {
        return [MapEntry("Période d'intervention", 'du ${b.dateDebut} au ${b.dateFin}')];
      }
      return [MapEntry("Date d'intervention", b.dateDebut.isEmpty ? '—' : b.dateDebut)];
    }
    final lignes = <MapEntry<String, String>>[
      MapEntry(b.pole == Poles.depannage ? "Date d'intervention" : 'Date', b.dateIntervention.isEmpty ? '—' : b.dateIntervention),
    ];
    if (b.heureDebut.isNotEmpty || b.heureFin.isNotEmpty) {
      lignes.add(MapEntry('Horaires', [b.heureDebut, b.heureFin].where((s) => s.isNotEmpty).join(' → ')));
    }
    lignes.add(MapEntry('Temps passé', b.tempsPasse.isEmpty ? '—' : b.tempsPasse));
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
