import 'models.dart';
import 'text_utils.dart';

class CategorySeed {
  final String name;
  final String icon;
  final int color;
  final String kind;
  const CategorySeed(this.name, this.icon, this.color, this.kind);
}

const String expenseFallbackName = 'Autres dépenses';
const String incomeFallbackName = 'Autres revenus';

const List<CategorySeed> defaultCategories = [
  CategorySeed('Logement', 'home', 0xFF5B7FEF, 'expense'),
  CategorySeed('Alimentation', 'cart', 0xFFF03E5E, 'expense'),
  CategorySeed('Restaurants', 'restaurant', 0xFFFFB300, 'expense'),
  CategorySeed('Transport', 'car', 0xFF26A69A, 'expense'),
  CategorySeed('Abonnements', 'subscriptions', 0xFF8E5BD8, 'expense'),
  CategorySeed('Shopping', 'bag', 0xFFEC6FB3, 'expense'),
  CategorySeed('Santé', 'health', 0xFF00B8D4, 'expense'),
  CategorySeed('Loisirs', 'leisure', 0xFFFF7043, 'expense'),
  CategorySeed('Banque & frais', 'bank', 0xFFB78763, 'expense'),
  CategorySeed('Impôts & taxes', 'gov', 0xFF7286C2, 'expense'),
  CategorySeed('Retraits', 'cash', 0xFF20C05C, 'expense'),
  CategorySeed('Virements', 'transfer', 0xFF90A4AE, 'both'),
  CategorySeed(expenseFallbackName, 'other', 0xFFB0B7C9, 'expense'),
  CategorySeed('Salaire', 'work', 0xFF2E9E5B, 'income'),
  CategorySeed('Remboursements', 'refund', 0xFF3AA6DD, 'income'),
  CategorySeed(incomeFallbackName, 'income', 0xFF9CCC65, 'income'),
];

const Map<String, List<String>> _keywords = {
  'Alimentation': [
    'CARREFOUR', 'LECLERC', 'AUCHAN', 'LIDL', 'ALDI', 'INTERMARCHE', 'MONOPRIX', 'FRANPRIX',
    'CASINO', 'SUPER U', 'HYPER U', 'NETTO', 'PICARD', 'GRAND FRAIS', 'BIOCOOP', 'CORA', 'SPAR',
    'LEADER PRICE', 'PROXI', 'BOULANGERIE', 'MARCHE U', 'NATURALIA', 'G20',
  ],
  'Restaurants': [
    'RESTAURANT', 'MCDONALD', 'MCDONALDS', 'MC DO', 'BURGER KING', 'KFC', 'QUICK', 'SUBWAY',
    'STARBUCKS', 'UBER EATS', 'UBER *EATS', 'UBEREATS', 'DELIVEROO', 'JUST EAT', 'DOMINOS',
    'PIZZA', 'SUSHI', 'BRASSERIE', 'KEBAB', 'TACOS', 'O TACOS', 'BAGELSTEIN', 'PAUL',
  ],
  'Transport': [
    'SNCF', 'RATP', 'NAVIGO', 'TRANSILIEN', 'UBER', 'BOLT', 'BLABLACAR', 'TOTALENERGIES', 'ESSO',
    'SHELL', 'AVIA', 'PEAGE', 'AUTOROUTE', 'VINCI', 'SANEF', 'APRR', 'PARKING', 'LIME', 'TCL',
    'TISSEO', 'RTM', 'OUIGO', 'TRAINLINE', 'HEETCH', 'FREENOW',
  ],
  'Logement': [
    'LOYER', 'EDF', 'ENGIE', 'VEOLIA', 'SUEZ', 'GRDF', 'ASSURANCE HABITATION', 'FONCIA',
    'NEXITY', 'EKWATEUR', 'OHM ENERGIE', 'SYNDIC',
  ],
  'Abonnements': [
    'NETFLIX', 'SPOTIFY', 'DEEZER', 'DISNEY', 'CANAL', 'AMAZON PRIME', 'PRIME VIDEO', 'APPLE.COM',
    'APPLE COM', 'ICLOUD', 'GOOGLE', 'YOUTUBE', 'FREE MOBILE', 'FREE TELECOM', 'SFR', 'ORANGE',
    'BOUYGUES', 'SOSH', 'RED BY SFR', 'B&YOU', 'OPENAI', 'CHATGPT', 'ANTHROPIC', 'CLAUDE.AI',
    'CRUNCHYROLL', 'PLAYSTATION PLUS', 'XBOX GAME PASS',
  ],
  'Shopping': [
    'AMAZON', 'AMZN', 'FNAC', 'DARTY', 'BOULANGER', 'ZARA', 'H&M', 'PRIMARK', 'DECATHLON', 'IKEA',
    'LEROY MERLIN', 'CASTORAMA', 'ACTION', 'CDISCOUNT', 'ZALANDO', 'SHEIN', 'VINTED', 'ALIEXPRESS',
    'TEMU', 'SEPHORA', 'KIABI', 'JD SPORTS', 'FOOT LOCKER', 'NIKE', 'UNIQLO',
  ],
  'Santé': [
    'PHARMACIE', 'PHARMA', 'MEDECIN', 'DOCTEUR', 'DENTISTE', 'LABORATOIRE', 'KINE', 'OPTIC',
    'MUTUELLE', 'DOCTOLIB', 'HOPITAL', 'CLINIQUE',
  ],
  'Loisirs': [
    'CINEMA', 'UGC', 'PATHE', 'GAUMONT', 'MK2', 'STEAM', 'PLAYSTATION', 'NINTENDO', 'XBOX',
    'EPIC GAMES', 'TICKETMASTER', 'BASIC FIT', 'FITNESS PARK', 'AIRBNB', 'BOOKING', 'FNAC SPECTACLES',
  ],
  'Banque & frais': [
    'FRAIS', 'COTISATION', 'COMMISSION', 'AGIOS', 'INTERETS DEBITEURS', 'OFFRE GROUPEE',
  ],
  'Impôts & taxes': ['DGFIP', 'IMPOT', 'IMPOTS', 'TRESOR PUBLIC', 'AMENDE', 'ANTAI', 'URSSAF'],
  'Retraits': ['RETRAIT', 'DAB'],
  'Salaire': ['SALAIRE', 'PAIE', 'PAYE'],
  'Remboursements': ['CPAM', 'AMELI', 'REMBOURSEMENT', 'REMB'],
  'Autres revenus': ['CAF'],
  'Virements': ['VIR', 'VIREMENT', 'LYDIA', 'WERO', 'PAYLIB'],
};

class RuleSeed {
  final String keyword;
  final String category;
  final int priority;
  const RuleSeed(this.keyword, this.category, this.priority);
}

/// Les virements génériques passent après les règles plus précises (ex. « VIR SALAIRE »).
List<RuleSeed> get defaultRuleSeeds => [
      for (final e in _keywords.entries)
        for (final k in e.value) RuleSeed(k, e.key, e.key == 'Virements' ? -1 : 0),
    ];

const int userRulePriority = 10;

List<Rule> sortRules(Iterable<Rule> rules) => rules.toList()
  ..sort((a, b) {
    final p = b.priority.compareTo(a.priority);
    if (p != 0) return p;
    return normalize(b.keyword).length.compareTo(normalize(a.keyword).length);
  });

/// Renvoie l'id de catégorie de la première règle qui correspond, sinon null.
int? categorize(String rawLabel, List<Rule> sortedRules) {
  final n = normalize(rawLabel);
  for (final r in sortedRules) {
    if (r.matches(n)) return r.categoryId;
  }
  return null;
}
