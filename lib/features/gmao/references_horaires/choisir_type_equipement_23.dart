import 'package:flutter/material.dart';
import 'reference_horaire_model.dart';

String _normaliser(String s) => s.trim().toLowerCase();

/// Sélection guidée de Type Equipement 2 puis 3, avec confirmation :
/// ne propose que des valeurs réellement présentes dans le catalogue
/// pour [typeEquipement1Fixe] (ex: "Split Autonome"), pour que la
/// correspondance équipement ↔ catalogue reste toujours exacte — plus
/// de saisie libre qui pourrait créer un texte ne correspondant à rien.
/// Retourne `{'typeEquipement2': ..., 'typeEquipement3': ...}`, ou
/// `null` si annulé à n'importe quelle étape.
Future<Map<String, String>?> choisirTypeEquipement23({
  required BuildContext context,
  required String typeEquipement1Fixe,
  required List<ReferenceHoraireModel> references,
}) async {
  final candidats = references
      .where(
        (r) => _normaliser(r.typeEquipement1) == _normaliser(typeEquipement1Fixe),
      )
      .toList();
  if (candidats.isEmpty) return null;

  final options2 = candidats
      .map((r) => r.typeEquipement2.trim())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  if (options2.isEmpty) return null;

  if (!context.mounted) return null;
  final type2 = await _choisirDansListe(context, 'Type Equipement 2', options2);
  if (type2 == null) return null;

  final options3 = candidats
      .where((r) => r.typeEquipement2.trim() == type2)
      .map((r) => r.typeEquipement3.trim())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  if (options3.isEmpty) return null;

  if (!context.mounted) return null;
  final type3 = await _choisirDansListe(context, 'Type Equipement 3', options3);
  if (type3 == null) return null;

  if (!context.mounted) return null;
  final confirme = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Confirmer le changement'),
      content: Text('Changer pour "$typeEquipement1Fixe - $type2 - $type3" ?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('NON'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('OUI'),
        ),
      ],
    ),
  );
  if (confirme != true) return null;

  return {'typeEquipement2': type2, 'typeEquipement3': type3};
}

Future<String?> _choisirDansListe(
  BuildContext context,
  String titre,
  List<String> options,
) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(titre),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: options
              .map(
                (o) => ListTile(
                  title: Text(o),
                  onTap: () => Navigator.pop(dialogContext, o),
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Annuler'),
        ),
      ],
    ),
  );
}
