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
        'guides/calendar',
        'guides/siri',
        'guides/widgets-notifications',
        'guides/templates-live-activity',
        'guides/productivity-features',
        'guides/cloud-ai',
        'guides/synthesis',
        'guides/subscriptions',
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
        'architecture/sessions',
        'architecture/calendar',
        'architecture/llm-inference',
        'architecture/siri',
      ],
    },
  ],
};

module.exports = sidebars;
