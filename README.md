# Pécule

Appli Android perso pour suivre son compte bancaire : évolution du compte jour par jour, analyse des sorties et entrées par catégorie, budget mensuel, et **liaison des dépenses à leurs remboursements** (les analyses comptent le montant net).

Toutes les données restent sur le téléphone (SQLite). Pas de serveur, pas de compte.

## Récupérer l'APK

Chaque push sur `main` lance le workflow **Build APK** (onglet *Actions*). À la fin, l'APK est publiée dans **Releases** (`pecule-N.apk`) : ouvre la release depuis le téléphone, télécharge l'APK et installe-la (autoriser l'installation depuis le navigateur la première fois).

Les builds sont toutes signées avec la même clé (`ci/debug.keystore`, imposée par `ci/patch_gradle.py` et vérifiée en CI), donc une nouvelle version s'installe par-dessus l'ancienne sans perdre les données. Garde le repo privé.

## Importer ses opérations

Le plus simple : les **relevés de compte PDF LCL** (appli ou site LCL → Documents → Relevés de compte de dépôt). Dans Pécule : *Activités → icône d'import*, plusieurs relevés d'un coup si besoin.

- Le PDF est lu sur le téléphone (rien n'est envoyé nulle part) ; le solde de fin de relevé est repris automatiquement.
- Les fichiers **CSV** et **OFX** sont aussi acceptés (détection automatique des colonnes, de l'encodage, débit/crédit).
- Réimporter une période déjà importée ne crée pas de doublons. Garde le même format d'un import à l'autre.

## Fonctionnalités

- **Activités** : une carte par jour avec le solde de fin de journée et la variation, détail des opérations au toucher.
- **Analyse** : donut par catégorie (sorties / entrées), budget mensuel, bilan du mois, détail par catégorie.
- **Remboursements** : depuis une dépense, « Lier un remboursement » (montant partiel possible). La dépense compte pour son net, l'entrée liée n'est plus comptée comme revenu.
- **Catégories** : catégorisation automatique par mots-clés (enseignes françaises courantes), changement manuel avec création de règle pour les opérations similaires et les imports suivants.
- **Exclure des analyses** : pour les virements entre ses propres comptes.

## Code

```
lib/
  importer.dart      parsing CSV / OFX (pur Dart, testé)
  lcl_pdf.dart       lecture des relevés PDF LCL à partir des mots positionnés
  pdf_words.dart     extraction du texte PDF (syncfusion_flutter_pdf, licence communautaire)
  bank/              client Enable Banking (JWT RS256) et conversion des transactions
  categorizer.dart   catégories et mots-clés par défaut
  store.dart         SQLite + état de l'app (ChangeNotifier)
  ui/screens/        Activités, Analyse, Réglages, fiche opération
test/                tests du parsing (dont un relevé LCL fictif) et de la catégorisation
```

Le dossier `android/` est généré par `flutter create` dans la CI. En local : `flutter create --project-name budget_app --org com.mehdi --platforms android .` puis `flutter run`.

## Synchro bancaire (Enable Banking)

Pécule peut récupérer les opérations directement auprès de la banque via l'API DSP2 d'[Enable Banking](https://enablebanking.com), gratuite en mode restreint pour ses propres comptes.

1. Control Panel Enable Banking → *API applications* : application **Production**, redirect URL `https://localhost/pecule`. Le navigateur télécharge la clé privée `<application-id>.pem`.
2. *Activate by linking accounts* sur la fiche de l'application (lier son compte LCL).
3. Dans Pécule : *Réglages → Synchro bancaire* → importer le `.pem`, puis « Connecter ma banque ».

Ensuite : bouton de synchro (ou tirer vers le bas) sur *Activités*, et synchro automatique à l'ouverture si la dernière date de plus de 6 h. Les opérations déjà importées par relevé ne sont pas dupliquées (même montant à ±3 jours). L'accès est à renouveler tous les ~180 jours.

La clé privée reste sur le téléphone : ne jamais la committer.
