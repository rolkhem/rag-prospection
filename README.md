# Prospection IA (rag_prospection)

Application Flutter (Android) de prospection B2B par RAG : appels d'offres
publics (BOAMP, TED) et signaux sociaux, interrogés en langage naturel et
qualifiés par Gemini.

## Architecture

```
lib/
  core/          config (.env), constantes, erreurs, client HTTP JSON, thème
  domain/        entités, interfaces de repositories, QueryRagUseCase
  data/          Gemini (embeddings + génération), Supabase (RPC + Edge Function), shared_preferences
  presentation/  ChatBloc + écran Chat, SourcesBloc + écran Sources
  injection.dart get_it — seul endroit où les implémentations sont choisies
supabase/
  migrations/    table `leads` (pgvector 768), RPC `match_leads` et `lead_source_stats`
  functions/     Edge Function `sync-leads` (ingestion BOAMP + TED)
```

Flux d'une question : embedding Gemini (`RETRIEVAL_QUERY`, 768 dim.) →
`match_leads` (HNSW cosinus filtré par source) → filtrage seuil / expiration →
prompt augmenté → Gemini.

Flux d'ingestion : bouton « Synchroniser » → Edge Function `sync-leads` →
connecteurs → embeddings `RETRIEVAL_DOCUMENT` → upsert avec la clé service_role.

| Source | API | Contenu |
|---|---|---|
| BOAMP | Opendatasoft DILA | Avis de marché français ouverts (30 derniers jours) |
| TED | TED Search v3 | Avis européens, acheteurs français |
| DECP | Opendatasoft data.economie.gouv.fr + Recherche d'entreprises | Marchés **attribués** dont la fin estimée tombe dans 3 à 12 mois : renouvellements à anticiper. Couvre aussi les marchés passés via Maximilien, AWS-Achat, Achatpublic, Marchés Sécurisés, e-marchespublics… |

Pour ajouter une source : un connecteur dans `FETCHERS`
(`supabase/functions/sync-leads/index.ts`), une migration qui l'autorise dans
les contraintes `check` et `lead_source_stats`, puis une valeur dans l'enum
`LeadSource` (+ `wireValue`, couleur et icône dans `source_style.dart`).

## Mise en place

### 1. Supabase

1. Créer un projet sur supabase.com.
2. Appliquer les migrations **dans l'ordre** : SQL Editor → coller
   `supabase/migrations/20261008000000_create_leads.sql`, puis
   `20261008100000_add_decp_source.sql`, ou avec la CLI :
   `supabase link --project-ref <ref>` puis `supabase db push`.
3. Déployer l'Edge Function :

   ```
   supabase secrets set GEMINI_API_KEY=<clé>
   supabase functions deploy sync-leads
   ```

   Avec une clé **publishable** (`sb_publishable_…`, non-JWT), ajouter
   `--no-verify-jwt` au déploiement : la passerelle rejetterait sinon l'appel.
   La fonction limite elle-même la fréquence (15 min par source).

### 2. Application

```
cp .env.example .env     # renseigner GEMINI_API_KEY, SUPABASE_URL, SUPABASE_ANON_KEY
flutter pub get
flutter run
```

Ouvrir l'écran Sources (icône réglages) et lancer une synchronisation pour
peupler l'index avant la première question.

### Tests

```
flutter analyze
flutter test
```

## Sécurité — à traiter avant distribution

Le `.env` est embarqué dans l'APK et lisible par décompilation.

- `SUPABASE_ANON_KEY` : conçue pour être publique. RLS est activé sans policy,
  seules les deux RPC bornées sont exposées.
- `GEMINI_API_KEY` : **acceptable uniquement pour un prototype**. Avant toute
  diffusion, faire passer embeddings et génération par une Edge Function et
  retirer la clé du `.env`.

## Limites connues

- LinkedIn et X n'ont pas de connecteur : pas d'API de recherche publique, et
  le scraping enfreint leurs CGU. La synchronisation renvoie « non supporté »
  pour ces sources ; brancher un fournisseur de données sous licence dans
  `FETCHERS` (`supabase/functions/sync-leads/index.ts`).
- L'ingestion couvre les 30 derniers jours, 200 avis max par source et par
  synchronisation.
- Le modèle et la dimension d'embedding (`gemini-embedding-001`, 768) doivent
  rester identiques entre l'app, l'Edge Function et la colonne SQL.
