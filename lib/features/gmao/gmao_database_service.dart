import 'package:cloud_firestore/cloud_firestore.dart';
import 'types_equipement/type_equipement_model.dart';
import 'equipements/equipement_model.dart';

class GmaoDatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<EquipementModel>> getEquipementsForClient(String clientId) {
    return _db
        .collection('equipements')
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => EquipementModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> addEquipement(EquipementModel equipement) async {
    await _db.collection('equipements').add({
      ...equipement.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateEquipement(String id, Map<String, dynamic> data) async {
    await _db.collection('equipements').doc(id).update(data);
  }

  Future<void> deleteEquipement(String id) async {
    await _db.collection('equipements').doc(id).delete();
  }

  Stream<List<TypeEquipementModel>> getTypesEquipement() {
    return _db
        .collection('types_equipement')
        .orderBy('nom')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TypeEquipementModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> addTypeEquipement(TypeEquipementModel type) async {
    await _db.collection('types_equipement').doc(type.id).set(type.toMap());
  }

  Future<void> updateTypeEquipement(TypeEquipementModel type) async {
    await _db
        .collection('types_equipement')
        .doc(type.id)
        .update(type.toMap());
  }

  Future<void> deleteTypeEquipement(String id) async {
    await _db.collection('types_equipement').doc(id).delete();
  }

  /// Pré-remplit le référentiel avec les deux familles déjà extraites du
  /// classeur "Mdle relevé entretien OGS BG" (MOD ROOF = cas complexe
  /// avec groupes de mesures répétables, MOD BRAS = cas simple), pour
  /// valider le formulaire dynamique avant d'extraire les 19 autres.
  Future<void> semerFamillesInitiales() async {
    final batch = _db.batch();
    final collection = _db.collection('types_equipement');

    batch.set(collection.doc('mod_roof'), _modRoof.toMap());
    batch.set(collection.doc('mod_bras'), _modBras.toMap());
    batch.set(collection.doc('mod_split'), _modSplit.toMap());

    await batch.commit();
  }

  static const _listeMarques = [
    'Airwell',
    'Gree',
    'LG',
    'Toshiba',
    'MDV',
    'Carrier',
    'Midea',
    'Daikin',
    'Wespoint',
    'TOP COOL',
    'Johnson Control',
    'ZENITHAIR',
    'Hitachi',
    'HAIER',
    'TOTALINE',
    'COLDAIR',
    'GALAXIE',
    'Mitsubishi Electric',
  ];

  static const _listeTechniciens = [
    'AMADY Toualali',
    'CHAMCIRKAN Dimitri',
    'CORSET Olivier',
    'GRONDIN Guillaume',
    'LAMY Fabrice',
    'LIXIVEL Elino',
    'MAILLOT Jean Cyrille',
    'MOUNICHY Julçay',
    'RAMSAMY Nicolas',
    'ROBERT Daniel',
    'ROBERT Ludovic',
    'ROSSE Bryan',
    'ROSSE Charly',
  ];

  static const _listeTypeVisite = [
    'Annuelle',
    '1/2 Semestriel',
    '2/2 Semestriel',
    '1/4 Trimestriel',
    '2/4 Trimestriel',
    '3/4 Trimestriel',
    '4/4 Trimestriel',
    'Mensuel',
  ];

  static final TypeEquipementModel _modRoof = TypeEquipementModel(
    id: 'mod_roof',
    code: 'MOD ROOF',
    nom: 'Roof-top',
    champsEnTeteSupplementaires: [
      ChampEnTete(cle: 'typeRefrigerant', label: 'Type réfrigérant'),
      ChampEnTete(cle: 'chargeRefrigerant', label: 'Charge réfrigérant'),
    ],
    checklist: [
      ChecklistItem(rep: 1, label: "Contrôle visuel de l'alignement"),
      ChecklistItem(rep: 2, label: 'Nettoyage de la turbine du ventilateur'),
      ChecklistItem(rep: 3, label: "Contrôle état et nettoyage des filtres"),
      ChecklistItem(
        rep: 4,
        label:
            "Nettoyage de la batterie échangeur (évaporateur et condenseur)",
      ),
      ChecklistItem(
        rep: 5,
        label: "Contrôle de l'absence de bruits anormaux ou de vibrations",
      ),
      ChecklistItem(
        rep: 6,
        label:
            'Vérification du bon fonctionnement des registres et volets de mélange',
      ),
      ChecklistItem(rep: 7, label: 'Reprise des points de rouille'),
      ChecklistItem(
        rep: 8,
        label: "Vérification de l'état des contacteurs / Perte tension",
      ),
      ChecklistItem(
        rep: 9,
        label: 'Essais des sécurités (pressostats HP/BP)',
      ),
      ChecklistItem(
        rep: 10,
        label: "Vérification de l'isolement des compresseurs",
      ),
      ChecklistItem(rep: 11, label: 'Contrôle des points de consigne'),
      ChecklistItem(rep: 12, label: 'Relevé paramètres de fonctionnement'),
      ChecklistItem(rep: 13, label: 'Contrôle étanchéité et PV'),
      ChecklistItem(
        rep: 14,
        label: "Vérification de l'isolement des moteurs condenseurs",
      ),
    ],
    groupesMesures: [
      GroupeMesure(
        cle: 'compresseur',
        label: 'Compresseur',
        repetable: true,
        nombreMax: 2,
        champs: [
          ChampMesure(
            cle: 'intensitePh1',
            label: 'Intensité mesurée Ph.1',
            unite: 'A',
          ),
          ChampMesure(
            cle: 'intensitePh2',
            label: 'Intensité mesurée Ph.2',
            unite: 'A',
          ),
          ChampMesure(
            cle: 'intensitePh3',
            label: 'Intensité mesurée Ph.3',
            unite: 'A',
          ),
          ChampMesure(
            cle: 'tensionL1L2',
            label: 'Tension mesurée L1-L2',
            unite: 'V',
          ),
          ChampMesure(
            cle: 'tensionL1L3',
            label: 'Tension mesurée L1-L3',
            unite: 'V',
          ),
          ChampMesure(
            cle: 'tensionL2L3',
            label: 'Tension mesurée L2-L3',
            unite: 'V',
          ),
          ChampMesure(
            cle: 'tempsFonctionnement',
            label: 'Temps de fonctionnement',
          ),
          ChampMesure(cle: 'nombreDemarrage', label: 'Nombre de démarrages'),
        ],
      ),
      GroupeMesure(
        cle: 'moteurCondenseur',
        label: 'Moteur condenseur',
        repetable: true,
        nombreMax: 4,
        champs: [
          ChampMesure(
            cle: 'intensitePh1',
            label: 'Intensité mesurée Ph.1',
            unite: 'A',
          ),
          ChampMesure(
            cle: 'intensitePh2',
            label: 'Intensité mesurée Ph.2',
            unite: 'A',
          ),
          ChampMesure(
            cle: 'intensitePh3',
            label: 'Intensité mesurée Ph.3',
            unite: 'A',
          ),
          ChampMesure(
            cle: 'tensionL1L2',
            label: 'Tension mesurée L1-L2',
            unite: 'V',
          ),
          ChampMesure(
            cle: 'tensionL1L3',
            label: 'Tension mesurée L1-L3',
            unite: 'V',
          ),
          ChampMesure(
            cle: 'tensionL2L3',
            label: 'Tension mesurée L2-L3',
            unite: 'V',
          ),
        ],
      ),
      GroupeMesure(
        cle: 'moteurCentrale',
        label: 'Moteur centrale',
        repetable: true,
        nombreMax: 2,
        champs: [
          ChampMesure(
            cle: 'intensitePh1',
            label: 'Intensité mesurée Ph.1',
            unite: 'A',
          ),
          ChampMesure(
            cle: 'intensitePh2',
            label: 'Intensité mesurée Ph.2',
            unite: 'A',
          ),
          ChampMesure(
            cle: 'intensitePh3',
            label: 'Intensité mesurée Ph.3',
            unite: 'A',
          ),
          ChampMesure(
            cle: 'tensionL1L2',
            label: 'Tension mesurée L1-L2',
            unite: 'V',
          ),
          ChampMesure(
            cle: 'tensionL1L3',
            label: 'Tension mesurée L1-L3',
            unite: 'V',
          ),
          ChampMesure(
            cle: 'tensionL2L3',
            label: 'Tension mesurée L2-L3',
            unite: 'V',
          ),
        ],
      ),
      GroupeMesure(
        cle: 'circuitFrigorifique',
        label: 'Circuit frigorifique',
        repetable: true,
        nombreMax: 2,
        champs: [
          ChampMesure(cle: 'tExterieure', label: 'T° Extérieure'),
          ChampMesure(
            cle: 'tCondensation',
            label: 'T° Condensation / Pression',
          ),
          ChampMesure(cle: 'tSortieEauGlacee', label: 'T° Sortie eau glacée'),
          ChampMesure(
            cle: 'tEvaporation',
            label: 'T° Évaporation / Pression',
          ),
          ChampMesure(
            cle: 'tLiquideDetendeur',
            label: 'T° Liquide entrée détendeur',
          ),
          ChampMesure(
            cle: 'tSurchauffeAspiration',
            label: "T° Surchauffe à l'aspiration",
          ),
        ],
      ),
      GroupeMesure(
        cle: 'courroie',
        label: 'Courroie',
        champs: [
          ChampMesure(cle: 'profil', label: 'Profil de courroie'),
          ChampMesure(cle: 'longueur', label: 'Longueur'),
          ChampMesure(cle: 'reference', label: 'Référence exacte'),
          ChampMesure(cle: 'quantite', label: 'Quantité'),
        ],
      ),
      GroupeMesure(
        cle: 'filtres',
        label: 'Filtres',
        repetable: true,
        nombreMax: 4,
        champs: [
          ChampMesure(cle: 'qte', label: 'Qté'),
          ChampMesure(cle: 'dimension', label: 'Dimension'),
          ChampMesure(cle: 'type', label: 'Type'),
          ChampMesure(cle: 'emplacement', label: 'Emplacement'),
          ChampMesure(cle: 'etat', label: 'État'),
        ],
      ),
    ],
  );

  static final TypeEquipementModel _modSplit = TypeEquipementModel(
    id: 'mod_split',
    code: 'MOD SPLIT',
    nom: 'Climatiseur individuel Split-Système',
    champsEnTeteSupplementaires: [
      ChampEnTete(
        cle: 'typeVisite',
        label: 'Type de visite',
        options: _listeTypeVisite,
      ),
      ChampEnTete(
        cle: 'nomTech',
        label: 'Nom technicien',
        options: _listeTechniciens,
      ),
      ChampEnTete(
        cle: 'typeRefrigerant',
        label: 'Type réfrigérant',
        options: ['R32', 'R410', 'R407', 'R22'],
      ),
      ChampEnTete(
        cle: 'typeEquipement',
        label: "Type d'équipement",
        options: [
          'Climatiseur type mural',
          'Climatiseur type cassette',
          'Climatiseur type plafonnier',
          'Climatiseur type allège',
        ],
      ),
      ChampEnTete(cle: 'marque', label: 'Marque', options: _listeMarques),
      ChampEnTete(
        cle: 'tensionAlim',
        label: 'Tension alim.',
        options: ['230 v', '400 v'],
      ),
      ChampEnTete(cle: 'referenceUInt', label: 'Référence U intérieure'),
      ChampEnTete(cle: 'referenceUExt', label: 'Référence U extérieure'),
      ChampEnTete(cle: 'numSerieUInt', label: 'N° série U intérieure'),
      ChampEnTete(cle: 'numSerieUExt', label: 'N° série U extérieure'),
      ChampEnTete(cle: 'dateMES', label: 'Date M.E.S.'),
      ChampEnTete(
        cle: 'chargeRefrigerant',
        label: 'Charge réfrigérant',
        numerique: true,
        unite: 'Kg',
      ),
      ChampEnTete(
        cle: 'puissance',
        label: 'Puissance',
        numerique: true,
        unite: 'Kw',
      ),
      ChampEnTete(
        cle: 'freqEntretienAnnuelle',
        label: "Fréquence entretien annuelle",
        numerique: true,
      ),
      ChampEnTete(
        cle: 'freqCourante',
        label: 'Fréquence courante',
        numerique: true,
        unite: '°',
      ),
      ChampEnTete(cle: 'dateIntervPrevue', label: 'Date interv. prévue'),
    ],
    checklist: [
      ChecklistItem(
        rep: 1,
        label: 'T° Air repris dans le local (°C)',
        typeValeur: TypeValeurChecklist.text,
      ),
      ChecklistItem(
        rep: 8,
        label: 'T° air soufflé dans le local (°C)',
        typeValeur: TypeValeurChecklist.text,
      ),
      ChecklistItem(
        rep: 4,
        label: 'Panneau commande contrôle led et affichage',
        typeValeur: TypeValeurChecklist.enum_,
        options: ['R.A.S.', 'À voir'],
      ),
      ChecklistItem(
        rep: 5,
        label: 'Evacuation des condensats / nettoyage Bac',
        typeValeur: TypeValeurChecklist.enum_,
        options: ['Fait', 'À voir'],
      ),
      ChecklistItem(
        rep: 6,
        label: 'Fonctionnement télécommande',
        typeValeur: TypeValeurChecklist.enum_,
        options: ['R.A.S.', 'À voir'],
      ),
      ChecklistItem(
        rep: 7,
        label: 'Fonctionnement volet de diffusion',
        typeValeur: TypeValeurChecklist.enum_,
        options: ['R.A.S.', 'À voir'],
      ),
      ChecklistItem(
        rep: 9,
        label: 'Nettoyage filtre à air',
        typeValeur: TypeValeurChecklist.enum_,
        options: ['Fait', 'À voir'],
      ),
      ChecklistItem(
        rep: 10,
        label: 'Vérification visuel état de la liaison fluide',
        typeValeur: TypeValeurChecklist.enum_,
        options: ['Fait', 'À voir'],
      ),
      ChecklistItem(
        rep: 11,
        label: 'Vérification visuel état de la liaison fluide',
        typeValeur: TypeValeurChecklist.enum_,
        options: ['R.A.S.', 'À voir'],
      ),
      ChecklistItem(
        rep: 12,
        label: 'T° air entrée condenseur (°C)',
        typeValeur: TypeValeurChecklist.text,
      ),
      ChecklistItem(
        rep: 13,
        label: 'T° air sortie condenseur (°C)',
        typeValeur: TypeValeurChecklist.text,
      ),
      ChecklistItem(
        rep: 14,
        label: 'Etat général du groupe extérieur',
        typeValeur: TypeValeurChecklist.enum_,
        options: ['Bon', 'Mauvais', 'A Remplacer'],
      ),
      ChecklistItem(
        rep: 15,
        label: "Etat général de l'unité intérieure",
        typeValeur: TypeValeurChecklist.enum_,
        options: ['Bon', 'Mauvais', 'A Remplacer'],
      ),
    ],
    groupesMesures: [
      GroupeMesure(
        cle: 'compresseur',
        label: 'Paramètres compresseur pleine charge',
        champs: [
          ChampMesure(cle: 'tension', label: 'Tension', unite: 'V'),
          ChampMesure(cle: 'intensite', label: 'Intensité', unite: 'A'),
          ChampMesure(
            cle: 'pressionAspi',
            label: 'Pression aspiration',
            unite: 'Bars',
          ),
        ],
      ),
    ],
  );

  static final TypeEquipementModel _modBras = TypeEquipementModel(
    id: 'mod_bras',
    code: 'MOD BRAS',
    nom: "Brasseur d'air",
    checklist: [
      ChecklistItem(
        rep: 1,
        label: 'Fonctionnement télécommande',
        typeValeur: TypeValeurChecklist.enum_,
        options: ['Ras', 'À voir'],
      ),
      ChecklistItem(
        rep: 2,
        label: 'Nettoyage pale',
        typeValeur: TypeValeurChecklist.enum_,
        options: ['Fait', 'À voir'],
      ),
      ChecklistItem(
        rep: 3,
        label: 'Contrôle équilibrage en rotation (vibrations)',
        typeValeur: TypeValeurChecklist.enum_,
        options: ['Ras', 'À voir'],
      ),
      ChecklistItem(
        rep: 4,
        label: 'État général brasseur',
        typeValeur: TypeValeurChecklist.enum_,
        options: ['Bon', 'Mauvais', 'HS'],
      ),
    ],
    groupesMesures: [
      GroupeMesure(
        cle: 'electrique',
        label: 'Paramètres électriques',
        champs: [
          ChampMesure(cle: 'tension', label: 'Tension', unite: 'V'),
          ChampMesure(cle: 'intensite', label: 'Intensité', unite: 'A'),
        ],
      ),
    ],
  );
}
