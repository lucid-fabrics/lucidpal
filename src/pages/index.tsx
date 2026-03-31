import type {ReactNode} from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';

import styles from './index.module.css';

const features = [
  {
    icon: '🔒',
    title: 'Fully On-Device',
    description: 'Model runs in your iPhone\'s RAM. No internet connection, no API keys, no data ever leaves your phone.',
  },
  {
    icon: '📅',
    title: 'Calendar Read & Write',
    description: 'Create, rename, delete, and look up events. Ask naturally — "add a dentist at 3pm Friday" — and it appears instantly in the iOS Calendar app.',
  },
  {
    icon: '🎙️',
    title: 'Voice Input',
    description: 'Tap the mic and speak. WhisperKit transcribes on-device, no audio ever sent to a server.',
  },
  {
    icon: '⏱️',
    title: 'Free Time Finder',
    description: 'Ask "when am I free this afternoon?" and LucidPal checks your calendar for conflicts automatically.',
  },
  {
    icon: '⚡',
    title: 'Siri Shortcuts',
    description: 'Ask a question, check your schedule, add an event, or find free time — all hands-free from Siri or the Shortcuts app.',
  },
  {
    icon: '📌',
    title: 'Pinned Prompts',
    description: 'Save frequently used questions as chips above the input bar. One tap to reuse in any session.',
  },
];

const models = [
  {
    name: '0.8B',
    size: '0.51 GB',
    badge: '2–3 GB RAM',
    badgeClass: styles.badgeBlue,
    desc: 'Q4_K_M — fast, minimal footprint',
  },
  {
    name: '2B',
    size: '1.2 GB',
    badge: 'Recommended',
    badgeClass: styles.badgeGreen,
    recommended: true,
    desc: 'Q4_K_M — best balance of speed and quality',
  },
  {
    name: '4B',
    size: '2.5 GB',
    badge: '5 GB+ RAM',
    badgeClass: styles.badgeIndigo,
    desc: 'Q4_K_M — highest quality, iPhone Pro class',
  },
];

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <header className={styles.heroBanner}>
      <div className="container">
        <Heading as="h1" className={styles.heroTitle}>
          {siteConfig.title}
        </Heading>
        <p className={styles.heroSubtitle}>{siteConfig.tagline}</p>
        <div className={styles.heroMeta}>
          <span className={styles.heroPill}>🔒 Zero telemetry</span>
          <span className={styles.heroPill}>📵 No internet required</span>
          <span className={styles.heroPill}>🆓 Free, open source</span>
        </div>
        <div className={styles.buttons}>
          <Link className="button button--primary button--lg" to="/introduction">
            Read the Docs
          </Link>
          <Link
            className="button button--secondary button--lg"
            href="https://github.com/lucid-fabrics/lucidpal">
            GitHub
          </Link>
        </div>
        <p className={styles.appStoreComing}>App Store release coming soon</p>
      </div>
    </header>
  );
}

function Features() {
  return (
    <section className={styles.features}>
      <div className="container">
        <Heading as="h2" className={styles.sectionTitle}>
          Everything You Need
        </Heading>
        <p className={styles.sectionSubtitle}>
          A pocket AI that actually respects your privacy
        </p>
        <div className={styles.featureGrid}>
          {features.map((f, i) => (
            <div key={i} className={styles.featureCard}>
              <div className={styles.featureIcon}>{f.icon}</div>
              <div className={styles.featureTitle}>{f.title}</div>
              <div className={styles.featureDesc}>{f.description}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function Stats() {
  return (
    <section className={styles.statsBar}>
      <div className={styles.statsGrid}>
        <div className={styles.statItem}>
          <div className={styles.statValue}>3</div>
          <div className={styles.statLabel}>Model Sizes</div>
        </div>
        <div className={styles.statItem}>
          <div className={styles.statValue}>0</div>
          <div className={styles.statLabel}>API Keys Needed</div>
        </div>
        <div className={styles.statItem}>
          <div className={styles.statValue}>iOS 16</div>
          <div className={styles.statLabel}>Minimum</div>
        </div>
        <div className={styles.statItem}>
          <div className={styles.statValue}>100%</div>
          <div className={styles.statLabel}>On-Device</div>
        </div>
      </div>
    </section>
  );
}

function Models() {
  return (
    <section className={styles.modelsSection}>
      <div className="container">
        <Heading as="h2" className={styles.sectionTitle}>
          Choose Your Model
        </Heading>
        <p className={styles.sectionSubtitle}>
          LucidPal recommends the right size automatically based on your device RAM
        </p>
        <div className={styles.modelGrid}>
          {models.map((m, i) => (
            <div key={i} className={clsx(styles.modelCard, m.recommended && styles.recommended)}>
              <div className={styles.modelName}>Qwen3.5 {m.name}</div>
              <div className={styles.modelSize}>{m.size}</div>
              <div className={styles.modelDesc}>{m.desc}</div>
              <span className={clsx(styles.modelBadge, m.badgeClass)}>{m.badge}</span>
            </div>
          ))}
        </div>
        <p className={styles.modelNote}>
          <Link to="/guides/models">Compare models in detail →</Link>
        </p>
      </div>
    </section>
  );
}

function Privacy() {
  return (
    <section className={styles.privacySection}>
      <div className="container">
        <Heading as="h2" className={styles.sectionTitle}>
          Under the Hood
        </Heading>
        <p className={styles.sectionSubtitle}>
          Everything stays on your device, from mic to response
        </p>
        <div className={styles.privacyDiagram}>
          <div className={styles.privacyFlow}>
            <span className={clsx(styles.privacyStep, styles.privacyStepHighlight)}>Your Voice</span>
            <span className={styles.privacyArrow}>→</span>
            <span className={clsx(styles.privacyStep, styles.privacyStepNormal)}>WhisperKit</span>
            <span className={styles.privacyArrow}>→</span>
            <span className={clsx(styles.privacyStep, styles.privacyStepNormal)}>Qwen3.5</span>
            <span className={styles.privacyArrow}>→</span>
            <span className={clsx(styles.privacyStep, styles.privacyStepNormal)}>EventKit</span>
            <span className={styles.privacyArrow}>→</span>
            <span className={clsx(styles.privacyStep, styles.privacyStepHighlight)}>Response</span>
          </div>
          <p className={styles.privacyNote}>
            No network request is made at any step. Your mic audio is discarded after transcription.
          </p>
        </div>
        <p style={{marginTop: '1.5rem', textAlign: 'center'}}>
          <Link to="/guides/privacy">Read the full privacy guide →</Link>
        </p>
      </div>
    </section>
  );
}

function CTA() {
  return (
    <section className={styles.ctaSection}>
      <div className="container">
        <Heading as="h2" className={styles.ctaTitle}>
          Your pocket AI, ready the moment you open it.
        </Heading>
        <p className={styles.ctaSubtitle}>
          No login. No subscription. No internet. Just ask.
        </p>
        <div className={styles.buttons}>
          <Link className="button button--primary button--lg" to="/introduction">
            Get Started
          </Link>
          <Link
            className="button button--secondary button--lg"
            href="https://github.com/lucid-fabrics/lucidpal">
            View Source
          </Link>
        </div>
      </div>
    </section>
  );
}

export default function Home(): ReactNode {
  return (
    <Layout
      title="On-Device AI Calendar Assistant"
      description="LucidPal — private, on-device AI assistant for iOS with native calendar access. Powered by Qwen3.5 and llama.cpp.">
      <HomepageHeader />
      <main>
        <Features />
        <Stats />
        <Models />
        <Privacy />
        <CTA />
      </main>
    </Layout>
  );
}
