const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  timeout: 60000,
  retries: 0,
  workers: 1,
  use: {
    baseURL: 'https://verificarte.softapatio.mx',
    headless: true,
    viewport: { width: 1280, height: 800 },
    ignoreHTTPSErrors: true,
    screenshot: 'on',
    video: 'off',
    locale: 'es-MX',
  },
  reporter: [
    ['list'],
    ['json', { outputFile: 'results/results.json' }],
  ],
});
