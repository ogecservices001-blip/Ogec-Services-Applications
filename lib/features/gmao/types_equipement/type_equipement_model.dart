import 'package:cloud_firestore/cloud_firestore.dart';

/// Champ d'en-tête spécifique à une famille, en plus du tronc commun
/// partagé par toutes les fiches (client, site, marque, référence,
/// n° série, tension, puissance, mise en service...).
class ChampEnTete {
  final String cle;
  final String label;
  final List<String> options;
  final bool numerique;
  final String unite;

  ChampEnTete({
    required this.cle,
    required this.label,
    this.options = const [],
    this.numerique = false,
    this.unite = '',
  });

  factory ChampEnTete.fromMap(Map<String, dynamic> m) {
    return ChampEnTete(
      cle: m['cle'] ?? '',
      label: m['label'] ?? '',
      options: List<String>.from(m['options'] ?? const []),
      numerique: m['numerique'] ?? false,
      unite: m['unite'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'cle': cle,
    'label': label,
    'options': options,
    'numerique': numerique,
    'unite': unite,
  };

  /// Liste d'options à afficher dans un dropdown, complétée par [valeur]
  /// si elle n'y figure pas déjà (ex: donnée réelle antérieure à un
  /// ajout dans la liste officielle) — pour ne jamais planter sur une
  /// valeur existante hors-liste.
  List<String> optionsAvec(String? valeur) {
    if (valeur == null || valeur.isEmpty || options.contains(valeur)) {
      return options;
    }
    return [...options, valeur];
  }
}

/// Type de valeur attendue pour un item de checklist.
enum TypeValeurChecklist { bool_, enum_, text }

TypeValeurChecklist typeValeurFromString(String s) {
  switch (s) {
    case 'enum':
      return TypeValeurChecklist.enum_;
    case 'text':
      return TypeValeurChecklist.text;
    default:
      return TypeValeurChecklist.bool_;
  }
}

String typeValeurToString(TypeValeurChecklist t) {
  switch (t) {
    case TypeValeurChecklist.enum_:
      return 'enum';
    case TypeValeurChecklist.text:
      return 'text';
    case TypeValeurChecklist.bool_:
      return 'bool';
  }
}

/// Une opération de la checklist d'entretien (ex: "Nettoyage de la
/// turbine du ventilateur"), avec son type de valeur attendue :
/// case à cocher (bool), choix parmi une liste (enum, avec ses propres
/// options), ou texte libre.
class ChecklistItem {
  final int rep;
  final String label;
  final TypeValeurChecklist typeValeur;
  final List<String> options;

  ChecklistItem({
    required this.rep,
    required this.label,
    this.typeValeur = TypeValeurChecklist.bool_,
    this.options = const [],
  });

  factory ChecklistItem.fromMap(Map<String, dynamic> m) {
    return ChecklistItem(
      rep: (m['rep'] ?? 0) is int ? m['rep'] : int.tryParse('${m['rep']}') ?? 0,
      label: m['label'] ?? '',
      typeValeur: typeValeurFromString(m['typeValeur'] ?? 'bool'),
      options: List<String>.from(m['options'] ?? const []),
    );
  }

  Map<String, dynamic> toMap() => {
    'rep': rep,
    'label': label,
    'typeValeur': typeValeurToString(typeValeur),
    'options': options,
  };
}

/// Un champ mesuré au sein d'un groupe de mesures (ex: "Intensité
/// mesurée Ph.1", unité "A").
class ChampMesure {
  final String cle;
  final String label;
  final String unite;

  ChampMesure({required this.cle, required this.label, this.unite = ''});

  factory ChampMesure.fromMap(Map<String, dynamic> m) {
    return ChampMesure(
      cle: m['cle'] ?? '',
      label: m['label'] ?? '',
      unite: m['unite'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'cle': cle, 'label': label, 'unite': unite};
}

/// Un groupe de mesures techniques (ex: "Compresseur", "Circuit
/// frigorifique"). Un groupe répétable se répète jusqu'à [nombreMax]
/// fois sur la fiche (ex: Compresseur 1, Compresseur 2), chaque
/// occurrence portant le même jeu de [champs].
class GroupeMesure {
  final String cle;
  final String label;
  final bool repetable;
  final int nombreMax;
  final List<ChampMesure> champs;

  GroupeMesure({
    required this.cle,
    required this.label,
    this.repetable = false,
    this.nombreMax = 1,
    this.champs = const [],
  });

  factory GroupeMesure.fromMap(Map<String, dynamic> m) {
    return GroupeMesure(
      cle: m['cle'] ?? '',
      label: m['label'] ?? '',
      repetable: m['repetable'] ?? false,
      nombreMax: (m['nombreMax'] ?? 1) is int
          ? m['nombreMax']
          : int.tryParse('${m['nombreMax']}') ?? 1,
      champs: (m['champs'] as List<dynamic>? ?? [])
          .map((c) => ChampMesure.fromMap(Map<String, dynamic>.from(c)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'cle': cle,
    'label': label,
    'repetable': repetable,
    'nombreMax': nombreMax,
    'champs': champs.map((c) => c.toMap()).toList(),
  };
}

/// Référentiel d'une famille d'équipement (ex: "MOD ROOF", "MOD BRAS") :
/// pilote entièrement le formulaire de relevé mobile pour cette
/// famille, sans code dédié — ajouter une famille = ajouter un
/// document dans cette collection.
class TypeEquipementModel {
  final String id;
  final String code;
  final String nom;
  final List<ChampEnTete> champsEnTeteSupplementaires;
  final List<ChecklistItem> checklist;
  final List<GroupeMesure> groupesMesures;

  TypeEquipementModel({
    required this.id,
    required this.code,
    required this.nom,
    this.champsEnTeteSupplementaires = const [],
    this.checklist = const [],
    this.groupesMesures = const [],
  });

  factory TypeEquipementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TypeEquipementModel(
      id: doc.id,
      code: data['code'] ?? '',
      nom: data['nom'] ?? '',
      champsEnTeteSupplementaires:
          (data['champsEnTeteSupplementaires'] as List<dynamic>? ?? [])
              .map((c) => ChampEnTete.fromMap(Map<String, dynamic>.from(c)))
              .toList(),
      checklist: (data['checklist'] as List<dynamic>? ?? [])
          .map((c) => ChecklistItem.fromMap(Map<String, dynamic>.from(c)))
          .toList(),
      groupesMesures: (data['groupesMesures'] as List<dynamic>? ?? [])
          .map((c) => GroupeMesure.fromMap(Map<String, dynamic>.from(c)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'code': code,
    'nom': nom,
    'champsEnTeteSupplementaires': champsEnTeteSupplementaires
        .map((c) => c.toMap())
        .toList(),
    'checklist': checklist.map((c) => c.toMap()).toList(),
    'groupesMesures': groupesMesures.map((g) => g.toMap()).toList(),
  };
}
