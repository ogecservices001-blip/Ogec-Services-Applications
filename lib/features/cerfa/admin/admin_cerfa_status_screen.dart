import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/auth/admin_google_session.dart';
import '../models/equipement_model.dart';
import '../services/sheets_service.dart';
import '../services/admin_mail_service.dart';

class AdminCerfaStatusScreen extends StatefulWidget {
  const AdminCerfaStatusScreen({super.key});

  @override
  State<AdminCerfaStatusScreen> createState() => _AdminCerfaStatusScreenState();
}

class _AdminCerfaStatusScreenState extends State<AdminCerfaStatusScreen> {
  final SheetsService _sheetsService = SheetsService();
  final AdminMailService _mailService = AdminMailService();

  bool _isLoading = true;
  bool _isSendingMail = false;
  List<Equipement> _enRetard = [];
  List<Equipement> _aJour = [];
  List<Equipement> _dansLeMois = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  DateTime? _parseDate(String value) {
    if (value.trim().isEmpty) return null;
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(value.trim());
    } catch (_) {
      return null;
    }
  }

  Future<void> _charger() async {
    setState(() => _isLoading = true);
    try {
      final equipements = await _sheetsService.getEquipements();
      final now = DateTime.now();
      final aujourdHui = DateTime(now.year, now.month, now.day);
      final dansUnMois = aujourdHui.add(const Duration(days: 30));

      final enRetard = <Equipement>[];
      final aJour = <Equipement>[];
      final dansLeMois = <Equipement>[];

      for (final e in equipements) {
        final date = _parseDate(e.dateProchainControle);
        if (date == null || date.isBefore(aujourdHui)) {
          enRetard.add(e);
        } else {
          aJour.add(e);
          if (!date.isAfter(dansUnMois)) {
            dansLeMois.add(e);
          }
        }
      }

      enRetard.sort(
        (a, b) => (_parseDate(a.dateProchainControle) ?? DateTime(1900))
            .compareTo(_parseDate(b.dateProchainControle) ?? DateTime(1900)),
      );
      dansLeMois.sort(
        (a, b) => _parseDate(
          a.dateProchainControle,
        )!.compareTo(_parseDate(b.dateProchainControle)!),
      );

      setState(() {
        _enRetard = enRetard;
        _aJour = aJour;
        _dansLeMois = dansLeMois;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de chargement : $e')));
      }
    }
  }

  String _construireCorpsRecap() {
    final buffer = StringBuffer();
    buffer.writeln('Point sur les CERFA — OGEC Services\n');
    buffer.writeln('À jour : ${_aJour.length}');
    buffer.writeln('En retard / à faire : ${_enRetard.length}');
    buffer.writeln('À faire dans le mois à venir : ${_dansLeMois.length}\n');

    if (_enRetard.isNotEmpty) {
      buffer.writeln('--- En retard / à faire ---');
      for (final e in _enRetard) {
        final date = e.dateProchainControle.isEmpty
            ? 'jamais contrôlé'
            : e.dateProchainControle;
        buffer.writeln('${e.client} / ${e.site} / ${e.nomEquipement} — $date');
      }
      buffer.writeln('');
    }

    if (_dansLeMois.isNotEmpty) {
      buffer.writeln('--- Dans le mois à venir ---');
      for (final e in _dansLeMois) {
        buffer.writeln(
          '${e.client} / ${e.site} / ${e.nomEquipement} — ${e.dateProchainControle}',
        );
      }
    }

    return buffer.toString();
  }

  Future<void> _envoyerRecap() async {
    final controller = TextEditingController(text: 'ogec.services@orange.fr');

    final destinataire = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Envoyer le récapitulatif'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Adresse destinataire',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    if (destinataire == null || destinataire.isEmpty) return;
    if (!mounted) return;

    setState(() => _isSendingMail = true);

    try {
      final account = await AdminGoogleSession.instance.ensureSignedIn(context);
      await _mailService.envoyerMail(
        compte: account,
        destinataire: destinataire,
        objet:
            'Point sur les CERFA — ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
        corps: _construireCorpsRecap(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Récapitulatif envoyé.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec de l\'envoi : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingMail = false);
    }
  }

  Widget _buildCompteur(String titre, int valeur, Color couleur) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: couleur.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text(
              '$valeur',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: couleur,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              titre,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListe(String titre, List<Equipement> equipements) {
    if (equipements.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          ...equipements.map((e) {
            final date = e.dateProchainControle.isEmpty
                ? 'Jamais contrôlé'
                : e.dateProchainControle;
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                title: Text(
                  '${e.client} — ${e.site}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(e.nomEquipement),
                trailing: Text(date),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Point sur les CERFA',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isSendingMail
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.mail_outline),
            onPressed: _isSendingMail ? null : _envoyerRecap,
            tooltip: 'Envoyer le récapitulatif par mail',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _charger,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildCompteur('À jour', _aJour.length, Colors.green),
                          _buildCompteur(
                            'En retard / à faire',
                            _enRetard.length,
                            Colors.red,
                          ),
                          _buildCompteur(
                            'Dans le mois',
                            _dansLeMois.length,
                            Colors.orange,
                          ),
                        ],
                      ),
                      _buildListe('En retard / à faire', _enRetard),
                      _buildListe('Dans le mois à venir', _dansLeMois),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
