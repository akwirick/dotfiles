#!/usr/bin/env bun
// Extracts Granola meeting data for a given date range.
// Primary: Granola API (WorkOS token). Fallback: local cache with panels + transcripts.
//
// Usage: bun granola.ts <start-date> <end-date>
// Dates in YYYY-MM-DD format. Outputs JSON to stdout.

import { readFileSync, readdirSync } from "fs";
import { join } from "path";
import { homedir } from "os";

const [startDate, endDate] = process.argv.slice(2);
if (!startDate || !endDate) {
  console.error("Usage: bun granola.ts <start-date> <end-date>");
  process.exit(1);
}

const startTs = new Date(`${startDate}T00:00:00Z`).getTime();
const endTs = new Date(`${endDate}T23:59:59Z`).getTime();

const appSupport = join(homedir(), "Library/Application Support/Granola");

// Find the highest-versioned cache file
function findCachePath(): string {
  try {
    const files = readdirSync(appSupport).filter((f) =>
      /^cache-v\d+\.json$/.test(f)
    );
    files.sort((a, b) => {
      const va = parseInt(a.match(/v(\d+)/)?.[1] ?? "0");
      const vb = parseInt(b.match(/v(\d+)/)?.[1] ?? "0");
      return vb - va;
    });
    return join(appSupport, files[0] ?? "cache-v6.json");
  } catch {
    return join(appSupport, "cache-v6.json");
  }
}

// Read WorkOS access token (the correct auth for Granola API)
function getWorkOSToken(): string | undefined {
  try {
    const raw = JSON.parse(readFileSync(join(appSupport, "supabase.json"), "utf-8"));
    const workos = JSON.parse(raw.workos_tokens ?? "{}");
    return workos.access_token;
  } catch {
    return undefined;
  }
}

// Strip HTML tags to plain text
function htmlToText(html: string): string {
  return html
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/?(p|div|li|h[1-6])[^>]*>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

// Extract text from ProseMirror nodes
function pmToText(node: any): string {
  if (!node) return "";
  if (typeof node === "string") return node;
  if (node.text) return node.text;
  if (node.content && Array.isArray(node.content)) {
    return node.content
      .map((c: any) => {
        const t = pmToText(c);
        if (c.type === "heading") return `## ${t}\n`;
        if (c.type === "paragraph") return t + "\n";
        if (c.type === "listItem") return `- ${t}\n`;
        return t;
      })
      .join("");
  }
  return "";
}

function truncate(s: string, max: number): string {
  return s.length > max ? s.substring(0, max) + "..." : s;
}

// --- API approach ---

async function fetchFromAPI(token: string): Promise<any[] | null> {
  try {
    const resp = await fetch("https://api.granola.ai/v2/get-documents", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
        "User-Agent": "Granola/5.354.0",
        "X-Client-Version": "5.354.0",
      },
      body: JSON.stringify({ limit: 200, offset: 0, include_last_viewed_panel: true }),
    });

    if (!resp.ok) {
      console.error(`Granola API: ${resp.status} ${resp.statusText}`);
      return null;
    }

    const data = (await resp.json()) as any;
    const docs = data.docs ?? data.documents ?? data;
    if (!Array.isArray(docs)) {
      console.error("Granola API: unexpected response shape");
      return null;
    }

    return docs
      .filter((doc: any) => {
        if (!doc.created_at) return false;
        const ts = new Date(doc.created_at).getTime();
        return ts >= startTs && ts <= endTs && !doc.deleted_at;
      })
      .map((doc: any) => ({
        title: doc.title ?? "(untitled)",
        date: doc.created_at,
        start: doc.google_calendar_event?.start?.dateTime ?? doc.google_calendar_event?.start?.date,
        end: doc.google_calendar_event?.end?.dateTime ?? doc.google_calendar_event?.end?.date,
        attendees: doc.google_calendar_event?.attendees?.map(
          (a: any) => a.displayName ?? a.email
        ),
        notes: truncate(doc.markdown || doc.notes_markdown || doc.notes_plain || "", 3000) || undefined,
        summary: truncate(doc.summary || "", 1500) || undefined,
        source: "api",
      }));
  } catch (err: any) {
    console.error(`Granola API failed: ${err.message}`);
    return null;
  }
}

// --- Local cache approach ---

function readFromCache(): any[] {
  const cachePath = findCachePath();
  let cache: any;
  try {
    const raw = JSON.parse(readFileSync(cachePath, "utf-8"));
    // Handle double-encoded JSON (some versions wrap cache.state in a string)
    const cacheObj = typeof raw.cache === "string" ? JSON.parse(raw.cache) : raw.cache;
    cache = cacheObj?.state ?? cacheObj;
  } catch (err: any) {
    console.error(`Could not read Granola cache: ${err.message}`);
    return [];
  }

  const documents = cache?.documents ?? {};
  const panels = cache?.documentPanels ?? {};
  const transcriptStore = cache?.transcripts ?? {};
  const metadata = cache?.meetingsMetadata ?? {};

  const meetings: any[] = [];

  for (const [id, doc] of Object.entries(documents) as [string, any][]) {
    if (!doc.created_at || doc.type !== "meeting") continue;
    const docTs = new Date(doc.created_at).getTime();
    if (docTs < startTs || docTs > endTs) continue;
    if (doc.deleted_at || doc.was_trashed) continue;

    const cal = doc.google_calendar_event;

    // Notes from ProseMirror
    let notes = doc.notes_markdown || doc.notes_plain || pmToText(doc.notes) || "";

    // AI summary from documentPanels
    let summary = "";
    const docPanels = panels[id];
    if (docPanels && typeof docPanels === "object") {
      for (const panel of Object.values(docPanels) as any[]) {
        const content = panel?.original_content || panel?.content;
        if (content && typeof content === "string" && content.length > 10) {
          summary = htmlToText(content);
          break;
        }
      }
    }

    // Transcript
    let transcript = "";
    const segs = transcriptStore[id];
    if (Array.isArray(segs) && segs.length > 0) {
      transcript = segs
        .map((s: any) => `${s.source ?? "?"}: ${s.text}`)
        .join("\n");
    }

    // Metadata attendees (sometimes richer than cal event)
    const meta = metadata[id];
    const attendees =
      cal?.attendees?.map((a: any) => a.displayName ?? a.email) ??
      meta?.attendees?.map((a: any) => a.displayName ?? a.email);

    meetings.push({
      title: doc.title ?? "(untitled)",
      date: doc.created_at,
      start: cal?.start?.dateTime ?? cal?.start?.date,
      end: cal?.end?.dateTime ?? cal?.end?.date,
      attendees,
      notes: truncate(notes.trim(), 3000) || undefined,
      summary: truncate(summary, 1500) || undefined,
      transcript: truncate(transcript, 2000) || undefined,
      source: "cache",
    });
  }

  return meetings;
}

// --- Main ---

async function main() {
  const token = getWorkOSToken();
  let meetings: any[] | null = null;

  if (token) {
    meetings = await fetchFromAPI(token);
  }

  if (!meetings) {
    console.error("Falling back to local cache");
    meetings = readFromCache();
  }

  meetings.sort(
    (a: any, b: any) => new Date(a.date).getTime() - new Date(b.date).getTime()
  );

  console.log(
    JSON.stringify(
      {
        range: { start: startDate, end: endDate },
        count: meetings.length,
        meetings,
      },
      null,
      2
    )
  );
}

main();
