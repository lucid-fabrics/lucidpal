/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  guides: [
    'introduction',
    {
      type: 'category',
      label: 'Using LucidPal',
      collapsed: false,
      items: [
        'guides/sessions',
        'guides/models',
        'guides/voice-input',
        'guides/calendar',
        'guides/contacts',
        'guides/notes',
        'guides/habit-tracker',
        'guides/reminders',
        'guides/vision-photos',
        'guides/document-summarization',
        'guides/web-search',
        'guides/siri',
        'guides/widgets-notifications',
        'guides/templates-live-activity',
        'guides/productivity-features',
        'guides/settings',
        'guides/privacy',
        'guides/accessibility',
      ],
    },
  ],
  architecture: [
    {
      type: 'category',
      label: 'Architecture',
      collapsed: false,
      items: [
        'architecture/overview',
        'architecture/chat-viewmodel',
        'architecture/sessions',
        'architecture/calendar',
        'architecture/llm-inference',
        'architecture/turboquant',
        'architecture/system-prompt',
        'architecture/siri',
        'architecture/free-slot-engine',
        'architecture/habit-store',
        'architecture/notes-store',
        'architecture/note-enrichment',
        'architecture/model-download',
        'architecture/testing',
        'architecture/ci-cd',
      ],
    },
  ],
};

module.exports = sidebars;
