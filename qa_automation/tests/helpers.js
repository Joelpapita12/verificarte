const fs = require('fs');
const path = require('path');

const BASE_URL = 'https://verificarte.softapatio.mx';
const ARTISTA_EMAIL = 'jmjacobo2007@gmail.com';
const ARTISTA_PASS = '12345678';
const PROPIETARIO_EMAIL = 'test_propietario_qa@mailinator.com';
const PROPIETARIO_PASS = 'TestPass123!';

const SCREENSHOTS_DIR = path.join(__dirname, '..', 'screenshots');

// Tap a coordinate to activate a Flutter text field, then type into the real HTML input
async function flutterType(page, x, y, text) {
  await page.mouse.click(x, y);
  await page.waitForTimeout(900);
  const input = await page.$('flt-text-editing-host input, flt-text-editing-host textarea');
  if (input) {
    await input.evaluate(el => { el.focus(); el.select(); el.value = ''; });
    await input.type(text, { delay: 40 });
    await page.waitForTimeout(400);
    return true;
  }
  return false;
}

async function screenshot(page, name) {
  const filePath = path.join(SCREENSHOTS_DIR, `${name}.png`);
  await page.screenshot({ path: filePath, fullPage: false });
  return filePath;
}

// Login using confirmed Flutter coordinate-based interaction
async function loginAs(page, email, password) {
  await page.goto(`${BASE_URL}/#/login`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(3000);
  await flutterType(page, 640, 265, email);
  await flutterType(page, 640, 329, password);
  await page.mouse.click(640, 391); // "Ingresar" button
  await page.waitForTimeout(5000);
}

// Clear session storage to log out reliably in Flutter web
async function logout(page) {
  await page.evaluate(() => {
    localStorage.clear();
    sessionStorage.clear();
    window.location.href = window.location.origin + '/';
  });
  await page.waitForLoadState('networkidle');
  await page.waitForTimeout(3000);
}

// Open the side drawer menu (hamburger at top-left)
async function openMenu(page) {
  await page.mouse.click(40, 35);
  await page.waitForTimeout(1000);
}

function saveResult(prueba, tipo, descripcion, resultado, desviacion = '') {
  const resultsFile = path.join(__dirname, '..', 'results', 'test_results.json');
  let results = [];
  if (fs.existsSync(resultsFile)) {
    try { results = JSON.parse(fs.readFileSync(resultsFile, 'utf8')); } catch (_) {}
  }
  // Remove previous result for this test if exists
  results = results.filter(r => r.prueba !== prueba);
  results.push({ prueba, tipo, descripcion, resultado, desviacion, fecha: new Date().toISOString().split('T')[0] });
  // Sort by prueba number
  results.sort((a, b) => parseInt(a.prueba) - parseInt(b.prueba));
  fs.writeFileSync(resultsFile, JSON.stringify(results, null, 2));
}

module.exports = {
  BASE_URL, ARTISTA_EMAIL, ARTISTA_PASS, PROPIETARIO_EMAIL, PROPIETARIO_PASS,
  flutterType, screenshot, loginAs, logout, openMenu, saveResult
};
