import 'package:flutter/material.dart';
import '../../../core/services/user_service.dart';
import 'bi_wizard_screen.dart' show biAccent;

/// Sélection des techniciens intervenus — même esthétique que les
/// autres listes de l'app (en-tête coloré, barre de recherche, liste),
/// mais multi-sélection (coche) puisqu'un bon peut avoir plusieurs
/// techniciens. Noms tirés en direct des comptes utilisateurs.
class BiTechnicienPickerScreen extends StatefulWidget {
  final List<String> selectionInitiale;
  const BiTechnicienPickerScreen({super.key, required this.selectionInitiale});

  @override
  State<BiTechnicienPickerScreen> createState() => _BiTechnicienPickerScreenState();
}

class _BiTechnicienPickerScreenState extends State<BiTechnicienPickerScreen> {
  final UserService _userService = UserService();
  String _recherche = '';
  late final List<String> _selection = List.from(widget.selectionInitiale);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Techniciens intervenus'),
        backgroundColor: biAccent,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _recherche = v.toLowerCase().trim()),
              decoration: InputDecoration(
                hintText: 'Rechercher un technicien...',
                prefixIcon: Icon(Icons.search, color: biAccent),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<String>>(
        stream: _userService.getTechnicienNames(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final noms = snapshot.data!.where((n) => n.toLowerCase().contains(_recherche)).toList();
          if (noms.isEmpty) {
            return Center(
              child: Text(
                _recherche.isEmpty ? 'Aucun technicien' : "Aucun résultat pour '$_recherche'",
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: noms.length,
            itemBuilder: (context, index) {
              final nom = noms[index];
              final coche = _selection.contains(nom);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: CheckboxListTile(
                  value: coche,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selection.add(nom);
                    } else {
                      _selection.remove(nom);
                    }
                  }),
                  activeColor: biAccent,
                  controlAffinity: ListTileControlAffinity.leading,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text(nom, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context, _selection),
        backgroundColor: biAccent,
        icon: const Icon(Icons.check),
        label: Text('Valider (${_selection.length})'),
      ),
    );
  }
}
