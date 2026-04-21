// @ts-check
const { themes } = require('prism-react-renderer');

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'PocketMind',
  tagline: 'On-device AI calendar assistant for iOS',
  favicon: 'img/favicon.ico',

  url: 'https://lucid-fabrics.github.io',
  baseUrl: '/pocketmind/',

  organizationName: 'lucid-fabrics',
  projectName: 'pocketmind',
  trailingSlash: false,

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          routeBasePath: '/',
          editUrl: 'https://github.com/lucid-fabrics/pocketmind/tree/main/docs/',
        },
        blog: false,
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      navbar: {
        title: 'PocketMind',
        items: [
          { type: 'docSidebar', sidebarId: 'guides', position: 'left', label: 'Guides' },
          { type: 'docSidebar', sidebarId: 'architecture', position: 'left', label: 'Architecture' },
          {
            href: 'https://github.com/lucid-fabrics/pocketmind',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        copyright: `© ${new Date().getFullYear()} PocketMind. Built with Docusaurus.`,
      },
      prism: {
        theme: themes.github,
        darkTheme: themes.dracula,
        additionalLanguages: ['swift', 'bash', 'json'],
      },
      colorMode: {
        defaultMode: 'light',
        respectPrefersColorScheme: true,
      },
    }),
};

module.exports = config;
