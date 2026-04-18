---
id: privacy-policy
title: Privacy Policy
sidebar_label: Privacy Policy
---

# Privacy Policy

**Effective Date:** April 18, 2026  
**Last Updated:** April 18, 2026

LucidPal ("we", "our", "us") is committed to protecting your privacy. This Privacy Policy explains what data we collect, how we use it, and your rights — wherever you are in the world.

---

## 1. Who We Are

LucidPal is an AI-powered personal assistant iOS app. Contact: wassimmehanna@gmail.com

---

## 2. Data We Collect

### 2.1 Account Data

When you sign in, we collect:

| Source | Data Collected |
|--------|---------------|
| Google Sign-In | Email address, display name (used to create your account) |
| Apple Sign-In | Email address (may be hidden relay), full name (optional) |

We exchange these identity tokens for a LucidPal session token (JWT) stored securely in your device's Keychain. We do not store your Google or Apple passwords.

### 2.2 Content You Create

All content you generate in the app — chat messages, sessions, notes, habits, conversation templates, AI memory entries, and pinned prompts — belongs to you. It is stored:

- **Locally on your device** (JSON files in your app's Documents directory with iOS file protection)
- **On our servers** only if you have a Starter or higher subscription and enable cloud sync

### 2.3 File Attachments

Notes attachments (JPEG, PNG, HEIC, M4A, PDF — max 50 MB each) are uploaded to our cloud storage (Cloudflare R2) when you attach them to a note. These files are linked to your account.

### 2.4 Subscription & Billing

We use Apple's StoreKit for all purchases. We never see or store your payment card details. We receive a cryptographically signed transaction receipt from Apple, which we verify server-side to grant your subscription entitlement.

### 2.5 Device & App State

We generate a random device identifier (stored in UserDefaults) used solely for sync conflict resolution. We do not use it for tracking or advertising.

### 2.6 App Settings & Preferences

Your in-app settings (selected AI models, feature toggles, context size, temperature, etc.) are stored locally in UserDefaults. Some settings sync to your account to persist across devices.

---

## 3. Data We Do NOT Collect

The following data is processed **entirely on-device** and is **never sent to our servers**:

| Data Type | How It's Used |
|-----------|--------------|
| **Calendar events** | Read from EventKit to answer calendar questions in chat |
| **Reminders** | Read from EventKit for task management |
| **Contacts** | Looked up on-device for context in chat |
| **Health data** | Read from HealthKit for health insights (Ultimate tier) |
| **Microphone / Speech** | Used for on-device voice input via Apple's Speech framework |
| **Location** | Reverse-geocoded on-device to your city name only; city stored in UserDefaults and never transmitted |
| **AI inference (on-device models)** | All llama.cpp GGUF model inference runs fully on-device |

We have **no analytics SDK, no crash reporting service, and no advertising framework** integrated in this app.

---

## 4. Third-Party Integrations (Optional)

These integrations are entirely optional and user-initiated:

### Gmail (Pro+)
- We request `gmail.readonly` and `gmail.send` scopes
- We fetch your 10 most recent email subjects, senders, and snippets to answer questions in chat
- We can send emails on your behalf when you explicitly request it
- Email content is never stored on our servers; it is fetched live and processed in your current chat session
- Your Google OAuth token is managed by the Google Sign-In SDK on your device

### Microsoft Exchange / Outlook (Pro+)
- OAuth tokens are stored in your device's Keychain
- We connect to Microsoft's Graph API on your behalf
- We never store your Exchange emails on our servers

### Immich (Pro+)
- Self-hosted only — you provide the server URL and API key
- Your Immich API key is stored in your device's Keychain
- We communicate directly with your self-hosted server; no data passes through ours

### Web Search
- **DuckDuckGo**: Queries sent directly to DuckDuckGo's HTML endpoint; no API key required
- **Brave Search**: Your Brave API key is stored in your device's Keychain; queries sent to Brave's API
- **SearXNG**: Your self-hosted instance; queries sent directly to your server

---

## 5. Cloud AI (Gemini 2.0 Flash)

When you use Cloud AI (Starter+ tier), your chat messages are sent to our backend (`api.lucidpal.app`), which forwards them to Google's Gemini 2.0 Flash API to generate a response. We do not store your messages on our servers beyond what is needed to serve the streaming response. Google's privacy policy applies to data processed by Gemini.

---

## 6. How We Use Your Data

| Purpose | Data Used |
|---------|-----------|
| Provide the app and its features | Account data, chat history (synced), attachments |
| Verify your subscription | StoreKit transaction receipts |
| Cloud sync across devices | Encrypted content (notes, habits, sessions, AI memory) |
| Authenticate you | JWT stored in Keychain |
| Improve AI context | AI memory entries (Ultimate tier) |

We do not sell your data. We do not use your data for advertising. We do not share your data with third parties except as described in this policy (authentication providers, Cloudflare R2 for storage, Google Gemini for cloud AI responses).

---

## 7. Data Retention

- **Account data**: Retained while your account is active
- **Chat history (synced)**: Retained until you delete it or close your account
- **Notes and attachments**: Retained until you delete them or close your account
- **AI memory**: Retained until you delete individual entries or close your account
- **Subscriptions**: Transaction records retained as required by Apple and applicable law

You can delete all cloud data at any time via **Settings → Data Export & Deletion**.

---

## 8. Data Security

- All data in transit uses HTTPS/TLS
- Sensitive tokens (JWT, OAuth tokens, API keys) stored in iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- Notes files use `.completeFileProtection` (encrypted at rest, inaccessible when device is locked)
- Cloud-synced records are encrypted client-side with AES-GCM before transmission

---

## 9. Your Rights

### All Users
- **Access**: Request a copy of your data via Settings → Data Export
- **Deletion**: Delete your account and all associated cloud data via Settings

### European Union (GDPR)
If you are in the EU, you have the right to:
- Access, rectify, or erase your personal data
- Restrict or object to processing
- Data portability
- Lodge a complaint with your national data protection authority

Legal basis for processing: **Contract performance** (providing the service you purchased) and **Legitimate interests** (security, fraud prevention).

### California (CCPA / CPRA)
If you are a California resident:
- You have the right to know what personal information we collect and how it's used
- You have the right to delete your personal information
- We do **not** sell or share your personal information for cross-context behavioral advertising

### Other Jurisdictions
We respect applicable privacy laws globally. Contact us at wassimmehanna@gmail.com for jurisdiction-specific requests.

---

## 10. Children's Privacy

LucidPal is not directed at children under 13 (or under 16 in the EU). We do not knowingly collect personal data from children. If you believe a child has provided us with personal data, contact us and we will delete it.

---

## 11. Changes to This Policy

We will notify you of material changes via an in-app notice or email. Continued use after the effective date constitutes acceptance.

---

## 12. Contact

**Email:** wassimmehanna@gmail.com  
**App:** LucidPal on the Apple App Store
