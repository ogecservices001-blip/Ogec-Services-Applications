import 'package:flutter/material.dart';
import '../gmao_database_service.dart';
import 'type_equipement_model.dart';
import 'type_equipement_detail_screen.dart';

class TypesEquipementListScreen extends StatefulWidget {
  const TypesEquipementListScreen({super.key});

  @override
  State<TypesEquipementListScreen> createState() =>
      _TypesEquipementListScreenState();
}

class _TypesEquipementListScreenState
    extends State<TypesEquipementListScreen> {
  final GmaoDatabaseService _db = GmaoDatabaseService();
  bool _semis = false;

  Future<void> _semer() async {
    setState(() => _semis = true);
    try {
      await _db.semerFamillesInitiales();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('MOD ROOF et MOD BRAS ajoutés au référentiel'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _semis = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Référentiel équipements (GMAO)'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<TypeEquipementModel>>(
        stream: _db.getTypesEquipement(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Erreur de chargement'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            );
          }

          final types = snapshot.data ?? [];

          if (types.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 60,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Référentiel vide pour le moment',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _semis ? null : _semer,
                    icon: const Icon(Icons.download),
                    label: Text(
                      _semis
                          ? 'Ajout en cours…'
                          : 'Ajouter MOD ROOF + MOD BRAS',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: types.length,
            itemBuilder: (context, index) {
              final type = types[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal[100],
                    child: const Icon(
                      Icons.precision_manufacturing_outlined,
                      color: Colors.teal,
                    ),
                  ),
                  title: Text(
                    type.nom,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${type.code} · ${type.checklist.length} opérations · '
                    '${type.groupesMesures.length} groupe(s) de mesures',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TypeEquipementDetailScreen(type: type),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
