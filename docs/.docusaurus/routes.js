import React from 'react';
import ComponentCreator from '@docusaurus/ComponentCreator';

export default [
  {
    path: '/pocketmind/',
    component: ComponentCreator('/pocketmind/', 'b0e'),
    routes: [
      {
        path: '/pocketmind/',
        component: ComponentCreator('/pocketmind/', 'ac5'),
        routes: [
          {
            path: '/pocketmind/',
            component: ComponentCreator('/pocketmind/', '529'),
            routes: [
              {
                path: '/pocketmind/architecture/calendar',
                component: ComponentCreator('/pocketmind/architecture/calendar', '620'),
                exact: true,
                sidebar: "architecture"
              },
              {
                path: '/pocketmind/architecture/llm-inference',
                component: ComponentCreator('/pocketmind/architecture/llm-inference', '7c9'),
                exact: true,
                sidebar: "architecture"
              },
              {
                path: '/pocketmind/architecture/overview',
                component: ComponentCreator('/pocketmind/architecture/overview', '382'),
                exact: true,
                sidebar: "architecture"
              },
              {
                path: '/pocketmind/architecture/sessions',
                component: ComponentCreator('/pocketmind/architecture/sessions', 'dbd'),
                exact: true,
                sidebar: "architecture"
              },
              {
                path: '/pocketmind/architecture/siri',
                component: ComponentCreator('/pocketmind/architecture/siri', 'b2d'),
                exact: true,
                sidebar: "architecture"
              },
              {
                path: '/pocketmind/guides/calendar',
                component: ComponentCreator('/pocketmind/guides/calendar', '886'),
                exact: true,
                sidebar: "guides"
              },
              {
                path: '/pocketmind/guides/models',
                component: ComponentCreator('/pocketmind/guides/models', 'b7f'),
                exact: true,
                sidebar: "guides"
              },
              {
                path: '/pocketmind/guides/privacy',
                component: ComponentCreator('/pocketmind/guides/privacy', 'a91'),
                exact: true,
                sidebar: "guides"
              },
              {
                path: '/pocketmind/guides/sessions',
                component: ComponentCreator('/pocketmind/guides/sessions', '522'),
                exact: true,
                sidebar: "guides"
              },
              {
                path: '/pocketmind/guides/siri',
                component: ComponentCreator('/pocketmind/guides/siri', '4ea'),
                exact: true,
                sidebar: "guides"
              },
              {
                path: '/pocketmind/quickstart',
                component: ComponentCreator('/pocketmind/quickstart', '3e4'),
                exact: true,
                sidebar: "guides"
              },
              {
                path: '/pocketmind/',
                component: ComponentCreator('/pocketmind/', '0fa'),
                exact: true,
                sidebar: "guides"
              }
            ]
          }
        ]
      }
    ]
  },
  {
    path: '*',
    component: ComponentCreator('*'),
  },
];
