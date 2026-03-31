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
        'guides/voice-input',
        'guides/privacy',
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
        'architecture/turboquant',
        'architecture/calendar',
        'architecture/sessions',
        'architecture/siri',
      ],
    },
  ],
};

module.exports = sidebars;
