// Edge Function `sync-leads` : récupère les dernières publications des
// sources demandées, calcule les embeddings Gemini et les insère dans
// `public.leads` avec la clé service_role.
//
// Appelée par l'app mobile avec la clé anon : elle ne fait confiance à rien
// de ce que le client envoie hormis la liste des sources, et applique un
// délai de grâce par source pour borner le coût des embeddings.
//
// Secrets requis : GEMINI_API_KEY (`supabase secrets set GEMINI_API_KEY=...`).
// SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY sont injectés par la plateforme.

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

// Doivent rester alignés avec la migration SQL et `EmbeddingDefaults` (Flutter).
const EMBEDDING_MODEL = Deno.env.get("GEMINI_EMBEDDING_MODEL") ?? "gemini-embedding-001";
const EMBEDDING_DIMENSIONS = 768;
const EMBEDDING_BATCH_SIZE = 100;

// Chaque texte d'un `batchEmbedContents` compte comme une requête : le niveau
// gratuit Gemini (~100/min) refuse un second lot de 100 dans la même minute.
// Le budget par appel reste sous ce plafond et est réparti entre les sources ;
// les avis restants sont traités aux synchronisations suivantes. À relever
// (secret EMBEDDING_BUDGET) avec un projet Gemini payant.
const EMBEDDING_BUDGET = Number(Deno.env.get("EMBEDDING_BUDGET") ?? "90");

const LOOKBACK_DAYS = 30;
const MAX_LEADS_PER_SOURCE = 200;
const SYNC_COOLDOWN_MINUTES = 15;
const FETCH_TIMEOUT_MS = 20_000;

type Source = "boamp" | "ted" | "linkedin" | "x";
const ALL_SOURCES: readonly Source[] = ["boamp", "ted", "linkedin", "x"];

type SyncStatus = "ok" | "partial" | "cooldown" | "unsupported" | "error";

interface LeadRow {
  id: string;
  source: Source;
  title: string;
  organization: string;
  summary: string;
  content: string;
  source_url: string;
  published_at: string;
  deadline: string | null;
  estimated_budget: number | null;
  region: string | null;
  sector: string | null;
}

interface SourceResult {
  source: Source;
  status: SyncStatus;
  fetched: number;
  inserted: number;
  /** Avis récupérés mais pas encore vectorisés (budget ou quota atteint). */
  remaining: number;
  message?: string;
}

/** Quota Gemini dépassé : arrêt propre, le reste attendra le prochain appel. */
class QuotaExceededError extends Error {}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Méthode non autorisée." }, 405);

  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  if (!geminiKey) return json({ error: "GEMINI_API_KEY non configurée côté serveur." }, 500);

  let requested: Source[];
  try {
    requested = parseSources(await req.json());
  } catch (error) {
    return json({ error: (error as Error).message }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  // Séquentiel : les API publiques (TED en particulier) limitent le nombre
  // de requêtes simultanées, et le volume reste faible.
  const connectable = requested.filter((s) => FETCHERS[s]).length;
  const budgetPerSource = Math.max(1, Math.floor(EMBEDDING_BUDGET / Math.max(1, connectable)));
  const results: SourceResult[] = [];
  for (const source of requested) {
    results.push(await syncSource(supabase, source, geminiKey, budgetPerSource));
  }

  return json({ results }, 200);
});

async function syncSource(
  supabase: SupabaseClient,
  source: Source,
  geminiKey: string,
  embeddingBudget: number,
): Promise<SourceResult> {
  const fetcher = FETCHERS[source];
  if (!fetcher) {
    return {
      source,
      status: "unsupported",
      fetched: 0,
      inserted: 0,
      remaining: 0,
      message: "Aucun connecteur disponible : cette source n'expose pas d'API publique exploitable.",
    };
  }

  let fetched = 0;
  let inserted = 0;
  try {
    const { data: lastRun, error: runError } = await supabase
      .from("source_sync_runs")
      .select("last_synced_at")
      .eq("source", source)
      .maybeSingle();
    if (runError) throw runError;

    if (lastRun) {
      const elapsedMs = Date.now() - new Date(lastRun.last_synced_at).getTime();
      if (elapsedMs < SYNC_COOLDOWN_MINUTES * 60_000) {
        return {
          source,
          status: "cooldown",
          fetched: 0,
          inserted: 0,
          remaining: 0,
          message: `Déjà synchronisée il y a moins de ${SYNC_COOLDOWN_MINUTES} minutes.`,
        };
      }
    }

    const leads = dedupe(await fetcher());
    fetched = leads.length;

    // Seuls les leads absents de l'index sont vectorisés : c'est l'appel
    // facturé, et un avis publié ne change pas de contenu.
    const existing = new Set<string>();
    for (const ids of chunk(leads.map((l) => l.id), 200)) {
      const { data, error } = await supabase.from("leads").select("id").in("id", ids);
      if (error) throw error;
      for (const row of data) existing.add(row.id as string);
    }
    const fresh = leads.filter((l) => !existing.has(l.id));

    let quotaHit = false;
    for (const batch of chunk(fresh.slice(0, embeddingBudget), EMBEDDING_BATCH_SIZE)) {
      let vectors: number[][];
      try {
        vectors = await embedDocuments(batch.map(toEmbeddingText), geminiKey);
      } catch (error) {
        if (!(error instanceof QuotaExceededError)) throw error;
        quotaHit = true;
        break;
      }
      const rows = batch.map((lead, i) => ({
        ...lead,
        embedding: JSON.stringify(vectors[i]),
        embedding_model: EMBEDDING_MODEL,
      }));
      const { error } = await supabase.from("leads").upsert(rows, { onConflict: "id" });
      if (error) throw error;
      inserted += rows.length;
    }

    const remaining = fresh.length - inserted;
    if (remaining > 0) {
      // Pas d'enregistrement du run : le délai de grâce ne doit pas empêcher
      // de reprendre là où la vectorisation s'est arrêtée.
      return {
        source,
        status: "partial",
        fetched,
        inserted,
        remaining,
        message: quotaHit
          ? "Quota Gemini atteint : relancez dans une minute pour continuer."
          : "Relancez dans une minute pour vectoriser les avis restants.",
      };
    }

    const { error: upsertRunError } = await supabase.from("source_sync_runs").upsert({
      source,
      last_synced_at: new Date().toISOString(),
      last_inserted: inserted,
    });
    if (upsertRunError) throw upsertRunError;

    return { source, status: "ok", fetched, inserted, remaining: 0 };
  } catch (error) {
    console.error(`sync ${source}`, error);
    return {
      source,
      status: "error",
      fetched,
      // Les lots déjà insérés restent dans l'index : on le signale.
      inserted,
      remaining: 0,
      message: "La synchronisation a échoué. Réessayez plus tard.",
    };
  }
}

// ---------------------------------------------------------------------------
// Connecteurs
// ---------------------------------------------------------------------------

const FETCHERS: Partial<Record<Source, () => Promise<LeadRow[]>>> = {
  boamp: fetchBoamp,
  ted: fetchTed,
  // LinkedIn et X n'offrent pas d'API de recherche publique ; le scraping
  // enfreint leurs CGU. Brancher ici un fournisseur de données sous licence.
};

/** BOAMP via l'API Opendatasoft de la DILA (sans authentification). */
async function fetchBoamp(): Promise<LeadRow[]> {
  const since = isoDate(daysAgo(LOOKBACK_DAYS));
  const rows: LeadRow[] = [];

  for (let offset = 0; offset < MAX_LEADS_PER_SOURCE; offset += 100) {
    const url = new URL(
      "https://boamp-datadila.opendatasoft.com/api/explore/v2.1/catalog/datasets/boamp/records",
    );
    url.searchParams.set("where", `dateparution >= date'${since}' and nature = 'APPEL_OFFRE'`);
    url.searchParams.set("order_by", "dateparution desc");
    url.searchParams.set("limit", "100");
    url.searchParams.set("offset", String(offset));

    const body = await fetchJson(url);
    const records = Array.isArray(body?.results) ? body.results : [];

    for (const r of records) {
      const idweb = str(r.idweb);
      const sourceUrl = httpUrl(r.url_avis);
      const title = str(r.objet);
      const publishedAt = str(r.dateparution);
      if (!idweb || !sourceUrl || !title || !publishedAt) continue;

      const descriptors = strArray(r.descripteur_libelle);
      const marketTypes = strArray(r.type_marche_facette);
      const departments = strArray(r.code_departement);

      const content = [
        `Objet : ${title}`,
        marketTypes.length ? `Type de marché : ${marketTypes.join(", ")}` : null,
        str(r.procedure_libelle) ? `Procédure : ${str(r.procedure_libelle)}` : null,
        descriptors.length ? `Descripteurs : ${descriptors.join(", ")}` : null,
        str(r.famille_libelle) ? `Famille : ${str(r.famille_libelle)}` : null,
      ].filter(Boolean).join("\n");

      rows.push({
        id: `boamp:${idweb}`,
        source: "boamp",
        title,
        organization: str(r.nomacheteur) ?? "Acheteur public non précisé",
        summary: excerpt([title, descriptors.join(", ")].filter(Boolean).join(" — "), 280),
        content,
        source_url: sourceUrl,
        published_at: new Date(publishedAt).toISOString(),
        deadline: isoOrNull(r.datelimitereponse),
        estimated_budget: null,
        region: departments.length ? `Département ${departments.join(", ")}` : null,
        sector: descriptors.length ? descriptors.slice(0, 3).join(", ") : null,
      });
    }

    if (records.length < 100) break;
  }

  return rows;
}

/** TED (avis européens) via l'API Search v3, restreinte aux acheteurs français. */
async function fetchTed(): Promise<LeadRow[]> {
  const since = isoDate(daysAgo(LOOKBACK_DAYS)).replaceAll("-", "");
  const rows: LeadRow[] = [];
  const pageSize = 100;

  for (let page = 1; (page - 1) * pageSize < MAX_LEADS_PER_SOURCE; page++) {
    const body = await fetchJson(new URL("https://api.ted.europa.eu/v3/notices/search"), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        query:
          `buyer-country=FRA AND publication-date>=${since} ` +
          `AND notice-type IN (cn-standard cn-social) SORT BY publication-date DESC`,
        fields: [
          "publication-number",
          "notice-title",
          "buyer-name",
          "buyer-city",
          "publication-date",
          "deadline-receipt-tender-date-lot",
          "description-proc",
          "classification-cpv",
          "estimated-value-proc",
        ],
        page,
        limit: pageSize,
      }),
    });
    const notices = Array.isArray(body?.notices) ? body.notices : [];

    for (const n of notices) {
      const number = str(n["publication-number"]);
      const publishedAt = tedDate(n["publication-date"]);
      if (!number || !publishedAt) continue;

      const sourceUrl = httpUrl(n.links?.html?.FRA) ?? `https://ted.europa.eu/fr/notice/-/detail/${number}`;
      // Le titre TED est préfixé « Pays – Catégorie CPV – Objet » : on garde l'objet.
      const fullTitle = localized(n["notice-title"]) ?? "Avis de marché européen";
      const parts = fullTitle.split(" – ");
      const title = parts.length >= 3 ? parts.slice(2).join(" – ").trim() : fullTitle;
      const category = parts.length >= 3 ? parts[1].trim() : null;
      const description = localized(n["description-proc"]) ?? title;
      const deadlines = (Array.isArray(n["deadline-receipt-tender-date-lot"])
        ? n["deadline-receipt-tender-date-lot"]
        : [])
        .map(tedDate)
        .filter((d: string | null): d is string => d !== null)
        .sort();

      rows.push({
        id: `ted:${number}`,
        source: "ted",
        title,
        organization: localized(n["buyer-name"]) ?? "Acheteur public non précisé",
        summary: excerpt(description, 280),
        content: [`Objet : ${title}`, category ? `Catégorie : ${category}` : null, description]
          .filter(Boolean)
          .join("\n"),
        source_url: sourceUrl,
        published_at: publishedAt,
        deadline: deadlines[0] ?? null,
        estimated_budget: firstNumber(n["estimated-value-proc"]),
        region: localized(n["buyer-city"]),
        sector: category,
      });
    }

    if (notices.length < pageSize) break;
  }

  return rows;
}

// ---------------------------------------------------------------------------
// Embeddings
// ---------------------------------------------------------------------------

/** Doit rester identique à `LeadModel.toEmbeddingText()` côté Flutter. */
function toEmbeddingText(lead: LeadRow): string {
  return [
    lead.title,
    lead.organization,
    lead.sector ? `Secteur : ${lead.sector}` : null,
    lead.region ? `Région : ${lead.region}` : null,
    lead.summary,
  ].filter(Boolean).join("\n");
}

async function embedDocuments(texts: string[], apiKey: string): Promise<number[][]> {
  const model = `models/${EMBEDDING_MODEL}`;
  const body = await fetchJson(
    new URL(`https://generativelanguage.googleapis.com/v1beta/${model}:batchEmbedContents`),
    {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
      body: JSON.stringify({
        requests: texts.map((text) => ({
          model,
          content: { parts: [{ text }] },
          // RETRIEVAL_DOCUMENT ici, RETRIEVAL_QUERY côté app : Gemini optimise
          // l'espace vectoriel pour ce couple asymétrique.
          taskType: "RETRIEVAL_DOCUMENT",
          outputDimensionality: EMBEDDING_DIMENSIONS,
        })),
      }),
    },
  );

  const embeddings = Array.isArray(body?.embeddings) ? body.embeddings : [];
  if (embeddings.length !== texts.length) {
    throw new Error(`Gemini a renvoyé ${embeddings.length} embeddings pour ${texts.length} textes.`);
  }
  return embeddings.map((e: { values?: unknown }) => {
    if (!Array.isArray(e.values) || e.values.length !== EMBEDDING_DIMENSIONS) {
      throw new Error("Embedding Gemini de dimension inattendue.");
    }
    return e.values as number[];
  });
}

// ---------------------------------------------------------------------------
// Utilitaires
// ---------------------------------------------------------------------------

function parseSources(payload: unknown): Source[] {
  const raw = (payload as { sources?: unknown })?.sources;
  if (!Array.isArray(raw) || raw.length === 0) {
    throw new Error("Le corps doit contenir une liste `sources` non vide.");
  }
  const sources = [...new Set(raw)].filter((s): s is Source => ALL_SOURCES.includes(s as Source));
  if (sources.length !== new Set(raw).size) {
    throw new Error(`Sources acceptées : ${ALL_SOURCES.join(", ")}.`);
  }
  return sources;
}

// deno-lint-ignore no-explicit-any
async function fetchJson(url: URL, init: RequestInit = {}): Promise<any> {
  const response = await fetch(url, { ...init, signal: AbortSignal.timeout(FETCH_TIMEOUT_MS) });
  if (response.status === 429) {
    throw new QuotaExceededError(`${url.host} : quota dépassé (429).`);
  }
  if (!response.ok) {
    throw new Error(`${url.host} a répondu ${response.status} : ${(await response.text()).slice(0, 300)}`);
  }
  return response.json();
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function dedupe(leads: LeadRow[]): LeadRow[] {
  return [...new Map(leads.map((l) => [l.id, l])).values()];
}

function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

function str(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function strArray(value: unknown): string[] {
  return Array.isArray(value) ? value.map(str).filter((v): v is string => v !== null) : [];
}

/** Même règle que `LeadModel._httpUrl` : refuse `javascript:`, `intent:`… */
function httpUrl(value: unknown): string | null {
  const raw = str(value);
  if (!raw) return null;
  try {
    const url = new URL(raw);
    return url.protocol === "https:" || url.protocol === "http:" ? url.toString() : null;
  } catch {
    return null;
  }
}

function isoOrNull(value: unknown): string | null {
  const raw = str(value);
  if (!raw) return null;
  const date = new Date(raw);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

/** TED renvoie des dates « 2026-10-15+01:00 » (date + fuseau, sans heure). */
function tedDate(value: unknown): string | null {
  const raw = str(value);
  const match = raw?.match(/^(\d{4}-\d{2}-\d{2})(Z|[+-]\d{2}:\d{2})?$/);
  if (!match) return isoOrNull(raw);
  return isoOrNull(`${match[1]}T23:59:59${match[2] ?? "Z"}`);
}

/** Champs multilingues TED : `{ "fra": ["…"] }` ou `{ "fra": "…" }`. */
function localized(value: unknown): string | null {
  if (!value || typeof value !== "object") return null;
  const map = value as Record<string, unknown>;
  for (const lang of ["fra", "mul", "eng"]) {
    const entry = map[lang];
    const text = Array.isArray(entry) ? str(entry[0]) : str(entry);
    if (text) return text;
  }
  const first = Object.values(map)[0];
  return Array.isArray(first) ? str(first[0]) : str(first);
}

function firstNumber(value: unknown): number | null {
  const candidate = Array.isArray(value) ? value[0] : value;
  const n = typeof candidate === "string" ? Number(candidate) : candidate;
  return typeof n === "number" && Number.isFinite(n) && n > 0 ? n : null;
}

function excerpt(text: string, max: number): string {
  return text.length <= max ? text : `${text.slice(0, max)}…`;
}

function daysAgo(days: number): Date {
  return new Date(Date.now() - days * 86_400_000);
}

function isoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}
