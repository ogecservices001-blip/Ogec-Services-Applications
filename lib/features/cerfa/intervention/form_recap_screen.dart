import 'package:flutter/material.dart';
import '../models/cerfa_data_model.dart';
import 'form_signature_screen.dart';

class FormRecapScreen extends StatelessWidget {
  final CerfaData cerfaData;

  const FormRecapScreen({super.key, required this.cerfaData});

  Widget _buildSection(String titre, Map<String, String> champs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
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
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.blue.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: champs.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${entry.key} :',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            entry.value.isEmpty ? '—' : entry.value,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _boolText(bool value) => value ? '✅ Oui' : '❌ Non';

  @override
  Widget build(BuildContext context) {
    final d = cerfaData;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Écran 5a : Récapitulatif (aperçu)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Aperçu temporaire : le vrai PDF CERFA sera généré dans une prochaine étape.',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection('Informations générales', {
                      'Fiche N°': d.ficheNo.isEmpty
                          ? 'Sera attribué à la validation'
                          : d.ficheNo,
                      'Attestation N°': d.attestationNo,
                      'Opérateur': d.operateur,
                      'Détenteur': d.detenteur,
                      'Équipement': d.equipementId,
                      'Nom fichier': d.nomFichier.isEmpty
                          ? 'Sera attribué à la validation'
                          : d.nomFichier,
                      'Statut': d.statut,
                    }),
                    _buildSection('Fluide & Intervention', {
                      'Fluide': d.equipementFluide,
                      'Charge (kg)': d.equipementCharge,
                      'Tonnage éq. CO₂': d.equipementTeqCO2,
                      'Assemblage': _boolText(d.caseAssemblage),
                      'Mise en service': _boolText(d.caseMiseService),
                      'Modification': _boolText(d.caseModif),
                      'Maintenance': _boolText(d.caseMaintenance),
                      'Contrôle périodique': _boolText(d.caseCtrlPerio),
                      'Contrôle non périodique': _boolText(d.caseCtrlNonPerio),
                      'Démantèlement': _boolText(d.caseDemantel),
                      'Autre': d.caseAutre ? d.autreTexte : 'Non',
                    }),
                    _buildSection('Détection & Périodicité', {
                      'Détecteur': d.detecteurId,
                      'Date contrôle':
                          '${d.controleJour}/${d.controleMois}/${d.controleAnnee}',
                      'Système permanent': d.boutonOui == 'true'
                          ? '✅ Oui'
                          : '❌ Non',
                      'HCFC 2-30 kg': _boolText(d.caseHcfc2),
                      'HCFC 30-300 kg': _boolText(d.caseHcfc30),
                      'Périodicité 12 mois': _boolText(d.caseSans12m),
                      'Périodicité 6 mois': _boolText(d.caseSans6m),
                      'Fuites constatées': d.caseFuiteOui ? '✅ Oui' : '❌ Non',
                      if (d.caseFuiteOui) ...{
                        'Fuite 1': d.fuiteLoca1.isEmpty ? '—' : d.fuiteLoca1,
                        'Fuite 2': d.fuiteLoca2.isEmpty ? '—' : d.fuiteLoca2,
                        'Fuite 3': d.fuiteLoca3.isEmpty ? '—' : d.fuiteLoca3,
                      },
                    }),
                    _buildSection('Manipulation du fluide', {
                      'Quantité totale chargée (kg)': d.quantite,
                      'Dont vierge (kg)': d.qa,
                      'Dénomination si changement': d.denom,
                      'Dont recyclé (kg)': d.qb,
                      'Dont régénéré (kg)': d.qc,
                      'Quantité récupérée totale (kg)': d.qde,
                      'Dont destiné traitement (kg)': d.qd,
                      'N° BSFF': d.bsff,
                      'Dont conservé (kg)': d.qe,
                      'Identification contenant(s)': d.contenantId,
                      'UN 1078': _boolText(d.caseUN1078),
                      'UN 3161': _boolText(d.caseUN3161),
                      'Observations': d.observations,
                    }),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.red, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Retour',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                FormSignatureScreen(cerfaData: cerfaData),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Signature',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
