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
        'guides/agent-mode',
        'guides/siri',
        'guides/widgets-notifications',
        'guides/templates-live-activity',
        'guides/productivity-features',
        'guides/settings',
        'guides/premium',
        'guides/privacy',
        'guides/accessibility',
      ],
    },
    {
      type: 'category',
      label: 'Legal',
      collapsed: true,
      items: [
        'legal/privacy-policy',
        'legal/terms-of-service',
        'legal/eula',
      ],
    },
  ],
};

module.exports = sidebars;
