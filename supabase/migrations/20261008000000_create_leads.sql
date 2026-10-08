-- Index vectoriel des leads de prospection.
--
-- Modèle de sécurité : l'application mobile n'embarque que la clé anon /
-- publishable. RLS est activé SANS aucune policy, donc anon ne peut ni lire
-- ni écrire les tables directement. Les seuls accès exposés sont les deux
-- fonctions SECURITY DEFINER ci-dessous (recherche bornée et statistiques).
-- L'écriture passe exclusivement par l'Edge Function `sync-leads`, qui
-- utilise la clé service_role côté serveur.

create extension if not exists vector with schema extensions;

-- 768 dimensions : gemini-embedding-001 produit 3072 dimensions par défaut,
-- or un index HNSW sur `vector` est limité à 2000. La réduction est demandée
-- via `outputDimensionality` à l'ingestion ET à la requête ; ces deux valeurs
-- doivent rester identiques à `EmbeddingDefaults.dimensions` côté Flutter.
create table public.leads (
  id               text primary key,
  source           text not null check (source in ('boamp', 'ted', 'linkedin', 'x')),
  title            text not null,
  organization     text not null,
  summary          text not null,
  content          text not null,
  source_url       text not null check (source_url ~* '^https?://'),
  published_at     timestamptz not null,
  deadline         timestamptz,
  estimated_budget double precision,
  region           text,
  sector           text,
  embedding        extensions.vector(768) not null,
  -- Permet de détecter (et ré-ingérer) les vecteurs d'un ancien modèle :
  -- des embeddings de modèles différents ne sont pas comparables.
  embedding_model  text not null,
  ingested_at      timestamptz not null default now()
);

create index leads_embedding_hnsw_idx
  on public.leads using hnsw (embedding extensions.vector_cosine_ops);

create index leads_source_idx on public.leads (source);

alter table public.leads enable row level security;

-- Dernière synchronisation par source, utilisée par l'Edge Function comme
-- délai de grâce : la fonction est appelable avec la clé anon, elle ne doit
-- pas permettre de faire exploser la facture d'embeddings en boucle.
create table public.source_sync_runs (
  source          text primary key check (source in ('boamp', 'ted', 'linkedin', 'x')),
  last_synced_at  timestamptz not null,
  last_inserted   integer not null default 0
);

alter table public.source_sync_runs enable row level security;

-- Recherche de similarité cosinus filtrée par source.
--
-- `hnsw.iterative_scan` (pgvector >= 0.8) poursuit le parcours de l'index
-- tant que `match_count` lignes satisfaisant le filtre n'ont pas été
-- trouvées ; sans lui, HNSW filtre après coup et peut renvoyer moins de
-- résultats quand une source désactivée domine le voisinage. `relaxed_order`
-- pouvant légèrement désordonner les résultats, ils sont re-triés dans la
-- CTE matérialisée.
create or replace function public.match_leads(
  query_embedding extensions.vector(768),
  match_count     integer,
  filter_sources  text[]
)
returns table (
  id               text,
  source           text,
  title            text,
  organization     text,
  summary          text,
  content          text,
  source_url       text,
  published_at     timestamptz,
  deadline         timestamptz,
  estimated_budget double precision,
  region           text,
  sector           text,
  similarity       double precision
)
language sql
stable
security definer
set search_path = ''
set hnsw.iterative_scan = 'relaxed_order'
as $$
  with candidates as materialized (
    select
      l.id, l.source, l.title, l.organization, l.summary, l.content,
      l.source_url, l.published_at, l.deadline, l.estimated_budget,
      l.region, l.sector,
      l.embedding operator(extensions.<=>) query_embedding as distance
    from public.leads l
    where l.source = any (filter_sources)
    order by distance
    -- Borne dure : la fonction est publique, elle ne doit pas servir à
    -- aspirer l'index en un appel.
    limit least(greatest(match_count, 1), 50)
  )
  select
    c.id, c.source, c.title, c.organization, c.summary, c.content,
    c.source_url, c.published_at, c.deadline, c.estimated_budget,
    c.region, c.sector,
    1 - c.distance as similarity
  from candidates c
  order by c.distance;
$$;

create or replace function public.lead_source_stats()
returns table (
  source            text,
  lead_count        bigint,
  last_published_at timestamptz,
  last_synced_at    timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    s.source,
    count(l.id) as lead_count,
    max(l.published_at) as last_published_at,
    r.last_synced_at
  from unnest(array['boamp', 'ted', 'linkedin', 'x']) as s(source)
  left join public.leads l on l.source = s.source
  left join public.source_sync_runs r on r.source = s.source
  group by s.source, r.last_synced_at;
$$;

-- Par défaut PostgreSQL accorde EXECUTE à PUBLIC : on restreint explicitement.
revoke execute on function public.match_leads(extensions.vector, integer, text[]) from public;
revoke execute on function public.lead_source_stats() from public;
grant execute on function public.match_leads(extensions.vector, integer, text[]) to anon, authenticated;
grant execute on function public.lead_source_stats() to anon, authenticated;
