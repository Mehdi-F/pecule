import 'models.dart';
import 'text_utils.dart';

// ---------------------------------------------------------------- taxonomie (inspirée de Bankin)

/// Groupes de la vue « Simplifié ».
const String grpEssentiel = 'essentiel';
const String grpPlaisir = 'plaisir';
const String grpEpargne = 'epargne';
const String grpImprevu = 'imprevu';

const Map<String, String> groupLabels = {
  grpEssentiel: 'Essentiel',
  grpPlaisir: 'Plaisir',
  grpEpargne: 'Épargne',
  grpImprevu: 'Imprévu / extra',
};

const Map<String, int> groupColors = {
  grpEssentiel: 0xFF5B5FEF,
  grpPlaisir: 0xFF9C8CFA,
  grpEpargne: 0xFFB9B3FC,
  grpImprevu: 0xFFD6DBE8,
};

const Map<String, String> groupIcons = {
  grpEssentiel: 'favorite_rounded',
  grpPlaisir: 'thumb_up_rounded',
  grpEpargne: 'savings_rounded',
  grpImprevu: 'bolt_rounded',
};

class SubSeed {
  final String name;
  final String icon;
  final String? grp; // sinon celui du parent
  const SubSeed(this.name, this.icon, [this.grp]);
}

class ParentSeed {
  final String name;
  final String icon;
  final int color;
  final String kind; // expense | income
  final String grp;
  final List<SubSeed> subs;
  const ParentSeed(this.name, this.icon, this.color, this.kind, this.grp, this.subs);
}

const String expenseFallbackName = 'À catégoriser';
const String incomeFallbackName = 'Autres rentrées';
const String incomeParentName = 'Entrées';

const List<ParentSeed> taxonomy = [
  ParentSeed('Logement', 'home_rounded', 0xFF5B7FEF, 'expense', grpEssentiel, [
    SubSeed('Loyer', 'home_rounded'),
    SubSeed('Électricité', 'bolt_rounded'),
    SubSeed('Gaz', 'local_fire_department_rounded'),
    SubSeed('Eau', 'water_drop_rounded'),
    SubSeed('Assurance habitation', 'shield_rounded'),
    SubSeed('Charges diverses', 'build_rounded'),
    SubSeed('Entretien', 'format_paint_rounded'),
    SubSeed('Décoration', 'chair_rounded', grpPlaisir),
    SubSeed('Extérieur et jardin', 'yard_rounded'),
    SubSeed('Logement - Autres', 'more_horiz_rounded'),
  ]),
  ParentSeed('Alimentation', 'shopping_cart_rounded', 0xFFF03E5E, 'expense', grpEssentiel, [
    SubSeed('Supermarché / Épicerie', 'shopping_cart_rounded'),
    SubSeed('Boulangerie', 'bakery_dining_rounded'),
    SubSeed('Fast foods', 'fastfood_rounded', grpPlaisir),
    SubSeed('Café / Snack', 'local_cafe_rounded', grpPlaisir),
    SubSeed('Alimentation - Autres', 'more_horiz_rounded'),
  ]),
  ParentSeed('Auto & Transports', 'directions_car_rounded', 0xFF26A69A, 'expense', grpEssentiel, [
    SubSeed('Transports en commun', 'directions_bus_rounded'),
    SubSeed('Billets de train', 'train_rounded'),
    SubSeed('Billets d\'avion', 'flight_rounded', grpPlaisir),
    SubSeed('Taxi / VTC', 'local_taxi_rounded'),
    SubSeed('Carburant', 'local_gas_station_rounded'),
    SubSeed('Péage', 'toll_rounded'),
    SubSeed('Parking', 'local_parking_rounded'),
    SubSeed('Location de véhicule', 'car_rental_rounded'),
    SubSeed('Entretien véhicule', 'car_repair_rounded'),
    SubSeed('Auto & Transports - Autres', 'more_horiz_rounded'),
  ]),
  ParentSeed('Abonnements', 'subscriptions_rounded', 0xFF8E5BD8, 'expense', grpEssentiel, [
    SubSeed('Internet & téléphonie', 'wifi_rounded'),
    SubSeed('Streaming & TV', 'live_tv_rounded', grpPlaisir),
    SubSeed('Applis & services', 'cloud_rounded'),
    SubSeed('Abonnements - Autres', 'more_horiz_rounded'),
  ]),
  ParentSeed('Achats & Shopping', 'shopping_bag_rounded', 0xFFEC6FB3, 'expense', grpPlaisir, [
    SubSeed('Vêtements / Chaussures', 'checkroom_rounded'),
    SubSeed('High-Tech', 'devices_rounded'),
    SubSeed('Jeux & jouets', 'toys_rounded'),
    SubSeed('Livres / Musique / Films', 'menu_book_rounded'),
    SubSeed('Articles de sport', 'sports_soccer_rounded'),
    SubSeed('Cadeaux', 'card_giftcard_rounded'),
    SubSeed('Achats & Shopping - Autres', 'more_horiz_rounded'),
  ]),
  ParentSeed('Loisirs & Sorties', 'celebration_rounded', 0xFFA35BD8, 'expense', grpPlaisir, [
    SubSeed('Sortie au restaurant', 'restaurant_rounded'),
    SubSeed('Bars / Clubs', 'local_bar_rounded'),
    SubSeed('Divertissements', 'sports_esports_rounded'),
    SubSeed('Sorties culturelles', 'theater_comedy_rounded'),
    SubSeed('Voyages / Vacances', 'beach_access_rounded'),
    SubSeed('Hôtels', 'hotel_rounded'),
    SubSeed('Sport', 'fitness_center_rounded'),
    SubSeed('Hobbies', 'palette_rounded'),
    SubSeed('Frais animaux', 'pets_rounded'),
    SubSeed('Loisirs & Sorties - Autres', 'more_horiz_rounded'),
  ]),
  ParentSeed('Santé', 'medical_services_rounded', 0xFF00B8D4, 'expense', grpEssentiel, [
    SubSeed('Médecin', 'medical_services_rounded'),
    SubSeed('Pharmacie', 'local_pharmacy_rounded'),
    SubSeed('Dentiste', 'health_and_safety_rounded'),
    SubSeed('Opticien', 'visibility_rounded'),
    SubSeed('Mutuelle', 'shield_rounded'),
    SubSeed('Santé - Autres', 'more_horiz_rounded'),
  ]),
  ParentSeed('Esthétique & Soins', 'spa_rounded', 0xFFFF8A80, 'expense', grpPlaisir, [
    SubSeed('Coiffeur', 'content_cut_rounded'),
    SubSeed('Cosmétique', 'spa_rounded'),
    SubSeed('Esthétique - Autres', 'more_horiz_rounded'),
  ]),
  ParentSeed('Banque', 'account_balance_rounded', 0xFFB78763, 'expense', grpEssentiel, [
    SubSeed('Frais bancaires', 'account_balance_rounded'),
    SubSeed('Assurance moyens de paiement', 'credit_card_rounded'),
    SubSeed('Remboursement emprunt', 'request_quote_rounded'),
    SubSeed('Banque - Autres', 'more_horiz_rounded'),
  ]),
  ParentSeed('Impôts & Taxes', 'gavel_rounded', 0xFF7286C2, 'expense', grpEssentiel, [
    SubSeed('Impôt sur le revenu', 'receipt_long_rounded'),
    SubSeed('Taxes locales', 'home_work_rounded'),
    SubSeed('Amendes', 'local_police_rounded', grpImprevu),
    SubSeed('Impôts - Autres', 'more_horiz_rounded'),
  ]),
  ParentSeed('Dépenses pro', 'work_rounded', 0xFF6F7FB8, 'expense', grpEssentiel, [
    SubSeed('Prévoyance', 'umbrella_rounded'),
    SubSeed('Logiciels pro', 'code_rounded'),
    SubSeed('Dépenses pro - Autres', 'more_horiz_rounded'),
  ]),
  ParentSeed('Retraits & Virements', 'swap_horiz_rounded', 0xFF90A4AE, 'expense', grpImprevu, [
    SubSeed('Retraits', 'local_atm_rounded', grpPlaisir),
    SubSeed('Virements émis', 'swap_horiz_rounded'),
  ]),
  ParentSeed('Épargne', 'savings_rounded', 0xFF3E9E8A, 'expense', grpEpargne, [
    SubSeed('Virements épargne', 'savings_rounded'),
    SubSeed('Assurance vie', 'trending_up_rounded'),
    SubSeed('Épargne - Autres', 'more_horiz_rounded'),
  ]),
  ParentSeed('Divers', 'category_rounded', 0xFFB0B7C9, 'expense', grpImprevu, [
    SubSeed(expenseFallbackName, 'help_outline_rounded'),
    SubSeed('Divers - Autres', 'more_horiz_rounded'),
  ]),
  ParentSeed(incomeParentName, 'download_rounded', 0xFF34C759, 'income', grpImprevu, [
    SubSeed('Salaires', 'work_rounded'),
    SubSeed('Remboursements', 'replay_rounded'),
    SubSeed('Allocations et pensions', 'family_restroom_rounded'),
    SubSeed('Virements reçus', 'call_received_rounded'),
    SubSeed('Économies', 'savings_rounded'),
    SubSeed('Dépôt d\'argent', 'account_balance_wallet_rounded'),
    SubSeed('Intérêts', 'percent_rounded'),
    SubSeed('Loyers reçus', 'real_estate_agent_rounded'),
    SubSeed('Extra', 'star_rounded'),
    SubSeed(incomeFallbackName, 'more_horiz_rounded'),
  ]),
];

/// Ancienne catégorie (v1) → sous-catégorie équivalente, pour la migration.
const Map<String, String> legacyCategoryMap = {
  'Logement': 'Logement - Autres',
  'Alimentation': 'Supermarché / Épicerie',
  'Restaurants': 'Sortie au restaurant',
  'Transport': 'Auto & Transports - Autres',
  'Abonnements': 'Abonnements - Autres',
  'Shopping': 'Achats & Shopping - Autres',
  'Santé': 'Santé - Autres',
  'Loisirs': 'Loisirs & Sorties - Autres',
  'Banque & frais': 'Frais bancaires',
  'Impôts & taxes': 'Impôts - Autres',
  'Retraits': 'Retraits',
  'Virements': 'Virements émis',
  'Autres dépenses': expenseFallbackName,
  'Salaire': 'Salaires',
  'Remboursements': 'Remboursements',
  'Autres revenus': incomeFallbackName,
};

// ---------------------------------------------------------------- mots-clés par défaut

const Map<String, List<String>> _keywords = {
  'Supermarché / Épicerie': [
    'CARREFOUR', 'LECLERC', 'AUCHAN', 'LIDL', 'ALDI', 'INTERMARCHE', 'MONOPRIX', 'FRANPRIX', 'CASINO',
    'SUPER U', 'HYPER U', 'MARCHE U', 'NETTO', 'PICARD', 'GRAND FRAIS', 'BIOCOOP', 'CORA', 'SPAR',
    'LEADER PRICE', 'PROXI', 'NATURALIA', 'G20', 'MATCH', 'CARREFOUR EXPRES',
  ],
  'Boulangerie': ['BOULANGERIE', 'CB PAUL', 'MARIE BLACHERE'],
  'Fast foods': [
    'MCDONALD', 'MCDONALDS', 'MC DO', 'BURGER KING', 'KFC', 'QUICK', 'SUBWAY', 'TACOS', 'O TACOS', 'KEBAB',
    'FIVE GUYS', 'DOMINOS', 'PIZZA HUT', 'POPEYES',
  ],
  'Café / Snack': ['STARBUCKS', 'CAFE', 'COFFEE', 'DONUTS', 'COLUMBUS', 'BAGELSTEIN'],
  'Sortie au restaurant': [
    'RESTAURANT', 'BRASSERIE', 'SUSHI', 'PIZZA', 'UBER EATS', 'UBER *EATS', 'UBEREATS', 'DELIVEROO',
    'JUST EAT', 'RESTAURATION', 'BISTROT',
  ],
  'Transports en commun': ['RATP', 'NAVIGO', 'TRANSILIEN', 'TCL', 'TISSEO', 'RTM', 'KEOLIS', 'ILEVIA', 'METRO', 'LIME'],
  'Billets de train': ['SNCF', 'OUIGO', 'TRAINLINE', 'SNCF-VOYAGEURS', 'EUROSTAR'],
  'Billets d\'avion': ['AIR FRANCE', 'RYANAIR', 'EASYJET', 'TRANSAVIA', 'VUELING', 'VOLOTEA'],
  'Taxi / VTC': ['UBER', 'BOLT', 'HEETCH', 'FREENOW', 'G7'],
  'Carburant': ['TOTALENERGIES', 'ESSO', 'SHELL', 'AVIA', 'BP', 'STATION SERVICE'],
  'Péage': ['PEAGE', 'AUTOROUTE', 'VINCI', 'SANEF', 'APRR'],
  'Parking': ['PARKING', 'INDIGO'],
  'Auto & Transports - Autres': ['BLABLACAR'],
  'Loyer': ['LOYER', 'IMMOB', 'FONCIA', 'NEXITY'],
  'Électricité': ['EDF', 'ENGIE', 'EKWATEUR', 'OHM ENERGIE', 'TOTALENERGIES ELECTRICITE'],
  'Gaz': ['GRDF'],
  'Eau': ['VEOLIA', 'SUEZ'],
  'Assurance habitation': ['ASSURANCE HABITATION', 'ACHEEL', 'LUKO'],
  'Charges diverses': ['SYNDIC'],
  'Décoration': ['IKEA', 'MAISONS DU MONDE', 'CASA'],
  'Entretien': ['LEROY MERLIN', 'CASTORAMA', 'BRICO', 'BRICOMARCHE'],
  'Internet & téléphonie': [
    'FREE MOBILE', 'FREE TELECOM', 'SFR', 'ORANGE', 'BOUYGUES', 'SOSH', 'RED BY SFR', 'B&YOU',
  ],
  'Streaming & TV': [
    'NETFLIX', 'SPOTIFY', 'DEEZER', 'DISNEY', 'CANAL', 'AMAZON PRIME', 'PRIME VIDEO', 'YOUTUBE', 'CRUNCHYROLL',
    'PLAYSTATION PLUS', 'XBOX GAME PASS',
  ],
  'Applis & services': [
    'APPLE.COM', 'APPLE COM', 'ICLOUD', 'GOOGLE', 'GOOGLE PLAY', 'OPENAI', 'CHATGPT', 'ANTHROPIC', 'CLAUDE.AI',
    'CLOUDFLARE',
  ],
  'Abonnements - Autres': ['DEKUPLE', 'ADLPARTNER'],
  'Vêtements / Chaussures': [
    'ZARA', 'H&M', 'PRIMARK', 'KIABI', 'JD SPORTS', 'FOOT LOCKER', 'NIKE', 'UNIQLO', 'ZALANDO', 'SHEIN',
    'VINTED', 'CELIO', 'JULES',
  ],
  'High-Tech': ['FNAC', 'DARTY', 'BOULANGER', 'LDLC'],
  'Jeux & jouets': ['LEGO', 'KING JOUET', 'JOUECLUB'],
  'Articles de sport': ['DECATHLON', 'INTERSPORT', 'GO SPORT'],
  'Achats & Shopping - Autres': [
    'AMAZON', 'AMZN', 'AMZ', 'CDISCOUNT', 'ALIEXPRESS', 'TEMU', 'ACTION', 'SCALAPAY', 'KLARNA',
  ],
  'Coiffeur': ['COIFFUR', 'COIFFURE', 'COIFFEUR', 'BARBER', 'BARBIER'],
  'Cosmétique': ['SEPHORA', 'NOCIBE', 'MARIONNAUD', 'YVES ROCHER'],
  'Divertissements': ['CINEMA', 'UGC', 'PATHE', 'GAUMONT', 'MK2', 'STEAM', 'PLAYSTATION', 'NINTENDO', 'XBOX', 'EPIC GAMES'],
  'Sorties culturelles': ['TICKETMASTER', 'FNAC SPECTACLES', 'LIVE NATION', 'MUSEE', 'MUSEO'],
  'Voyages / Vacances': ['AIRBNB', 'BOOKING'],
  'Sport': ['BASIC FIT', 'FITNESS PARK', 'ON AIR'],
  'Médecin': ['MEDECIN', 'DOCTEUR', 'DOCTOLIB', 'KINE', 'LABORATOIRE', 'HOPITAL', 'CLINIQUE'],
  'Pharmacie': ['PHARMACIE', 'PHARMA'],
  'Dentiste': ['DENTISTE', 'DENTAIRE'],
  'Opticien': ['OPTIC', 'OPTIQUE', 'AFFLELOU', 'KRYS'],
  'Mutuelle': ['MUTUELLE'],
  'Frais bancaires': ['FRAIS', 'COTISATION', 'COMMISSION', 'AGIOS', 'INTERETS DEBITEURS', 'OFFRE GROUPEE'],
  'Assurance moyens de paiement': ['ASSURANCE MOYEN DE PAIEMENT'],
  'Impôt sur le revenu': ['DGFIP', 'IMPOT', 'IMPOTS', 'TRESOR PUBLIC', 'FINANCES PUBLIQUES', 'FINANCES PUBLIQUE'],
  'Amendes': ['AMENDE', 'ANTAI'],
  'Impôts - Autres': ['URSSAF'],
  'Prévoyance': ['PREVOYANCE'],
  'Retraits': ['RETRAIT', 'DAB'],
  'Virements émis': ['VIR', 'VIREMENT', 'LYDIA', 'WERO', 'PAYLIB'],
  'Virements épargne': ['REVOLUT', 'LIVRET'],
  'Assurance vie': ['ASSURANCE VIE', 'LCL VIE', 'PREDICA'],
  'Salaires': ['SALAIRE', 'PAIE', 'PAYE', 'SALARY'],
  'Remboursements': [
    'CPAM', 'AMELI', 'REMBOURSEMENT', 'REMB', 'SIACI', 'WORKLIFE BENEFITS', 'MUTUELLE', 'AVOIR',
  ],
  'Allocations et pensions': ['CAF', 'FRANCE TRAVAIL', 'POLE EMPLOI', 'CARSAT'],
  'Virements reçus': ['VIR', 'VIREMENT', 'LYDIA', 'WERO', 'PAYLIB'],
  'Économies': ['REVOLUT', 'LIVRET'],
  'Intérêts': ['INTERETS'],
};

class RuleSeed {
  final String keyword;
  final String category;
  final int priority;
  const RuleSeed(this.keyword, this.category, this.priority);
}

const Set<String> _genericCategories = {'Virements émis', 'Virements reçus'};

/// Les virements génériques passent après les règles plus précises (ex. « VIR SALAIRE »).
List<RuleSeed> get defaultRuleSeeds => [
      for (final e in _keywords.entries)
        for (final k in e.value) RuleSeed(k, e.key, _genericCategories.contains(e.key) ? -1 : 0),
    ];

const int userRulePriority = 10;

/// À incrémenter quand on ajoute des mots-clés par défaut (migration des installations existantes).
const int defaultRulesVersion = 3;

List<Rule> sortRules(Iterable<Rule> rules) => rules.toList()
  ..sort((a, b) {
    final p = b.priority.compareTo(a.priority);
    if (p != 0) return p;
    return normalize(b.keyword).length.compareTo(normalize(a.keyword).length);
  });

/// Renvoie l'id de catégorie de la première règle qui correspond et qui convient au sens de
/// l'opération (une catégorie de dépense n'est pas proposée pour une entrée, et inversement).
int? categorize(String rawLabel, List<Rule> sortedRules, {bool? isExpense, String Function(int categoryId)? kindOf}) {
  final n = normalize(rawLabel);
  for (final r in sortedRules) {
    if (!r.matches(n)) continue;
    if (isExpense != null && kindOf != null) {
      final kind = kindOf(r.categoryId);
      if (isExpense && kind == 'income') continue;
      if (!isExpense && kind == 'expense') continue;
    }
    return r.categoryId;
  }
  return null;
}
