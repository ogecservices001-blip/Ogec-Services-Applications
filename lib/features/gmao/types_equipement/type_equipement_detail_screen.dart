import 'package:flutter/material.dart';
import 'type_equipement_model.dart';
import '../releve/dynamic_releve_form_screen.dart';

class TypeEquipementDetailScreen extends StatelessWidget {
  final TypeEquipementModel type;

  const TypeEquipementDetailScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(type.nom),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.teal[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.precision_manufacturing_outlined,
                      size: 42,
                      color: Colors.teal,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type.nom,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          Text(
                            type.code,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DynamicReleveFormScreen(type: type),
                  ),
                ),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Prévisualiser le formulaire de relevé'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            if (type.champsEnTeteSupplementaires.isNotEmpty) ...[
              _sectionTitle('Champs d\'en-tête spécifiques'),
              _card(
                type.champsEnTeteSupplementaires
                    .map(
                      (c) => _simpleRow(
                        c.label,
                        trailing: c.options.isEmpty
                            ? const Text(
                                'Texte',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blueGrey,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : Flexible(
                                child: Text(
                                  '${c.options.length} choix',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                ),
                              ),
                      ),
                    )
                    .toList(),
              ),
            ],

            _sectionTitle(
              'Checklist d\'entretien (${type.checklist.length})',
            ),
            _card(
              type.checklist
                  .map(
                    (item) => _simpleRow(
                      '${item.rep}. ${item.label}',
                      trailing: _checklistTypeChip(item),
                    ),
                  )
                  .toList(),
            ),

            _sectionTitle(
              'Groupes de mesures (${type.groupesMesures.length})',
            ),
            ...type.groupesMesures.map(
              (groupe) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                groupe.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (groupe.repetable)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.indigo[50],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'répétable × ${groupe.nombreMax}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo[700],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: groupe.champs
                              .map(
                                (c) => Chip(
                                  label: Text(
                                    c.unite.isEmpty
                                        ? c.label
                                        : '${c.label} (${c.unite})',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor: Colors.grey[100],
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checklistTypeChip(ChecklistItem item) {
    String label;
    Color color;
    switch (item.typeValeur) {
      case TypeValeurChecklist.bool_:
        label = 'Effectué';
        color = Colors.green;
        break;
      case TypeValeurChecklist.enum_:
        label = item.options.join(' / ');
        color = Colors.orange;
        break;
      case TypeValeurChecklist.text:
        label = 'Texte';
        color = Colors.blueGrey;
        break;
    }
    return Text(
      label,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8, left: 2),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.teal,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: children),
      ),
    );
  }

  Widget _simpleRow(String label, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          ?trailing,
        ],
      ),
    );
  }
}
