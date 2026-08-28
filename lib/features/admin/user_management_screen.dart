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

  void _showUserForm({String? uid, String? currentName, String? currentRole}) {
    final nameController = TextEditingController(text: currentName);
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = currentRole ?? 'technicien';

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
                    decoration: const InputDecoration(labelText: "Email"),
                  ),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: "Mot de passe",
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 10),
                ],
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
                    await _userService.addUser(
                      email: emailController.text.trim(),
                      password: passwordController.text.trim(),
                      role: selectedRole,
                      name: nameController.text.trim(),
                    );
                  } else {
                    await _userService.updateUser(uid, {
                      'role': selectedRole,
                      'name': nameController.text.trim(),
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

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(user['name'] ?? "Sans nom"),
                  subtitle: Text("${user['email']} - ${user['role']}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _showUserForm(
                          uid: userId,
                          currentName: user['name'],
                          currentRole: user['role'],
                        ),
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
