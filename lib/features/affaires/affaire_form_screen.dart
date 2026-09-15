import 'package:flutter/material.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../annuaire/clients/client_model.dart';
import 'data/affaire_constants.dart';
import 'data/affaire_model.dart';
import 'data/affaire_service.dart';
import 'travaux_clients_screen.dart' show travauxAccent;

/// Création/modification d'une affaire (travaux sur devis) pour un
/// client/site donné. La nature (Remplacement/Réparation/Installation)
/// reste optionnelle ici — elle se précise souvent seulement sur le
/// terrain, via le Bon d'intervention Petits travaux qui s'y rattache.
class AffaireFormScreen extends StatefulWidget {
  final ClientModel client;
  final AffaireModel? affaire;
  const AffaireFormScreen({super.key, required this.client, this.affaire});

  @override
  State<AffaireFormScreen> createState() => _AffaireFormScreenState();
}

class _AffaireFormScreenState extends State<AffaireFormScreen> {
  final AffaireService _service = AffaireService();
  late final _numeroDevisController = TextEditingController(text: widget.affaire?.numeroDevis ?? '');
  late final _designationController = TextEditingController(
    text: widget.affaire?.designationPrestations ?? '',
  );
  late final _emailController = TextEditingController(
    text: widget.affaire?.emailResponsableContrat ?? widget.client.courrielResponsable,
  );
  late final _numeroCommandeController = TextEditingController(
    text: widget.affaire?.numeroCommandeClient ?? '',
  );
  late String _dateCommandeClient = widget.affaire?.dateCommandeClient ?? '';
  late String _nature = widget.affaire?.nature ?? '';
  bool _enregistrementEnCours = false;

  bool get _modification => widget.affaire != null;

  @override
  void dispose() {
    _numeroDevisController.dispose();
    _designationController.dispose();
    _emailController.dispose();
    _numeroCommandeController.dispose();
    super.dispose();
  }

  Future<void> _choisirDateCommande() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        _dateCommandeClient =
            '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      });
    }
  }

  Future<void> _enregistrer() async {
    setState(() => _enregistrementEnCours = true);
    try {
      final affaire = AffaireModel(
        id: widget.affaire?.id ?? '',
        clientId: widget.client.id,
        clientNom: widget.client.nom,
        site: widget.client.site,
        numeroDevis: _numeroDevisController.text.trim(),
        designationPrestations: _designationController.text.trim(),
        emailResponsableContrat: _emailController.text.trim(),
        dateCommandeClient: _dateCommandeClient,
        numeroCommandeClient: _numeroCommandeController.text.trim(),
        nature: _nature,
        createdAt: widget.affaire?.createdAt ?? 0,
      );
      await _service.saveAffaire(affaire);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_modification ? 'Affaire mise à jour' : 'Affaire créée')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _enregistrementEnCours = false);
    }
  }

  Future<void> _supprimer() async {
    final confirme = await confirmerSuppression(
      context: context,
      titre: 'Supprimer cette affaire',
      message: 'Supprime l\'affaire "${_numeroDevisController.text}" — action irréversible.',
    );
    if (!confirme || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await _service.deleteAffaire(widget.affaire!.id);
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Affaire supprimée')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(_modification ? 'Modifier l\'affaire' : 'Nouvelle affaire'),
        backgroundColor: travauxAccent,
        foregroundColor: Colors.white,
        actions: [
          if (_modification)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _supprimer,
              tooltip: 'Supprimer',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [widget.client.nom, widget.client.site].where((s) => s.isNotEmpty).join(' — '),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _numeroDevisController,
              decoration: const InputDecoration(
                labelText: 'Numéro de devis',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _designationController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Désignation des prestations',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email responsable contrat',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _choisirDateCommande,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date de commande client',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: Text(_dateCommandeClient.isEmpty ? '—' : _dateCommandeClient),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _numeroCommandeController,
              decoration: const InputDecoration(
                labelText: 'Référence commande client',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _nature.isEmpty ? null : _nature,
              decoration: const InputDecoration(
                labelText: 'Nature (si déjà connue)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: NatureAffaire.all.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _nature = v ?? ''),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _enregistrementEnCours ? null : _enregistrer,
                style: ElevatedButton.styleFrom(backgroundColor: travauxAccent, foregroundColor: Colors.white),
                child: _enregistrementEnCours
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
