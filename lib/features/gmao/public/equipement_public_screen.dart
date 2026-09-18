import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Base des Cloud Functions callable v2 du projet (région us-central1,
/// valeur par défaut) — appelées ici en HTTP brut plutôt qu'avec le
/// package `cloud_functions` : ce dernier plante en web release
/// ("Unsupported operation: Int64 accessor not supported by dart2js"),
/// un bug de son interop JS indépendant des données renvoyées. Le
/// protocole Callable Functions n'est qu'un POST JSON classique
/// (`{"data": {...}}` → `{"result": ...}` ou `{"error": {...}}`), donc
/// on le reproduit directement avec `http`.
const _cloudFunctionsBase =
    'https://us-central1-ogec-services-app.cloudfunctions.net';

class _CallableException implements Exception {
  final String status;
  final String message;
  _CallableException(this.status, this.message);
}

Future<Map<String, dynamic>> _appelerFonction(
  String nom,
  Map<String, dynamic> data,
) async {
  final reponse = await http.post(
    Uri.parse('$_cloudFunctionsBase/$nom'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({'data': data}),
  );
  final corps = jsonDecode(reponse.body) as Map<String, dynamic>;
  if (corps.containsKey('error')) {
    final erreur = corps['error'] as Map<String, dynamic>;
    throw _CallableException(
      (erreur['status'] ?? '').toString(),
      (erreur['message'] ?? '').toString(),
    );
  }
  return Map<String, dynamic>.from(corps['result'] as Map);
}

/// Page publique d'un équipement, ouverte SANS connexion en scannant son
/// QR code (voir la détection de route dans `app.dart`). Aucun accès
/// Firestore direct ici : tout passe par les Cloud Functions
/// `verifierAccesEquipement`/`soumettreDemandeDepannage`, qui vérifient
/// côté serveur que l'email saisi est bien connu du site avant de
/// renvoyer quoi que ce soit.
class EquipementPublicScreen extends StatefulWidget {
  final String equipementId;

  const EquipementPublicScreen({super.key, required this.equipementId});

  @override
  State<EquipementPublicScreen> createState() =>
      _EquipementPublicScreenState();
}

class _EquipementPublicScreenState extends State<EquipementPublicScreen> {
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _chargement = false;
  String? _erreur;
  Map<String, dynamic>? _donnees;
  String? _emailValide;
  bool _envoiEnCours = false;
  bool _demandeEnvoyee = false;

  Future<void> _verifier() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _erreur = 'Merci de saisir un email valide.');
      return;
    }
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final result = await _appelerFonction('verifierAccesEquipement', {
        'equipementId': widget.equipementId,
        'email': email,
      });
      setState(() {
        _donnees = result;
        _emailValide = email;
        _chargement = false;
      });
    } on _CallableException catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.status == 'PERMISSION_DENIED'
            ? "Cet email n'est pas reconnu pour ce site. Vérifie qu'il "
                "correspond bien à l'adresse déjà connue d'OGEC Services "
                "pour ce contrat."
            : e.status == 'NOT_FOUND'
                ? 'Équipement introuvable.'
                : "Une erreur est survenue, réessaie dans un instant.";
      });
    } catch (_) {
      setState(() {
        _chargement = false;
        _erreur = "Une erreur est survenue, réessaie dans un instant.";
      });
    }
  }

  Future<void> _envoyerDemande() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      setState(() => _erreur = 'Merci de décrire la panne rencontrée.');
      return;
    }
    setState(() {
      _envoiEnCours = true;
      _erreur = null;
    });
    try {
      await _appelerFonction('soumettreDemandeDepannage', {
        'equipementId': widget.equipementId,
        'email': _emailValide,
        'message': message,
      });
      setState(() {
        _envoiEnCours = false;
        _demandeEnvoyee = true;
      });
    } catch (_) {
      setState(() {
        _envoiEnCours = false;
        _erreur = "L'envoi a échoué, réessaie dans un instant.";
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Équipement OGEC Services'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _donnees == null ? _formulaireEmail() : _contenuEquipement(),
          ),
        ),
      ),
    );
  }

  Widget _formulaireEmail() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.qr_code_2, size: 48, color: Colors.teal),
            const SizedBox(height: 12),
            const Text(
              'Consulter cet équipement',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Saisis l'email connu d'OGEC Services pour ce site afin "
              "d'accéder aux informations de cet équipement.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _verifier(),
            ),
            if (_erreur != null) ...[
              const SizedBox(height: 10),
              Text(_erreur!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _chargement ? null : _verifier,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _chargement
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenuEquipement() {
    final eq = Map<String, dynamic>.from(_donnees!['equipement'] as Map);
    final client = Map<String, dynamic>.from(_donnees!['client'] as Map);
    final type = _donnees!['type'] != null
        ? Map<String, dynamic>.from(_donnees!['type'] as Map)
        : null;
    final champsEnTete = Map<String, dynamic>.from(eq['champsEnTete'] ?? {});
    final champsSupp = (type?['champsEnTeteSupplementaires'] as List<dynamic>? ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.teal[50],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [client['nom'], client['site']]
                      .whereType<String>()
                      .where((s) => s.isNotEmpty)
                      .join(' — '),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if ((client['adresse'] ?? '').toString().isNotEmpty ||
                    (client['commune'] ?? '').toString().isNotEmpty)
                  Text(
                    [client['adresse'], client['commune']]
                        .whereType<String>()
                        .where((s) => s.isNotEmpty)
                        .join(', '),
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                const SizedBox(height: 10),
                Text(
                  (eq['nom'] ?? '').toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                if (type != null)
                  Text('${type['code']} — ${type['nom']}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                if ((eq['groupe'] ?? '').toString().isNotEmpty)
                  Text('Groupe : ${eq['groupe']}', style: const TextStyle(fontSize: 12)),
                if ((eq['numeroEquipement'] ?? '').toString().isNotEmpty ||
                    (eq['localisation'] ?? '').toString().isNotEmpty)
                  Text(
                    [eq['numeroEquipement'], eq['localisation']]
                        .whereType<String>()
                        .where((s) => s.isNotEmpty)
                        .join(' — '),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (final c in champsSupp)
                  if ((champsEnTete[c['cle']]?.toString() ?? '').isNotEmpty)
                    _ligneChamp(
                      (c['unite'] ?? '').toString().isEmpty
                          ? (c['label'] ?? '').toString()
                          : '${c['label']} (${c['unite']})',
                      champsEnTete[c['cle']].toString(),
                    ),
              ],
            ),
          ),
        ),
        if ((eq['remarqueTechnicien'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: Colors.amber.withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notes de suivi',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(eq['remarqueTechnicien'].toString(),
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (_demandeEnvoyee)
          Card(
            color: Colors.green[50],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ta demande de dépannage a bien été transmise à OGEC Services.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Signaler une panne',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _messageController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Décris la panne rencontrée',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_erreur != null) ...[
                    const SizedBox(height: 10),
                    Text(_erreur!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _envoiEnCours ? null : _envoyerDemande,
                    icon: _envoiEnCours
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.build_outlined),
                    label: const Text('Demander un dépannage'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _ligneChamp(String label, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
          Expanded(
            flex: 5,
            child: Text(valeur,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
