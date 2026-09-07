import 'package:flutter/material.dart';
import '../../core/services/csv_import_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/repertoire_export_service.dart';
import '../../core/widgets/confirm_delete_dialog.dart';

class AdminToolsScreen extends StatefulWidget {
  const AdminToolsScreen({super.key});

  @override
  State<AdminToolsScreen> createState() => _AdminToolsScreenState();
}

class _AdminToolsScreenState extends State<AdminToolsScreen> {
  final DatabaseService _db = DatabaseService();
  final RepertoireExportService _exportService = RepertoireExportService();

  String _generateFileName(String type) {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year;
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');

    return "ogec_service_${type}_$day-$month-${year}_${hour}h$minute";
  }

  Future<void> _handleImport(
    BuildContext context,
    Future<void> Function() importFunction,
    String label,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Importation des $label en cours..."),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      await importFunction();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Importation des $label terminée !"),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l'import : $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exporterClients() async {
    final clients = await _db.getClients().first;
    _exportService.exporterClients(
      clients,
      '${_generateFileName('clients')}.xlsx',
    );
  }

  Future<void> _exporterFournisseurs() async {
    final suppliers = await _db.getSuppliers().first;
    _exportService.exporterFournisseurs(
      suppliers,
      '${_generateFileName('fournisseurs')}.csv',
    );
  }

  Future<void> _supprimerTousLesClients() async {
    final confirme = await confirmerSuppressionMasse(
      context: context,
      titre: 'Supprimer tous les clients',
      message:
          'Supprime toutes les fiches Répertoire (tous clients, tous '
          "sites) — action irréversible. N'affecte pas les équipements "
          'GMAO déjà enregistrés.',
      motConfirmation: 'SUPPRIMER TOUT',
    );
    if (!confirme || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final clients = await _db.getClients().first;
    await _db.deleteClients(clients.map((c) => c.id).toList());
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('${clients.length} client(s) supprimé(s)')),
    );
  }

  Future<void> _supprimerTousLesFournisseurs() async {
    final confirme = await confirmerSuppressionMasse(
      context: context,
      titre: 'Supprimer tous les fournisseurs',
      message: 'Supprime tous les fournisseurs — action irréversible.',
      motConfirmation: 'SUPPRIMER TOUT',
    );
    if (!confirme || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final suppliers = await _db.getSuppliers().first;
    await _db.deleteSuppliers(suppliers.map((s) => s.id).toList());
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('${suppliers.length} fournisseur(s) supprimé(s)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CsvImportService csvService = CsvImportService();

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Outils de Données'),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Importation",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.upload_file, color: Colors.blue),
                    title: const Text("Importer Clients"),
                    subtitle: const Text(
                      "Charger le fichier Excel (.xlsx/.xlsm) — feuille SITES",
                    ),
                    onTap: () => _handleImport(
                      context,
                      csvService.importClients,
                      "clients",
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.upload_file,
                      color: Colors.blueGrey,
                    ),
                    title: const Text("Importer Fournisseurs"),
                    subtitle: const Text("Charger un fichier .csv"),
                    onTap: () => _handleImport(
                      context,
                      csvService.importSuppliers,
                      "fournisseurs",
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Exportation (Sauvegarde)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.download, color: Colors.orange),
                    title: const Text("Exporter Clients"),
                    subtitle: Text(
                      "Fichier : ${_generateFileName('clients')}.xlsx",
                    ),
                    onTap: _exporterClients,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.download,
                      color: Colors.orangeAccent,
                    ),
                    title: const Text("Exporter Fournisseurs"),
                    subtitle: Text(
                      "Fichier : ${_generateFileName('fournisseurs')}.csv",
                    ),
                    onTap: _exporterFournisseurs,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Suppression",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text("Supprimer tous les clients"),
                    subtitle: const Text("Action irréversible"),
                    onTap: _supprimerTousLesClients,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text("Supprimer tous les fournisseurs"),
                    subtitle: const Text("Action irréversible"),
                    onTap: _supprimerTousLesFournisseurs,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
