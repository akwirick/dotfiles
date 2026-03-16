#!/usr/bin/env bun
// Searches Slack messages sent by the user in a date range.
// Token is read from macOS Keychain. Service name comes from config.json.
//
// Usage: bun slack.ts <start-date> <end-date>
// Dates in YYYY-MM-DD format. Outputs JSON to stdout.

import { execSync } from "child_process";
import { readFileSync } from "fs";
import { join, dirname } from "path";

const scriptDir = dirname(Bun.main);

const [startDate, endDate] = process.argv.slice(2);
if (!startDate || !endDate) {
  console.error("Usage: bun slack.ts <start-date> <end-date>");
  process.exit(1);
}

// Read keychain service name from config
let keychainService = "weekly-wrap-slack";
try {
  const config = JSON.parse(readFileSync(join(scriptDir, "config.json"), "utf-8"));
  keychainService = config.slack?.keychain_service ?? keychainService;
} catch {}

// Read token from macOS Keychain
let token: string;
try {
  token = execSync(
    `security find-generic-password -s "${keychainService}" -w`,
    { encoding: "utf-8" }
  ).trim();
} catch {
  console.error(`Failed to read Slack token from Keychain (service: ${keychainService}). Add it with:`);
  console.error(`  security add-generic-password -a "weekly-wrap" -s "${keychainService}" -w "xoxp-..." -U -A`);
  process.exit(1);
}

// Slack search query: messages from me in the date range
// after/before use YYYY-MM-DD format
const query = `from:me after:${startDate} before:${endDate}`;

interface SlackMessage {
  channel: string;
  channel_name?: string;
  text: string;
  ts: string;
  permalink?: string;
}

async function searchMessages(
  query: string,
  page = 1
): Promise<{ messages: SlackMessage[]; total: number; pages: number }> {
  const params = new URLSearchParams({
    query,
    sort: "timestamp",
    sort_dir: "asc",
    count: "100",
    page: String(page),
  });

  const resp = await fetch(
    `https://slack.com/api/search.messages?${params}`,
    {
      headers: { Authorization: `Bearer ${token}` },
    }
  );

  if (!resp.ok) {
    throw new Error(`Slack API: ${resp.status} ${resp.statusText}`);
  }

  const data = (await resp.json()) as any;
  if (!data.ok) {
    throw new Error(`Slack API error: ${data.error}`);
  }

  const matches = data.messages?.matches ?? [];
  return {
    messages: matches.map((m: any) => ({
      channel: m.channel?.id,
      channel_name: m.channel?.name,
      text: m.text,
      ts: m.ts,
      permalink: m.permalink,
    })),
    total: data.messages?.total ?? 0,
    pages: data.messages?.paging?.pages ?? 1,
  };
}

// Resolve user IDs to display names (for DM channel names)
const userCache = new Map<string, string>();

async function resolveUser(userId: string): Promise<string> {
  if (userCache.has(userId)) return userCache.get(userId)!;
  try {
    const resp = await fetch(
      `https://slack.com/api/users.info?user=${userId}`,
      { headers: { Authorization: `Bearer ${token}` } }
    );
    const data = (await resp.json()) as any;
    const name =
      data.user?.profile?.display_name ||
      data.user?.real_name ||
      data.user?.name ||
      userId;
    userCache.set(userId, name);
    return name;
  } catch {
    return userId;
  }
}

// Check if a string looks like a Slack user ID (DM channel)
function isUserId(s: string): boolean {
  return /^U[A-Z0-9]{8,}$/.test(s);
}

async function main() {
  const allMessages: SlackMessage[] = [];
  let totalPages = 1;

  try {
    // First page
    const first = await searchMessages(query, 1);
    allMessages.push(...first.messages);
    totalPages = Math.min(first.pages, 5); // Cap at 5 pages (500 messages)

    // Remaining pages
    for (let page = 2; page <= totalPages; page++) {
      const next = await searchMessages(query, page);
      allMessages.push(...next.messages);
    }

    // Resolve DM user IDs to names
    const userIds = new Set<string>();
    for (const msg of allMessages) {
      const name = msg.channel_name ?? msg.channel ?? "";
      if (isUserId(name)) userIds.add(name);
    }
    await Promise.all([...userIds].map((id) => resolveUser(id)));

    // Group by channel (with resolved names)
    const byChannel: Record<string, { name: string; messages: any[] }> = {};
    for (const msg of allMessages) {
      let name = msg.channel_name ?? msg.channel ?? "unknown";
      if (isUserId(name)) {
        name = `DM: ${userCache.get(name) ?? name}`;
      }
      if (!byChannel[name]) {
        byChannel[name] = { name, messages: [] };
      }
      byChannel[name].messages.push({
        text:
          msg.text.length > 500
            ? msg.text.substring(0, 500) + "..."
            : msg.text,
        timestamp: msg.ts
          ? new Date(parseFloat(msg.ts) * 1000).toISOString()
          : undefined,
        permalink: msg.permalink,
      });
    }

    // Sort channels by message count (most active first)
    const channels = Object.values(byChannel).sort(
      (a, b) => b.messages.length - a.messages.length
    );

    console.log(
      JSON.stringify(
        {
          range: { start: startDate, end: endDate },
          query,
          total_messages: allMessages.length,
          channels,
        },
        null,
        2
      )
    );
  } catch (err: any) {
    console.error(`Slack search failed: ${err.message}`);
    process.exit(1);
  }
}

main();
