import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'client_field_group.dart';
import 'client_model.dart';

/// Page listant les champs d'un [ClientFieldGroup] pour un client donné.
class ClientGroupDetailScreen extends StatelessWidget {
  final ClientFieldGroup group;
  final ClientModel client;

  const ClientGroupDetailScreen({
    super.key,
    required this.group,
    required this.client,
  });

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Impossible de lancer $url';
      }
    } catch (e) {
      debugPrint("Erreur de lien : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(group.title),
        backgroundColor: group.color,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: group.fields.map((field) {
          final value = field.getValue(client);
          final display = value.trim().isEmpty ? "Non renseigné" : value;

          VoidCallback? onTap;
          if (field.isPhone && value.trim().isNotEmpty) {
            onTap = () => _launchURL("tel:$value");
          } else if (field.isEmail && value.trim().isNotEmpty) {
            onTap = () => _launchURL("mailto:$value");
          }

          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              leading: Icon(field.icon, color: group.color),
              title: Text(
                field.label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              subtitle: Text(
                display,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: onTap != null
                  ? const Icon(Icons.open_in_new, size: 18, color: Colors.blue)
                  : null,
              onTap: onTap,
            ),
          );
        }).toList(),
      ),
    );
  }
}
