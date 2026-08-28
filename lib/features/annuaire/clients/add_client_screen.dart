import 'package:flutter/material.dart';
import '../../../core/services/database_service.dart';
import 'client_model.dart';

class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();

  final _nomController = TextEditingController();
  final _siteController = TextEditingController();
  final _affaireController = TextEditingController();
  final _cpController = TextEditingController();
  final _communeController = TextEditingController();
  final _adresseController = TextEditingController();
  final _complementController = TextEditingController();
  final _responsableController = TextEditingController();
  final _telFixeController = TextEditingController();
  final _portableController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _nomController.dispose();
    _siteController.dispose();
    _affaireController.dispose();
    _cpController.dispose();
    _communeController.dispose();
    _adresseController.dispose();
    _complementController.dispose();
    _responsableController.dispose();
    _telFixeController.dispose();
    _portableController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveClient() async {
    if (_formKey.currentState!.validate()) {
      final newClient = ClientModel(
        id: '',
        nom: _nomController.text.trim(),
        site: _siteController.text.trim(),
        nAffaire: _affaireController.text.trim(),
        codePostal: _cpController.text.trim(),
        commune: _communeController.text.trim(),
        adresse: _adresseController.text.trim(),
        complementAdresse: _complementController.text.trim(),
        responsableContrat: _responsableController.text.trim(),
        telFixeResponsable: _telFixeController.text.trim(),
        portableResponsable: _portableController.text.trim(),
        courrielResponsable: _emailController.text.trim(),
      );

      try {
        await _db.addClient(newClient);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Site client créé avec succès")),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Erreur : $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nouveau Site Client"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _siteController,
              decoration: const InputDecoration(
                labelText: "Nom du Site (ex: Lycée...)*",
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? "Le nom du site est requis" : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _nomController,
              decoration: const InputDecoration(
                labelText: "Entité / Nom (Entreprise)*",
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v!.isEmpty ? "Le nom de l'entité est requis" : null,
            ),
            const Divider(height: 32),
            TextFormField(
              controller: _affaireController,
              decoration: const InputDecoration(
                labelText: "N° d'Affaire",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _adresseController,
              decoration: const InputDecoration(
                labelText: "Adresse",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _complementController,
              decoration: const InputDecoration(
                labelText: "Complément d'adresse (Bâtiment, étage...)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Code Postal",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _communeController,
                    decoration: const InputDecoration(
                      labelText: "Ville",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            TextFormField(
              controller: _responsableController,
              decoration: const InputDecoration(
                labelText: "Nom du Responsable Contrat",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _telFixeController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Téléphone Fixe",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
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
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email Responsable",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _saveClient,
              child: const Text(
                "ENREGISTRER LE CLIENT",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
