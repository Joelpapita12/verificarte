const { chromium } = require('playwright');

async function flutterLogin(page, email, pass) {
  await page.goto('https://verificarte.softapatio.mx/#/login', { waitUntil: 'networkidle' });
  await page.waitForTimeout(3000);
  await page.mouse.click(640, 265);
  await page.waitForTimeout(800);
  const emailInput = await page.$('flt-text-editing-host input');
  if (emailInput) await emailInput.type(email);
  await page.mouse.click(640, 329);
  await page.waitForTimeout(800);
  const passInput = await page.$('flt-text-editing-host input');
  if (passInput) await passInput.type(pass);
  await page.mouse.click(640, 391);
  await page.waitForTimeout(5000);
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  await page.setViewportSize({ width: 1280, height: 800 });
  
  await flutterLogin(page, 'jmjacobo2007@gmail.com', '12345678');
  await page.screenshot({ path: 'screenshots/debug_feed_loggedin.png' });
  console.log('URL after login:', page.url());
  
  // Click hamburger menu (top-left ~40,35)
  await page.mouse.click(40, 35);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: 'screenshots/debug_side_menu.png' });
  
  // Click hamburger again to close / try navigation
  // Navigate to create-post
  await page.goto('https://verificarte.softapatio.mx/#/create-post', { waitUntil: 'networkidle' });
  await page.waitForTimeout(3000);
  await page.screenshot({ path: 'screenshots/debug_create_post.png' });
  
  // Navigate to certificates
  await page.goto('https://verificarte.softapatio.mx/#/certificados', { waitUntil: 'networkidle' });
  await page.waitForTimeout(3000);
  await page.screenshot({ path: 'screenshots/debug_certificates.png' });
  
  // Navigate to transfers
  await page.goto('https://verificarte.softapatio.mx/#/transferencias', { waitUntil: 'networkidle' });
  await page.waitForTimeout(3000);
  await page.screenshot({ path: 'screenshots/debug_transfers.png' });
  
  // Navigate to profile
  await page.goto('https://verificarte.softapatio.mx/#/editar-perfil', { waitUntil: 'networkidle' });
  await page.waitForTimeout(3000);
  await page.screenshot({ path: 'screenshots/debug_profile.png' });
  
  // Navigate to reports
  await page.goto('https://verificarte.softapatio.mx/#/reports', { waitUntil: 'networkidle' });
  await page.waitForTimeout(3000);
  await page.screenshot({ path: 'screenshots/debug_reports.png' });
  
  // Navigate to admin
  await page.goto('https://verificarte.softapatio.mx/#/admin-panel', { waitUntil: 'networkidle' });
  await page.waitForTimeout(3000);
  await page.screenshot({ path: 'screenshots/debug_admin.png' });
  
  await browser.close();
  console.log('Done!');
})();
