import 'package:flutter/material.dart';
import '../../core/services/csv_import_service.dart';

class AdminToolsScreen extends StatelessWidget {
  const AdminToolsScreen({super.key});

  String _generateFileName(String type) {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year;
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');

    return "ogec_service_${type}_$day-$month-${year}_${hour}h$minute.csv";
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
                    subtitle: Text("Fichier : ${_generateFileName('clients')}"),
                    onTap: () {
                      final name = _generateFileName('clients');
                      debugPrint("Action : Exportation vers $name");
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.download,
                      color: Colors.orangeAccent,
                    ),
                    title: const Text("Exporter Fournisseurs"),
                    subtitle: Text(
                      "Fichier : ${_generateFileName('fournisseurs')}",
                    ),
                    onTap: () {
                      final name = _generateFileName('fournisseurs');
                      debugPrint("Action : Exportation vers $name");
                    },
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
