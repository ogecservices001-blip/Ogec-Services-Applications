import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'equipement_model.dart';

/// URL publique (sans connexion) d'un équipement, ouverte en scannant son
/// QR code — voir [EquipementPublicScreen] et la détection de route dans
/// `app.dart`.
String urlPubliqueEquipement(String equipementId) =>
    'https://ogec-services-app.web.app/equipement/$equipementId';

/// Dialogue affichant le QR code à imprimer et coller sur l'équipement
/// physique — scanné, il ouvre la page publique de consultation +
/// demande de dépannage.
class EquipementQrDialog extends StatelessWidget {
  final EquipementModel equipement;

  const EquipementQrDialog({super.key, required this.equipement});

  @override
  Widget build(BuildContext context) {
    final url = urlPubliqueEquipement(equipement.id);
    return AlertDialog(
      title: Text('QR code — ${equipement.nom}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: QrImageView(data: url, size: 220),
          ),
          const SizedBox(height: 12),
          Text(
            'À imprimer et coller sur l\'équipement. Une fois scanné, ce '
            'code ouvre une page publique permettant de consulter les '
            'données de l\'équipement et de signaler une panne.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          SelectableText(
            url,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}
