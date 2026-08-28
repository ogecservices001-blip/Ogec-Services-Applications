import 'package:flutter/material.dart';
import '../../../core/services/database_service.dart';
import 'supplier_model.dart';

class AddSupplierScreen extends StatefulWidget {
  const AddSupplierScreen({super.key});

  @override
  State<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends State<AddSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();

  final _nomController = TextEditingController();
  final _denominationController = TextEditingController();
  final _interlocuteursController = TextEditingController();
  final _telController = TextEditingController();
  final _portableController = TextEditingController();
  final _emailController = TextEditingController();
  final _webController = TextEditingController();
  final _communeController = TextEditingController();
  final _cpController = TextEditingController();
  final _adresseController = TextEditingController();
  final _complementController = TextEditingController();
  final _produitsController = TextEditingController();
  final _remarquesController = TextEditingController();

  @override
  void dispose() {
    _nomController.dispose();
    _denominationController.dispose();
    _interlocuteursController.dispose();
    _telController.dispose();
    _portableController.dispose();
    _emailController.dispose();
    _webController.dispose();
    _communeController.dispose();
    _cpController.dispose();
    _adresseController.dispose();
    _complementController.dispose();
    _produitsController.dispose();
    _remarquesController.dispose();
    super.dispose();
  }

  Future<void> _saveSupplier() async {
    if (_formKey.currentState!.validate()) {
      final newSupplier = SupplierModel(
        id: '',
        nom: _nomController.text.trim(),
        denominationCourte: _denominationController.text.trim(),
        interlocuteurs: _interlocuteursController.text.trim(),
        tel: _telController.text.trim(),
        portable: _portableController.text.trim(),
        courriel: _emailController.text.trim(),
        siteWeb: _webController.text.trim(),
        commune: _communeController.text.trim(),
        codePostal: _cpController.text.trim(),
        adresse: _adresseController.text.trim(),
        complementAdresse: _complementController.text.trim(),
        produitsCles: _produitsController.text.trim(),
        remarques: _remarquesController.text.trim(),
      );

      try {
        await _db.addSupplier(newSupplier);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Fournisseur ajouté avec succès")),
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
        title: const Text("Nouveau Fournisseur"),
        backgroundColor: Colors.blueGrey[800],
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
                labelText: "Nom de l'entreprise *",
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? "Le nom est obligatoire" : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _denominationController,
              decoration: const InputDecoration(
                labelText: "Dénomination courte",
                border: OutlineInputBorder(),
              ),
            ),
            const Divider(height: 32),
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
                labelText: "Complément d'adresse",
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
              controller: _interlocuteursController,
              decoration: const InputDecoration(
                labelText: "Interlocuteurs",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _telController,
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
                labelText: "Email de contact",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _webController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: "Site Web",
                border: OutlineInputBorder(),
              ),
            ),
            const Divider(height: 32),
            TextFormField(
              controller: _produitsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Expertise & Produits clés",
                border: OutlineInputBorder(),
                hintText: "Décrivez les services proposés...",
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _remarquesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "Remarques",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _saveSupplier,
                child: const Text(
                  "ENREGISTRER LE FOURNISSEUR",
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
