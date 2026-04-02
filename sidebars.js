/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  guides: [
    'introduction',
    {
      type: 'category',
      label: 'Using LucidPal',
      collapsed: false,
      items: [
        'guides/calendar',
        'guides/siri',
        'guides/sessions',
        'guides/productivity-features',
        'guides/widgets-notifications',
        'guides/templates-live-activity',
        'guides/models',
        'guides/vision-photos',
        'guides/privacy',
        'guides/notes',
        'guides/document-summarization',
        'guides/contacts',
        'guides/habit-tracker',
        'guides/reminders',
        'guides/web-search',
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
        'architecture/llm-inference',
        'architecture/calendar',
        'architecture/sessions',
        'architecture/siri',
        'architecture/note-enrichment',
        'architecture/system-prompt',
      ],
    },
  ],
};

module.exports = sidebars;
