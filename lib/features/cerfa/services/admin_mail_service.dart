import 'dart:convert';
import 'dart:typed_data';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Envoie un email via l'API Gmail, en utilisant le compte Google de
/// l'administrateur (connecté via AdminAuthService), sans passer par un
/// serveur intermédiaire.
class AdminMailService {
  Future<void> envoyerMail({
    required GoogleSignInAccount compte,
    required String destinataire,
    required String objet,
    required String corps,
  }) async {
    final headers = await compte.authHeaders;
    final raw = _construireMessageBrut(
      from: compte.email,
      to: destinataire,
      subject: objet,
      body: corps,
    );

    final response = await http.post(
      Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages/send'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'raw': raw}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Échec de l\'envoi (${response.statusCode}) : ${response.body}',
      );
    }
  }

  /// Envoie un email avec le PDF du CERFA en pièce jointe réelle
  /// (message MIME multipart, encodé en base64 comme attendu par
  /// l'API Gmail).
  Future<void> envoyerMailAvecPieceJointe({
    required GoogleSignInAccount compte,
    required String destinataire,
    required String objet,
    required String corps,
    required String nomFichier,
    required Uint8List pieceJointe,
  }) async {
    final headers = await compte.authHeaders;
    final raw = _construireMessageAvecPieceJointe(
      from: compte.email,
      to: destinataire,
      subject: objet,
      body: corps,
      filename: nomFichier,
      attachment: pieceJointe,
    );

    final response = await http.post(
      Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages/send'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'raw': raw}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Échec de l\'envoi (${response.statusCode}) : ${response.body}',
      );
    }
  }

  String _construireMessageBrut({
    required String from,
    required String to,
    required String subject,
    required String body,
  }) {
    final subjectEncode = '=?UTF-8?B?${base64.encode(utf8.encode(subject))}?=';
    final message =
        'From: $from\r\n'
        'To: $to\r\n'
        'Subject: $subjectEncode\r\n'
        'MIME-Version: 1.0\r\n'
        'Content-Type: text/plain; charset="UTF-8"\r\n\r\n'
        '$body';

    return base64Url.encode(utf8.encode(message)).replaceAll('=', '');
  }

  String _construireMessageAvecPieceJointe({
    required String from,
    required String to,
    required String subject,
    required String body,
    required String filename,
    required Uint8List attachment,
  }) {
    final boundary = 'ogec_boundary_${DateTime.now().millisecondsSinceEpoch}';
    final subjectEncode = '=?UTF-8?B?${base64.encode(utf8.encode(subject))}?=';
    final attachmentBase64 = _decouperEnLignes(base64.encode(attachment));

    final message = StringBuffer()
      ..write('From: $from\r\n')
      ..write('To: $to\r\n')
      ..write('Subject: $subjectEncode\r\n')
      ..write('MIME-Version: 1.0\r\n')
      ..write('Content-Type: multipart/mixed; boundary="$boundary"\r\n\r\n')
      ..write('--$boundary\r\n')
      ..write('Content-Type: text/plain; charset="UTF-8"\r\n\r\n')
      ..write('$body\r\n\r\n')
      ..write('--$boundary\r\n')
      ..write('Content-Type: application/pdf; name="$filename"\r\n')
      ..write('Content-Disposition: attachment; filename="$filename"\r\n')
      ..write('Content-Transfer-Encoding: base64\r\n\r\n')
      ..write('$attachmentBase64\r\n')
      ..write('--$boundary--');

    return base64Url
        .encode(utf8.encode(message.toString()))
        .replaceAll('=', '');
  }

  /// Découpe le base64 en lignes de 76 caractères, conformément à la
  /// norme MIME (RFC 2045) — évite d'éventuels rejets par certains
  /// clients mail avec une ligne unique trop longue.
  String _decouperEnLignes(String base64String) {
    final buffer = StringBuffer();
    for (int i = 0; i < base64String.length; i += 76) {
      final fin = (i + 76 > base64String.length) ? base64String.length : i + 76;
      buffer.writeln(base64String.substring(i, fin));
    }
    return buffer.toString();
  }
}
