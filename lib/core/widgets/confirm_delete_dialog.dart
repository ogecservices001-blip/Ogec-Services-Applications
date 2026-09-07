import 'package:flutter/material.dart';

/// Boîte de dialogue de confirmation simple (Oui/Non) pour la
/// suppression d'un seul élément — même style que les écrans de fiche
/// existants (client, fournisseur).
Future<bool> confirmerSuppression({
  required BuildContext context,
  required String titre,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(titre),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('ANNULER'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('SUPPRIMER', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Boîte de dialogue de confirmation pour une suppression en masse et
/// irréversible : le bouton "SUPPRIMER" ne s'active que si l'utilisateur
/// a tapé exactement [motConfirmation] — un simple "OK" ne suffit pas
/// pour une action de cette ampleur.
Future<bool> confirmerSuppressionMasse({
  required BuildContext context,
  required String titre,
  required String message,
  required String motConfirmation,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        final ok = controller.text.trim() == motConfirmation;
        return AlertDialog(
          title: Text(titre),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 12),
              Text(
                'Tape "$motConfirmation" pour confirmer :',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ANNULER'),
            ),
            TextButton(
              onPressed: ok ? () => Navigator.pop(dialogContext, true) : null,
              child: const Text(
                'SUPPRIMER',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    ),
  );
  return result ?? false;
}
