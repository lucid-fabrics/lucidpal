---
sidebar_position: 21
---

# API Access

LucidPal gives you a personal API key so you can query your own data and send AI messages from scripts, automations, or any tool that can make HTTP requests.

## What you can do with it

- Read your notes and habits from external tools (Shortcuts, Zapier, Python scripts, etc.)
- Send AI messages programmatically and get responses back
- Build your own dashboards or automations on top of your LucidPal data

## Getting your API key

1. Open **Settings** in LucidPal.
2. Scroll to **API Access** and tap **Generate API Key**.
3. Your key is shown once — copy it somewhere safe. If you lose it, you can regenerate a new one (the old key is immediately revoked).

:::warning Keep your key private
Anyone with your API key can read your notes, habits, and send AI messages on your behalf. Do not share it or commit it to version control.
:::

## Making requests

All API requests go to `https://api.lucidpal.app/v1/` with your key in the `Authorization` header.

```bash
curl https://api.lucidpal.app/v1/notes \
  -H "Authorization: Bearer YOUR_API_KEY"
```

## Available endpoints

| Method | Endpoint | What it returns |
|--------|----------|----------------|
| `GET` | `/v1/notes` | All your notes (id, title, content, tags, dates) |
| `GET` | `/v1/habits` | Your habits and today's completion status |
| `POST` | `/v1/ai/chat` | Send a message to LucidPal AI, get a response |

### GET /v1/notes

Returns all non-deleted notes.

```bash
curl https://api.lucidpal.app/v1/notes \
  -H "Authorization: Bearer YOUR_API_KEY"
```

```json
[
  {
    "id": "uuid",
    "title": "Meeting notes",
    "content": "...",
    "tags": ["work", "q3"],
    "created_at": "2026-04-01T09:00:00Z",
    "updated_at": "2026-04-10T14:23:00Z"
  }
]
```

### GET /v1/habits

Returns your habit definitions and whether each one is completed today.

```bash
curl https://api.lucidpal.app/v1/habits \
  -H "Authorization: Bearer YOUR_API_KEY"
```

```json
[
  {
    "id": "uuid",
    "name": "Morning run",
    "emoji": "🏃",
    "frequency": "daily",
    "completed_today": true
  }
]
```

### POST /v1/ai/chat

Send a message to the AI and get a response.

```bash
curl https://api.lucidpal.app/v1/ai/chat \
  -X POST \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"message": "Summarize my notes from this week"}'
```

```json
{
  "reply": "Here's a summary of your notes from this week: ..."
}
```

## Rate limits

| Limit | Value |
|-------|-------|
| Requests per day | 1,000 |
| Requests per minute | 60 |

When you exceed the daily limit, requests return `429 Too Many Requests`. The counter resets at midnight UTC.

## Revoking your key

To revoke your key, tap **Revoke** in **Settings → API Access**. This immediately invalidates the key. You can generate a new one at any time.

## Example: daily notes summary with a cron job

```bash
#!/bin/bash
# Run daily at 8am to get an AI summary of recent notes

RESPONSE=$(curl -s https://api.lucidpal.app/v1/ai/chat \
  -X POST \
  -H "Authorization: Bearer $LUCIDPAL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"message": "What are the 3 most important things from my notes this week?"}')

echo "$RESPONSE" | jq -r '.reply'
```

## Example: check habit status from Shortcuts

You can use the **Shortcuts** app to call the API and display your habit completion in a widget or notification.

1. Add a **Get Contents of URL** action pointing to `https://api.lucidpal.app/v1/habits`
2. Add the header `Authorization: Bearer YOUR_API_KEY`
3. Parse the JSON response with a **Get Dictionary Value** action
4. Show the result in a notification or widget
