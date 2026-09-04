import 'package:flutter/material.dart';
import 'client_model.dart';

/// Un champ affichable de la fiche client : libellé, icône, valeur
/// extraite du modèle, et indication si la valeur est un téléphone/email
/// cliquable.
class ClientField {
  final String label;
  final IconData icon;
  final String Function(ClientModel client) getValue;
  final bool isPhone;
  final bool isEmail;

  const ClientField({
    required this.label,
    required this.icon,
    required this.getValue,
    this.isPhone = false,
    this.isEmail = false,
  });
}

/// Un groupe thématique de champs, affiché comme une carte de sous-menu
/// sur la fiche client. [adminOnly] restreint le groupe aux administrateurs
/// (données contractuelles/financières) ; les autres groupes sont visibles
/// par les techniciens aussi.
class ClientFieldGroup {
  final String title;
  final IconData icon;
  final Color color;
  final bool adminOnly;
  final List<ClientField> fields;

  const ClientFieldGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.fields,
    this.adminOnly = false,
  });
}

/// Regroupement des ~64 champs de la fiche client selon "Ordre
/// affichage.xlsx" (feuille 1) : ordre d'affichage au sein de chaque
/// groupe, et visibilité Admin/Technicien par groupe.
final List<ClientFieldGroup> clientFieldGroups = [
  ClientFieldGroup(
    title: "Identité & Site",
    icon: Icons.business,
    color: Colors.green,
    fields: [
      ClientField(label: "Client", icon: Icons.business, getValue: (c) => c.nom),
      ClientField(label: "Site", icon: Icons.store, getValue: (c) => c.site),
      ClientField(label: "N°Affaire", icon: Icons.tag, getValue: (c) => c.nAffaire),
      ClientField(
        label: "Code Postal",
        icon: Icons.mark_as_unread,
        getValue: (c) => c.codePostal,
      ),
      ClientField(
        label: "Commune",
        icon: Icons.location_city,
        getValue: (c) => c.commune,
      ),
      ClientField(
        label: "Adresse",
        icon: Icons.location_on,
        getValue: (c) => c.adresse,
      ),
      ClientField(
        label: "Complément d'adresse",
        icon: Icons.add_location,
        getValue: (c) => c.complementAdresse,
      ),
    ],
  ),
  ClientFieldGroup(
    title: "Accès & Sécurité",
    icon: Icons.security,
    color: Colors.blue,
    fields: [
      ClientField(
        label: "EPI spécifique",
        icon: Icons.shield_outlined,
        getValue: (c) => c.epiSpecifique,
      ),
      ClientField(
        label: "Habilitation spécifique",
        icon: Icons.verified_user_outlined,
        getValue: (c) => c.habilitationSpecifique,
      ),
      ClientField(
        label: "Moyen d'accès",
        icon: Icons.key,
        getValue: (c) => c.moyenAcces,
      ),
      ClientField(
        label: "Jour d'accès",
        icon: Icons.calendar_today,
        getValue: (c) => c.jourAcces,
      ),
      ClientField(
        label: "Heures d'accès",
        icon: Icons.access_time,
        getValue: (c) => c.heuresAcces,
      ),
      ClientField(
        label: "Délai d'intervention",
        icon: Icons.timer_outlined,
        getValue: (c) => c.delaiIntervention,
      ),
    ],
  ),
  ClientFieldGroup(
    title: "Contacts & Suivi",
    icon: Icons.contacts,
    color: Colors.teal,
    fields: [
      ClientField(
        label: "Interlocuteur site",
        icon: Icons.person,
        getValue: (c) => c.interlocuteurSite,
      ),
      ClientField(
        label: "Tel Fixe interlocuteur site",
        icon: Icons.phone,
        getValue: (c) => c.telFixeInterlocuteurSite,
        isPhone: true,
      ),
      ClientField(
        label: "Portable interlocuteur site",
        icon: Icons.phone_android,
        getValue: (c) => c.portableInterlocuteurSite,
        isPhone: true,
      ),
      ClientField(
        label: "Courriel interlocuteur site",
        icon: Icons.email,
        getValue: (c) => c.courrielInterlocuteurSite,
        isEmail: true,
      ),
      ClientField(
        label: "Fréq. entretien / an",
        icon: Icons.event_repeat,
        getValue: (c) => c.freqEntretienAn,
      ),
      ClientField(
        label: "Interlocuteur Tiers",
        icon: Icons.person_outline,
        getValue: (c) => c.interlocuteurTiers,
      ),
      ClientField(
        label: "Tel Fixe Tiers",
        icon: Icons.phone,
        getValue: (c) => c.telFixeTiers,
        isPhone: true,
      ),
      ClientField(
        label: "Portable Tiers",
        icon: Icons.phone_android,
        getValue: (c) => c.portableTiers,
        isPhone: true,
      ),
      ClientField(
        label: "Courriel Tiers",
        icon: Icons.email,
        getValue: (c) => c.courrielTiers,
        isEmail: true,
      ),
      ClientField(
        label: "Remarques libres",
        icon: Icons.comment,
        getValue: (c) => c.remarquesLibres,
      ),
    ],
  ),
  ClientFieldGroup(
    title: "Heures & Tarifs",
    icon: Icons.schedule,
    color: Colors.purple,
    adminOnly: true,
    fields: [
      ClientField(
        label: "Nb Heures vendues",
        icon: Icons.timer,
        getValue: (c) => c.nbHeuresVendues,
      ),
      ClientField(
        label: "Nb Heures vendues assistant",
        icon: Icons.timer,
        getValue: (c) => c.nbHeuresVenduesAssistant,
      ),
      ClientField(
        label: "Qté heures programmées",
        icon: Icons.event_available,
        getValue: (c) => c.qteHeuresProgrammees,
      ),
      ClientField(
        label: "Qté heures restantes",
        icon: Icons.event_busy,
        getValue: (c) => c.qteHeuresRestantes,
      ),
      ClientField(
        label: "Taux horaire régie",
        icon: Icons.euro,
        getValue: (c) => c.tauxHoraireRegie,
      ),
      ClientField(
        label: "Taux horaire vendu",
        icon: Icons.euro,
        getValue: (c) => c.tauxHoraireVendu,
      ),
      ClientField(
        label: "Forfait déplacement",
        icon: Icons.local_shipping,
        getValue: (c) => c.forfaitDeplacement,
      ),
    ],
  ),
  ClientFieldGroup(
    title: "Contrat",
    icon: Icons.description,
    color: Colors.indigo,
    adminOnly: true,
    fields: [
      ClientField(
        label: "Date de l'offre",
        icon: Icons.calendar_today,
        getValue: (c) => c.dateOffre,
      ),
      ClientField(
        label: "Date de prise d'effet",
        icon: Icons.calendar_today,
        getValue: (c) => c.datePriseEffetContrat,
      ),
      ClientField(
        label: "Date de fin de contrat",
        icon: Icons.event_busy,
        getValue: (c) => c.dateFinContrat,
      ),
      ClientField(
        label: "Durée",
        icon: Icons.hourglass_bottom,
        getValue: (c) => c.dureeContrat,
      ),
      ClientField(
        label: "Montant Contrat + AV",
        icon: Icons.euro,
        getValue: (c) => c.montantContratAv,
      ),
      ClientField(
        label: "Référence offre OGS",
        icon: Icons.confirmation_number,
        getValue: (c) => c.referenceOffreOgs,
      ),
      ClientField(
        label: "Responsable contrat",
        icon: Icons.person,
        getValue: (c) => c.responsableContrat,
      ),
      ClientField(
        label: "Tel Fixe responsable",
        icon: Icons.phone,
        getValue: (c) => c.telFixeResponsable,
        isPhone: true,
      ),
      ClientField(
        label: "Portable responsable",
        icon: Icons.phone_android,
        getValue: (c) => c.portableResponsable,
        isPhone: true,
      ),
      ClientField(
        label: "Courriel responsable",
        icon: Icons.email,
        getValue: (c) => c.courrielResponsable,
        isEmail: true,
      ),
    ],
  ),
  ClientFieldGroup(
    title: "Facturation",
    icon: Icons.receipt_long,
    color: Colors.orange,
    adminOnly: true,
    fields: [
      ClientField(
        label: "Adresse facturation",
        icon: Icons.location_on,
        getValue: (c) => c.adresseFacturation,
      ),
      ClientField(
        label: "Code Postal facturation",
        icon: Icons.mark_as_unread,
        getValue: (c) => c.codePostalFacturation,
      ),
      ClientField(
        label: "Commune facturation",
        icon: Icons.location_city,
        getValue: (c) => c.communeFacturation,
      ),
      ClientField(
        label: "Complément d'adresse facturation",
        icon: Icons.add_location,
        getValue: (c) => c.complementAdresseFacturation,
      ),
      ClientField(
        label: "Interlocuteur facturation",
        icon: Icons.person,
        getValue: (c) => c.interlocuteurFacturation,
      ),
      ClientField(
        label: "Tel Fixe interlocuteur facturation",
        icon: Icons.phone,
        getValue: (c) => c.telFixeInterlocuteurFacturation,
        isPhone: true,
      ),
      ClientField(
        label: "Portable interlocuteur facturation",
        icon: Icons.phone_android,
        getValue: (c) => c.portableInterlocuteurFacturation,
        isPhone: true,
      ),
      ClientField(
        label: "Courriel interlocuteur facturation",
        icon: Icons.email,
        getValue: (c) => c.courrielInterlocuteurFacturation,
        isEmail: true,
      ),
      ClientField(
        label: "Fréq. facturation annuelle",
        icon: Icons.event_repeat,
        getValue: (c) => c.freqFactuAnnuelle,
      ),
    ],
  ),
  ClientFieldGroup(
    title: "Révision & Indices",
    icon: Icons.trending_up,
    color: Colors.brown,
    adminOnly: true,
    fields: [
      ClientField(
        label: "Date de révision",
        icon: Icons.calendar_today,
        getValue: (c) => c.dateRevision,
      ),
      ClientField(
        label: "Formule révision entretien",
        icon: Icons.functions,
        getValue: (c) => c.formuleRevisionEntretien,
      ),
      ClientField(
        label: "Formule révision dépannage",
        icon: Icons.functions,
        getValue: (c) => c.formuleRevisionDepannage,
      ),
      ClientField(
        label: "Date Indice S",
        icon: Icons.calendar_today,
        getValue: (c) => c.dateIndiceS,
      ),
      ClientField(
        label: "Valeur indice S",
        icon: Icons.numbers,
        getValue: (c) => c.valeurIndiceS,
      ),
      ClientField(
        label: "Date Indice CH",
        icon: Icons.calendar_today,
        getValue: (c) => c.dateIndiceCh,
      ),
      ClientField(
        label: "Valeur indice CH",
        icon: Icons.numbers,
        getValue: (c) => c.valeurIndiceCh,
      ),
      ClientField(
        label: "Date Indice S°",
        icon: Icons.calendar_today,
        getValue: (c) => c.dateIndiceSPrime,
      ),
      ClientField(
        label: "Valeur indice S°",
        icon: Icons.numbers,
        getValue: (c) => c.valeurIndiceSPrime,
      ),
      ClientField(
        label: "Date Indice CH°",
        icon: Icons.calendar_today,
        getValue: (c) => c.dateIndiceChPrime,
      ),
      ClientField(
        label: "Valeur indice CH°",
        icon: Icons.numbers,
        getValue: (c) => c.valeurIndiceChPrime,
      ),
      ClientField(
        label: "Montant Contrat+AV révisé",
        icon: Icons.euro,
        getValue: (c) => c.montantContratAvRevise,
      ),
      ClientField(
        label: "Taux horaire révisé",
        icon: Icons.euro,
        getValue: (c) => c.tauxHoraireRevise,
      ),
      ClientField(
        label: "Forfait déplacement révisé",
        icon: Icons.local_shipping,
        getValue: (c) => c.forfaitDeplacementRevise,
      ),
      ClientField(
        label: "Modif RI ou BG",
        icon: Icons.edit_note,
        getValue: (c) => c.modifRiOuBg,
      ),
    ],
  ),
];
