---
sidebar_position: 13
---

# Web Search

Ask LucidPal to search the web and get real-time results without leaving the app.

---

## Overview

LucidPal can query the web on your behalf and include results in its response. Three search providers are supported — one works out of the box with no configuration required.

| Provider     | Setup required            | Privacy                     |
| ------------ | ------------------------- | --------------------------- |
| DuckDuckGo   | None — works immediately  | No API key, HTML scrape     |
| Brave Search | Brave API key             | Requires free/paid API key  |
| SearXNG      | Self-hosted instance URL  | Full self-hosted privacy    |

---

## Enabling Web Search

**Simple mode** (default): Open [**Settings**](./settings) → **Data Sources** and flip the **Web Search** toggle. DuckDuckGo is used automatically — no further configuration required.

**Advanced mode**: Open [**Settings**](./settings) → **Data Sources** → **Web Search** to access the full configuration screen where you can:

1. Choose a provider.
2. If using **Brave Search**, paste your API key.
3. If using **SearXNG**, enter your instance URL (must be `https://`).

To switch to Advanced mode, tap the mode selector at the top of Settings.

---

## Using Web Search in Chat

Once enabled, ask naturally:

- "What's the weather in Montreal today?"
- "Search for the latest news on iOS 19"
- "Look up the price of AAPL stock"

LucidPal fetches up to 5 results, summarizes them, and cites sources inline.

:::note
The AI uses a two-pass approach: the first pass detects a search intent and fetches results; the second pass synthesizes the answer. The synthesis pass cannot trigger another web search — only one search round-trip occurs per message.
:::

---

## Provider Details

All providers use a **10-second request timeout**. If the provider does not respond in time, the search fails and the AI reports the error inline.

### DuckDuckGo

Zero-config. LucidPal scrapes DuckDuckGo's HTML search results using a mobile Safari user-agent. No account or API key needed.

### Brave Search

Requires a [Brave Search API](https://brave.com/search/api/) key (free tier available). Enter the key in [**Settings**](./settings) → **Web Search → Brave API Key**.

### SearXNG (Self-Hosted)

Point LucidPal at your own SearXNG instance. The instance must:
- Use `https://`
- Have **JSON format enabled** (`search.formats: [json]` in `settings.yml`)

:::tip
If you see "SearXNG JSON format is disabled", add `json` to the `search.formats` list in your SearXNG `settings.yml` and restart the container.
:::

---

## Privacy

Web search queries are sent to the chosen provider — DuckDuckGo, Brave, or your own SearXNG server. No queries are sent to Anthropic or any LucidPal backend. The on-device model synthesizes the results locally.
