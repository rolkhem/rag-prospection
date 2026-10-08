-- Ajoute la source `decp` : marchés publics attribués (données essentielles
-- de la commande publique, data.economie.gouv.fr) dont la fin estimée
-- approche, c'est-à-dire des renouvellements à anticiper.

alter table public.leads drop constraint if exists leads_source_check;
alter table public.leads
  add constraint leads_source_check
  check (source in ('boamp', 'ted', 'decp', 'linkedin', 'x'));

alter table public.source_sync_runs drop constraint if exists source_sync_runs_source_check;
alter table public.source_sync_runs
  add constraint source_sync_runs_source_check
  check (source in ('boamp', 'ted', 'decp', 'linkedin', 'x'));

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
  from unnest(array['boamp', 'ted', 'decp', 'linkedin', 'x']) as s(source)
  left join public.leads l on l.source = s.source
  left join public.source_sync_runs r on r.source = s.source
  group by s.source, r.last_synced_at;
$$;
