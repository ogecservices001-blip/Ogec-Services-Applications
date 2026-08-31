import 'package:flutter/material.dart';
import '../../../core/services/database_service.dart';
import 'collaborateur_model.dart';

class AddCollaborateurScreen extends StatefulWidget {
  const AddCollaborateurScreen({super.key});

  @override
  State<AddCollaborateurScreen> createState() =>
      _AddCollaborateurScreenState();
}

class _AddCollaborateurScreenState extends State<AddCollaborateurScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();

  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _portableController = TextEditingController();
  final _emailOgecController = TextEditingController();
  final _emailPersoController = TextEditingController();
  final _communeController = TextEditingController();
  final _vehiculeController = TextEditingController();

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _portableController.dispose();
    _emailOgecController.dispose();
    _emailPersoController.dispose();
    _communeController.dispose();
    _vehiculeController.dispose();
    super.dispose();
  }

  Future<void> _saveCollaborateur() async {
    if (_formKey.currentState!.validate()) {
      final newCollaborateur = CollaborateurModel(
        id: '',
        nom: _nomController.text.trim(),
        prenom: _prenomController.text.trim(),
        portable: _portableController.text.trim(),
        emailOgec: _emailOgecController.text.trim(),
        emailPerso: _emailPersoController.text.trim(),
        communeHabitation: _communeController.text.trim(),
        vehicule: _vehiculeController.text.trim(),
      );

      try {
        await _db.addCollaborateur(newCollaborateur);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Collaborateur ajouté avec succès")),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur lors de l'ajout : $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nouveau Collaborateur"),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nomController,
              decoration: const InputDecoration(
                labelText: "Nom *",
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? "Le nom est obligatoire" : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _prenomController,
              decoration: const InputDecoration(
                labelText: "Prénom",
                border: OutlineInputBorder(),
              ),
            ),
            const Divider(height: 32),
            TextFormField(
              controller: _portableController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Portable",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _emailOgecController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email OGEC Services",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _emailPersoController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email personnel",
                border: OutlineInputBorder(),
              ),
            ),
            const Divider(height: 32),
            TextFormField(
              controller: _communeController,
              decoration: const InputDecoration(
                labelText: "Commune d'habitation",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _vehiculeController,
              decoration: const InputDecoration(
                labelText: "Véhicule (immatriculation)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _saveCollaborateur,
                child: const Text(
                  "ENREGISTRER LE COLLABORATEUR",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
