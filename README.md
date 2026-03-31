# LucidPal Documentation

> On-device AI calendar assistant for iOS — fully private, no cloud, powered by Qwen3.

**Live docs → [lucid-fabrics.github.io/lucidpal](https://lucid-fabrics.github.io/lucidpal/)**

---

## What's in here

This repo is the Docusaurus documentation site for [LucidPal](https://github.com/lucid-fabrics/lucidpal-dev).

| Section | Content |
|---------|---------|
| **Using LucidPal** | Calendar commands, Siri shortcuts, sessions, widgets, notifications, templates, models, privacy |
| **Architecture** | MVVM layers, LLM inference pipeline, calendar action system, session management, Siri intents |

---

## Run locally

```bash
git clone https://github.com/lucid-fabrics/lucidpal.git
cd lucidpal
npm install
npm start
```

Opens at `http://localhost:3000/lucidpal/`.

---

## Deploy

Docs deploy automatically to GitHub Pages on every push to `main` via the [deploy workflow](.github/workflows/deploy.yml).

---

## Contributing

1. Edit any `.md` file under `docs/`
2. Run `npm start` to preview
3. Open a PR — Pages updates on merge
