import 'package:flutter/material.dart';
import '../../../core/services/database_service.dart';
import 'supplier_model.dart';

class EditSupplierScreen extends StatefulWidget {
  final SupplierModel supplier;

  const EditSupplierScreen({super.key, required this.supplier});

  @override
  State<EditSupplierScreen> createState() => _EditSupplierScreenState();
}

class _EditSupplierScreenState extends State<EditSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();

  late TextEditingController _nomController;
  late TextEditingController _denominationController;
  late TextEditingController _interlocuteursController;
  late TextEditingController _telController;
  late TextEditingController _portableController;
  late TextEditingController _emailController;
  late TextEditingController _webController;
  late TextEditingController _communeController;
  late TextEditingController _cpController;
  late TextEditingController _adresseController;
  late TextEditingController _complementController;
  late TextEditingController _produitsController;
  late TextEditingController _remarquesController;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.supplier.nom);
    _denominationController = TextEditingController(
      text: widget.supplier.denominationCourte,
    );
    _interlocuteursController = TextEditingController(
      text: widget.supplier.interlocuteurs,
    );
    _telController = TextEditingController(text: widget.supplier.tel);
    _portableController = TextEditingController(text: widget.supplier.portable);
    _emailController = TextEditingController(text: widget.supplier.courriel);
    _webController = TextEditingController(text: widget.supplier.siteWeb);
    _communeController = TextEditingController(text: widget.supplier.commune);
    _cpController = TextEditingController(text: widget.supplier.codePostal);
    _adresseController = TextEditingController(text: widget.supplier.adresse);
    _complementController = TextEditingController(
      text: widget.supplier.complementAdresse,
    );
    _produitsController = TextEditingController(
      text: widget.supplier.produitsCles,
    );
    _remarquesController = TextEditingController(
      text: widget.supplier.remarques,
    );
  }

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

  Future<void> _updateSupplier() async {
    if (_formKey.currentState!.validate()) {
      final updatedSupplier = SupplierModel(
        id: widget.supplier.id,
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
        await _db.updateSupplier(updatedSupplier);
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Fournisseur mis à jour")));
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
        title: const Text("Modifier Fournisseur"),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildField(
              _nomController,
              "Nom de l'entreprise *",
              Icons.business,
              isRequired: true,
            ),
            _buildField(
              _denominationController,
              "Dénomination courte",
              Icons.tag,
            ),
            const Divider(height: 32),
            _buildField(_adresseController, "Adresse", Icons.location_on),
            _buildField(
              _complementController,
              "Complément d'adresse",
              Icons.add_location,
            ),
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
                    "Ville",
                    Icons.location_city,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _buildField(
              _telController,
              "Téléphone Fixe",
              Icons.phone,
              isPhone: true,
            ),
            _buildField(
              _portableController,
              "Portable",
              Icons.phone_android,
              isPhone: true,
            ),
            _buildField(
              _emailController,
              "Email de contact",
              Icons.email,
              isEmail: true,
            ),
            _buildField(_webController, "Site Web", Icons.language),
            const Divider(height: 32),
            _buildField(
              _interlocuteursController,
              "Interlocuteurs",
              Icons.people,
            ),
            _buildField(
              _produitsController,
              "Expertise & Produits clés",
              Icons.inventory_2,
              maxLines: 3,
            ),
            _buildField(
              _remarquesController,
              "Remarques",
              Icons.comment,
              maxLines: 2,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _updateSupplier,
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
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueGrey),
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
