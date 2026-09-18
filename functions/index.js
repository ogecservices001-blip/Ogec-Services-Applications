const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();
const db = admin.firestore();

// Mot de passe d'application Gmail du compte expéditeur — jamais en clair
// dans le code, configuré via `firebase functions:secrets:set`.
const gmailAppPassword = defineSecret('GMAIL_APP_PASSWORD');
const GMAIL_USER = 'ogecservices001@gmail.com';
const BUREAU_EMAIL = 'ogec.services@orange.fr';

function normaliserEmail(valeur) {
  return (valeur || '').toString().trim().toLowerCase();
}

/// Convertit récursivement tout Timestamp Firestore en chaîne ISO — le
/// SDK web (dart2js) plante sur le type Timestamp natif renvoyé tel
/// quel par une Callable Function ("Int64 accessor not supported").
function serialiserTimestamps(valeur) {
  if (valeur === null || valeur === undefined) return valeur;
  if (typeof valeur.toDate === 'function') {
    return valeur.toDate().toISOString();
  }
  if (Array.isArray(valeur)) {
    return valeur.map(serialiserTimestamps);
  }
  if (typeof valeur === 'object') {
    const resultat = {};
    for (const [cle, v] of Object.entries(valeur)) {
      resultat[cle] = serialiserTimestamps(v);
    }
    return resultat;
  }
  return valeur;
}

/// Charge l'équipement, son client/site et sa famille (type) — lève une
/// HttpsError 'not-found' si l'équipement ou son site n'existe pas.
async function chargerEquipementEtClient(equipementId) {
  const eqSnap = await db.collection('equipements').doc(equipementId).get();
  if (!eqSnap.exists) {
    throw new HttpsError('not-found', "Équipement introuvable.");
  }
  const equipement = serialiserTimestamps({ id: eqSnap.id, ...eqSnap.data() });

  const clientSnap = await db
    .collection('clients')
    .doc(equipement.clientId || '')
    .get();
  if (!clientSnap.exists) {
    throw new HttpsError('not-found', 'Site introuvable.');
  }
  const client = serialiserTimestamps({ id: clientSnap.id, ...clientSnap.data() });

  let type = null;
  if (equipement.typeEquipementId) {
    const typeSnap = await db
      .collection('types_equipement')
      .doc(equipement.typeEquipementId)
      .get();
    if (typeSnap.exists) {
      type = serialiserTimestamps({ id: typeSnap.id, ...typeSnap.data() });
    }
  }

  return { equipement, client, type };
}

/// Un email est "connu" s'il correspond à l'un des contacts déjà
/// enregistrés sur la fiche du site (site, tiers, responsable contrat,
/// facturation) — mêmes champs que ceux saisis dans le Répertoire — OU à
/// n'importe quelle personne ayant déjà accès à l'appli (technicien,
/// bureau, admin — collection `users`, email de connexion ou personnel).
async function emailConnu(client, email) {
  const connusClient = [
    client.courrielInterlocuteurSite,
    client.courrielTiers,
    client.courrielResponsable,
    client.courrielInterlocuteurFacturation,
  ]
    .map(normaliserEmail)
    .filter((e) => e.length > 0);
  if (connusClient.includes(email)) return true;

  const usersSnap = await db.collection('users').get();
  return usersSnap.docs.some((doc) => {
    const d = doc.data();
    const candidats = [d.email, d.emailPerso]
      .map(normaliserEmail)
      .filter((e) => e.length > 0);
    return candidats.includes(email);
  });
}

/// Callable public (sans authentification) : vérifie que l'email saisi
/// par la personne qui scanne le QR code est connu du site propriétaire
/// de l'équipement, et renvoie alors toutes ses données. Utilisée par la
/// page publique /equipement/{id} de l'appli web.
exports.verifierAccesEquipement = onCall(async (request) => {
  const equipementId = (request.data && request.data.equipementId || '')
    .toString()
    .trim();
  const email = normaliserEmail(request.data && request.data.email);
  if (!equipementId || !email) {
    throw new HttpsError('invalid-argument', 'Équipement et email requis.');
  }

  const { equipement, client, type } = await chargerEquipementEtClient(
    equipementId
  );

  if (!(await emailConnu(client, email))) {
    throw new HttpsError(
      'permission-denied',
      "Cet email n'est pas reconnu pour ce site."
    );
  }

  return { equipement, client, type };
});

/// Callable public : enregistre une demande de dépannage envoyée depuis
/// la page publique d'un équipement. Revalide l'email (défense en
/// profondeur, indépendante de verifierAccesEquipement), historise la
/// demande dans la fiche équipement (remarqueTechnicien), l'enregistre
/// dans la collection demandes_depannage pour le suivi bureau, et
/// notifie par email — un échec d'envoi n'empêche pas l'enregistrement.
exports.soumettreDemandeDepannage = onCall(
  { secrets: [gmailAppPassword] },
  async (request) => {
    const equipementId = (request.data && request.data.equipementId || '')
      .toString()
      .trim();
    const email = normaliserEmail(request.data && request.data.email);
    const message = (request.data && request.data.message || '')
      .toString()
      .trim();
    if (!equipementId || !email || !message) {
      throw new HttpsError(
        'invalid-argument',
        'Équipement, email et message requis.'
      );
    }

    const { equipement, client } = await chargerEquipementEtClient(
      equipementId
    );

    if (!(await emailConnu(client, email))) {
      throw new HttpsError(
        'permission-denied',
        "Cet email n'est pas reconnu pour ce site."
      );
    }

    const demandeRef = await db.collection('demandes_depannage').add({
      equipementId,
      clientId: client.id,
      clientNom: client.nom || '',
      clientSite: client.site || '',
      equipementNom: equipement.nom || '',
      email,
      message,
      statut: 'nouvelle',
      dateCreation: admin.firestore.FieldValue.serverTimestamp(),
    });

    const dateLisible = new Date().toLocaleString('fr-FR', {
      timeZone: 'Indian/Reunion',
    });
    const noteHistorique = `Demande de dépannage reçue le ${dateLisible} (${email})\n${message}`;
    const existante = (equipement.remarqueTechnicien || '').toString();
    const nouvelleRemarque = existante
      ? `${existante}\n---\n${noteHistorique}`
      : noteHistorique;
    await db
      .collection('equipements')
      .doc(equipementId)
      .update({ remarqueTechnicien: nouvelleRemarque });

    try {
      const transporteur = nodemailer.createTransport({
        service: 'gmail',
        auth: { user: GMAIL_USER, pass: gmailAppPassword.value() },
      });
      await transporteur.sendMail({
        from: `OGEC Services <${GMAIL_USER}>`,
        to: BUREAU_EMAIL,
        subject:
          `Nouvelle demande de dépannage — ${client.nom} ${client.site}`.trim(),
        text:
          `Équipement : ${equipement.nom}\n` +
          `Site : ${client.nom} — ${client.site}\n` +
          `Email du demandeur : ${email}\n\n` +
          `Message :\n${message}`,
      });
    } catch (err) {
      console.error('Échec envoi email demande de dépannage', err);
    }

    return { ok: true, demandeId: demandeRef.id };
  }
);
