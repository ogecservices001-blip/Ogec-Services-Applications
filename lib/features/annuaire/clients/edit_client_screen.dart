import 'package:flutter/material.dart';
import '../../../core/services/database_service.dart';
import 'client_model.dart';

class EditClientScreen extends StatefulWidget {
  final ClientModel client;

  const EditClientScreen({super.key, required this.client});

  @override
  State<EditClientScreen> createState() => _EditClientScreenState();
}

class _EditClientScreenState extends State<EditClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();

  late TextEditingController _nomController;
  late TextEditingController _siteController;
  late TextEditingController _affaireController;
  late TextEditingController _cpController;
  late TextEditingController _communeController;
  late TextEditingController _adresseController;
  late TextEditingController _complementController;
  late TextEditingController _responsableController;
  late TextEditingController _telFixeController;
  late TextEditingController _portableController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.client.nom);
    _siteController = TextEditingController(text: widget.client.site);
    _affaireController = TextEditingController(text: widget.client.nAffaire);
    _cpController = TextEditingController(text: widget.client.codePostal);
    _communeController = TextEditingController(text: widget.client.commune);
    _adresseController = TextEditingController(text: widget.client.adresse);
    _complementController = TextEditingController(
      text: widget.client.complementAdresse,
    );
    _responsableController = TextEditingController(
      text: widget.client.responsableContrat,
    );
    _telFixeController = TextEditingController(
      text: widget.client.telFixeResponsable,
    );
    _portableController = TextEditingController(
      text: widget.client.portableResponsable,
    );
    _emailController = TextEditingController(
      text: widget.client.courrielResponsable,
    );
  }

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

  Future<void> _updateClient() async {
    if (_formKey.currentState!.validate()) {
      final updatedClient = ClientModel(
        id: widget.client.id,
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
        await _db.updateClient(updatedClient);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fiche client mise à jour")),
        );
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la mise à jour : $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Modifier la Fiche Client"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildField(
              _nomController,
              "Clients (Entreprise) *",
              Icons.business,
              isRequired: true,
            ),
            _buildField(
              _siteController,
              "Sites (Nom du bâtiment) *",
              Icons.apartment,
              isRequired: true,
            ),
            _buildField(_affaireController, "N°Affaire", Icons.tag),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    _cpController,
                    "Code Postal",
                    Icons.mark_as_unread,
                    isNumeric: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildField(
                    _communeController,
                    "Commune",
                    Icons.location_city,
                  ),
                ),
              ],
            ),
            _buildField(_adresseController, "Adresse", Icons.location_on),
            _buildField(
              _complementController,
              "Complément d'adresse",
              Icons.add_location,
            ),
            const Divider(height: 32),
            _buildField(
              _responsableController,
              "Responsable contrat",
              Icons.person,
            ),
            _buildField(
              _telFixeController,
              "Tel Fixe responsable",
              Icons.phone,
              isPhone: true,
            ),
            _buildField(
              _portableController,
              "Portable responsable",
              Icons.phone_android,
              isPhone: true,
            ),
            _buildField(
              _emailController,
              "Courriel responsable",
              Icons.email,
              isEmail: true,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _updateClient,
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
    bool isNumeric = false,
    bool isPhone = false,
    bool isEmail = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.green),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        keyboardType: isNumeric
            ? TextInputType.number
            : (isPhone
                  ? TextInputType.phone
                  : (isEmail
                        ? TextInputType.emailAddress
                        : TextInputType.text)),
        validator: isRequired
            ? (v) => v!.isEmpty ? "Champ obligatoire" : null
            : null,
      ),
    );
  }
}
