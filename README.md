# Pécule

Appli Android perso pour suivre son compte bancaire : évolution du compte jour par jour, analyse des sorties et entrées par catégorie, budget mensuel, et **liaison des dépenses à leurs remboursements** (les analyses comptent le montant net).

Toutes les données restent sur le téléphone (SQLite). Pas de serveur, pas de compte.

## Récupérer l'APK

Chaque push sur `main` lance le workflow **Build APK** (onglet *Actions*). À la fin, l'APK est publiée dans **Releases** (`pecule-N.apk`) : ouvre la release depuis le téléphone, télécharge l'APK et installe-la (autoriser l'installation depuis le navigateur la première fois).

Les builds sont toutes signées avec la même clé (`ci/debug.keystore`), donc une nouvelle version s'installe par-dessus l'ancienne sans perdre les données. Garde le repo privé.

## Importer ses opérations

Depuis l'espace client LCL (site web), télécharge l'historique du compte en **CSV** ou **OFX**, puis *Activités → icône d'import*.

- Le format CSV est détecté automatiquement (séparateur, en-têtes, colonnes montant ou débit/crédit, encodage).
- L'OFX renseigne aussi le solde du compte.
- Réimporter une période qui chevauche la précédente ne crée pas de doublons. Garde le même format d'un import à l'autre.

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
  categorizer.dart   catégories et mots-clés par défaut
  store.dart         SQLite + état de l'app (ChangeNotifier)
  ui/screens/        Activités, Analyse, Réglages, fiche opération
test/                tests du parsing et de la catégorisation
```

Le dossier `android/` est généré par `flutter create` dans la CI. En local : `flutter create --project-name budget_app --org com.mehdi --platforms android .` puis `flutter run`.

## Étape suivante possible

Synchronisation automatique via Enable Banking (API DSP2, gratuite en mode restreint pour ses propres comptes).
