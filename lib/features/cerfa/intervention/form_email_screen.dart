import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/cerfa_data_model.dart';

/// Écran 6 : Envoi Mail Client (cf. cahier des charges, Thématique 4.8)
///
/// Pré-remplit le destinataire, l'objet et le corps du message à partir des
/// données du CERFA finalisé, puis ouvre le client mail du technicien.
///
/// (à faire une fois la génération PDF réelle en place) :
/// `url_launcher` avec un lien `mailto:` NE PERMET PAS de joindre un fichier
/// (limitation du protocole mailto, pas de Flutter). Pour joindre le PDF
/// finalisé en pièce jointe comme demandé au cahier des charges, il faudra
/// remplacer l'envoi par le package `share_plus` (Share.shareXFiles) une fois
/// que le chemin local du PDF final (généré via syncfusion_flutter_pdf) sera
/// disponible dans CerfaData.
class FormEmailScreen extends StatefulWidget {
  final CerfaData cerfaData;

  const FormEmailScreen({super.key, required this.cerfaData});

  @override
  State<FormEmailScreen> createState() => _FormEmailScreenState();
}

class _FormEmailScreenState extends State<FormEmailScreen> {
  late final TextEditingController _emailController;
  late final String _objet;
  late final String _corps;

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    final data = widget.cerfaData;
    final e = data.equipement;

    _emailController = TextEditingController(
      text: data.emailSignataireClient.trim(),
    );

    _objet = 'CERFA 15497 – ${e.site} – ${e.nomEquipement}';

    _corps =
        'Bonjour,\n\n'
        'Nous vous prions de bien vouloir trouver en pièce jointe votre '
        'certificat de contrôle d\'étanchéité pour votre équipement suivant :\n\n'
        'Site : ${e.site}\n'
        'Équipement : ${e.nomEquipement}\n'
        'Numéro du CERFA : ${data.chronoStr}\n\n'
        'Cordialement,\n\n'
        'L\'équipe OGEC Services';
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onEnvoyer() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner une adresse email destinataire'),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final uri = Uri(
        scheme: 'mailto',
        path: email,
        query:
            'subject=${Uri.encodeComponent(_objet)}&body=${Uri.encodeComponent(_corps)}',
      );

      final launched = await launchUrl(uri);

      if (!mounted) return;

      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucune application mail disponible sur cet appareil',
            ),
          ),
        );
        setState(() => _isSending = false);
        return;
      }

      // Retour à l'écran d'accueil après envoi (Thématique 4.8.2)
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'envoi du mail : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Écran 6 : Envoi Mail Client',
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
                      'CERFA finalisé — envoi au client',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email destinataire',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email, color: Colors.blue),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Objet',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(_objet),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Message',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(_corps),
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
                      onPressed: _isSending
                          ? null
                          : () => Navigator.popUntil(context, (r) => r.isFirst),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.red, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Plus tard',
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
                      onPressed: _isSending ? null : _onEnvoyer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Envoyer',
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
