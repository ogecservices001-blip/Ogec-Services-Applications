import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Bouton "scanner" à poser en `suffixIcon` d'un champ texte (référence,
/// n° de série...) — prend une photo de l'étiquette/plaque signalétique
/// et propose au technicien les lignes de texte reconnues pour remplir
/// le champ, plutôt que de retaper un numéro à rallonge.
///
/// Google ML Kit est un SDK natif (Android/iOS), sans équivalent web —
/// ce bouton se rend donc invisible sur le web plutôt que d'échouer.
/// Réutilisable partout où un champ vient du Référentiel équipements
/// (BI comme relevés GMAO), aucun champ codé en dur.
class OcrScanButton extends StatefulWidget {
  final TextEditingController controller;

  /// Appelé avec le texte choisi, en plus de la mise à jour du
  /// contrôleur — pour que l'appelant puisse synchroniser son propre
  /// état (ex: une Map de valeurs), puisque changer `controller.text`
  /// directement ne déclenche pas `onChanged`.
  final ValueChanged<String>? onRecognized;

  const OcrScanButton({super.key, required this.controller, this.onRecognized});

  @override
  State<OcrScanButton> createState() => _OcrScanButtonState();
}

class _OcrScanButtonState extends State<OcrScanButton> {
  bool _enCours = false;

  Future<void> _scanner() async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
    if (xfile == null || !mounted) return;
    setState(() => _enCours = true);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final resultat = await recognizer.processImage(InputImage.fromFilePath(xfile.path));
      final lignes = resultat.text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (!mounted) return;
      if (lignes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun texte reconnu sur la photo.')),
        );
        return;
      }
      final choisie = lignes.length == 1 ? lignes.first : await _choisirLigne(lignes);
      if (choisie != null) {
        widget.controller.text = choisie;
        widget.onRecognized?.call(choisie);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec de la lecture : $e')));
    } finally {
      await recognizer.close();
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<String?> _choisirLigne(List<String> lignes) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Texte reconnu — choisir la ligne à utiliser',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final ligne in lignes) ListTile(title: Text(ligne), onTap: () => Navigator.pop(context, ligne)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    return IconButton(
      icon: _enCours
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.camera_alt_outlined),
      tooltip: 'Scanner (OCR)',
      onPressed: _enCours ? null : _scanner,
    );
  }
}
