import 'package:flutter/material.dart';
import '../../../core/services/database_service.dart';
import 'collaborateur_model.dart';

class EditCollaborateurScreen extends StatefulWidget {
  final CollaborateurModel collaborateur;

  const EditCollaborateurScreen({super.key, required this.collaborateur});

  @override
  State<EditCollaborateurScreen> createState() =>
      _EditCollaborateurScreenState();
}

class _EditCollaborateurScreenState extends State<EditCollaborateurScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();

  late TextEditingController _nomController;
  late TextEditingController _prenomController;
  late TextEditingController _portableController;
  late TextEditingController _emailOgecController;
  late TextEditingController _emailPersoController;
  late TextEditingController _communeController;
  late TextEditingController _vehiculeController;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.collaborateur.nom);
    _prenomController = TextEditingController(
      text: widget.collaborateur.prenom,
    );
    _portableController = TextEditingController(
      text: widget.collaborateur.portable,
    );
    _emailOgecController = TextEditingController(
      text: widget.collaborateur.emailOgec,
    );
    _emailPersoController = TextEditingController(
      text: widget.collaborateur.emailPerso,
    );
    _communeController = TextEditingController(
      text: widget.collaborateur.communeHabitation,
    );
    _vehiculeController = TextEditingController(
      text: widget.collaborateur.vehicule,
    );
  }

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

  Future<void> _updateCollaborateur() async {
    if (_formKey.currentState!.validate()) {
      final updatedCollaborateur = CollaborateurModel(
        id: widget.collaborateur.id,
        nom: _nomController.text.trim(),
        prenom: _prenomController.text.trim(),
        portable: _portableController.text.trim(),
        emailOgec: _emailOgecController.text.trim(),
        emailPerso: _emailPersoController.text.trim(),
        communeHabitation: _communeController.text.trim(),
        vehicule: _vehiculeController.text.trim(),
      );

      try {
        await _db.updateCollaborateur(updatedCollaborateur);
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Collaborateur mis à jour")));
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erreur : $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Modifier Collaborateur"),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildField(
              _nomController,
              "Nom *",
              Icons.person,
              isRequired: true,
            ),
            _buildField(_prenomController, "Prénom", Icons.badge),
            const Divider(height: 32),
            _buildField(
              _portableController,
              "Portable",
              Icons.phone_android,
              isPhone: true,
            ),
            _buildField(
              _emailOgecController,
              "Email OGEC Services",
              Icons.email,
              isEmail: true,
            ),
            _buildField(
              _emailPersoController,
              "Email personnel",
              Icons.alternate_email,
              isEmail: true,
            ),
            const Divider(height: 32),
            _buildField(
              _communeController,
              "Commune d'habitation",
              Icons.location_on,
            ),
            _buildField(
              _vehiculeController,
              "Véhicule (immatriculation)",
              Icons.directions_car,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _updateCollaborateur,
              child: const Text(
                "ENREGISTRER LES MODIFICATIONS",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isRequired = false,
    bool isPhone = false,
    bool isEmail = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.indigo),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        keyboardType: isPhone
            ? TextInputType.phone
            : (isEmail ? TextInputType.emailAddress : TextInputType.text),
        validator: isRequired
            ? (v) => v!.isEmpty ? "Champ obligatoire" : null
            : null,
      ),
    );
  }
}
