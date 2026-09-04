import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/user_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserService _userService = UserService();
  bool _migrationEnCours = false;

  Future<void> _migrer() async {
    setState(() => _migrationEnCours = true);
    try {
      final resultat = await _userService.migrerCollaborateursEtTechniciens();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(resultat)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _migrationEnCours = false);
    }
  }

  void _showUserForm({
    String? uid,
    Map<String, dynamic>? current,
  }) {
    final nameController = TextEditingController(text: current?['name']);
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final portableController = TextEditingController(
      text: current?['portable'],
    );
    final emailPersoController = TextEditingController(
      text: current?['emailPerso'],
    );
    final communeController = TextEditingController(
      text: current?['communeHabitation'],
    );
    final vehiculeController = TextEditingController(
      text: current?['vehicule'],
    );
    final qualiteController = TextEditingController(text: current?['qualite']);
    String selectedRole = current?['role'] ?? 'technicien';
    if (selectedRole == 'en_attente') selectedRole = 'technicien';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            uid == null ? "Ajouter un utilisateur" : "Modifier l'utilisateur",
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Nom complet"),
                ),
                const SizedBox(height: 10),
                if (uid == null) ...[
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: "Email (compte de connexion)",
                    ),
                  ),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: "Mot de passe",
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Laisser email et mot de passe vides pour créer une "
                    "fiche \"en attente\" (sans accès à l'appli).",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: portableController,
                  decoration: const InputDecoration(labelText: "Portable"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailPersoController,
                  decoration: const InputDecoration(
                    labelText: "Email personnel",
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: communeController,
                  decoration: const InputDecoration(
                    labelText: "Commune d'habitation",
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: vehiculeController,
                  decoration: const InputDecoration(
                    labelText: "Véhicule (immatriculation)",
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qualiteController,
                  decoration: const InputDecoration(
                    labelText: "Qualité (ex: Frigoriste)",
                  ),
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Rôle :",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                DropdownButton<String>(
                  value: selectedRole,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text("Administrateur"),
                    ),
                    DropdownMenuItem(
                      value: 'technicien',
                      child: Text("Technicien"),
                    ),
                  ],
                  onChanged: (val) => setDialogState(() => selectedRole = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                try {
                  if (uid == null) {
                    final email = emailController.text.trim();
                    final password = passwordController.text.trim();
                    if (email.isEmpty || password.isEmpty) {
                      await _userService.addUserSansCompte(
                        name: nameController.text.trim(),
                        portable: portableController.text.trim(),
                        emailPerso: emailPersoController.text.trim(),
                        communeHabitation: communeController.text.trim(),
                        vehicule: vehiculeController.text.trim(),
                        qualite: qualiteController.text.trim(),
                      );
                    } else {
                      await _userService.addUser(
                        email: email,
                        password: password,
                        role: selectedRole,
                        name: nameController.text.trim(),
                        portable: portableController.text.trim(),
                        emailPerso: emailPersoController.text.trim(),
                        communeHabitation: communeController.text.trim(),
                        vehicule: vehiculeController.text.trim(),
                        qualite: qualiteController.text.trim(),
                      );
                    }
                  } else {
                    await _userService.updateUser(uid, {
                      'role': selectedRole,
                      'name': nameController.text.trim(),
                      'portable': portableController.text.trim(),
                      'emailPerso': emailPersoController.text.trim(),
                      'communeHabitation': communeController.text.trim(),
                      'vehicule': vehiculeController.text.trim(),
                      'qualite': qualiteController.text.trim(),
                    });
                  }

                  if (!context.mounted) return;
                  navigator.pop();
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text("Erreur : $e")),
                  );
                }
              },
              child: const Text("Enregistrer"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion Utilisateurs"),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _migrationEnCours
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Migrer collaborateurs + techniciens vers Utilisateurs',
            onPressed: _migrationEnCours ? null : _migrer,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _userService.getUsers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data!.docs;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;
              final String userId = users[index].id;
              final role = user['role'] ?? 'technicien';
              final enAttente = role == 'en_attente';

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: enAttente ? Colors.grey[300] : null,
                    child: Icon(
                      enAttente ? Icons.person_outline : Icons.person,
                    ),
                  ),
                  title: Text(user['name'] ?? "Sans nom"),
                  subtitle: Text(
                    enAttente
                        ? "En attente de compte"
                        : "${user['email']} - $role"
                              "${(user['qualite'] ?? '').toString().isNotEmpty ? ' - ${user['qualite']}' : ''}",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () =>
                            _showUserForm(uid: userId, current: user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await _userService.deleteUser(userId);
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text("Utilisateur supprimé"),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.purple[700],
        onPressed: () => _showUserForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
