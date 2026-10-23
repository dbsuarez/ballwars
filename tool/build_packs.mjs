// Builds the built-in ball packs served from GitHub Pages:
//   web/packs/<group>/<ball>.svg   logos and flags
//   web/packs/packs.json           catalog the app reads
//   web/packs/LICENSES.md          where every image comes from
//
// Run from the repo root:  node tool/build_packs.mjs
// Sources, in order of preference for brands:
//   gilbarbara/logos  (CC0, full-color)        https://github.com/gilbarbara/logos
//   svgl              (official logos, MIT repo) https://svgl.app
//   simple-icons      (CC0, single-color, drawn in the brand color) https://simpleicons.org
// Countries: flag-icons (MIT) https://github.com/lipis/flag-icons
// Yes or No: drawn here (original).
// Ulam (Filipino food): photos from Wikimedia Commons under free licenses
// (CC BY / CC BY-SA / CC0 / public domain), credited in LICENSES.md.
// Logos remain trademarks of their owners; they are used to identify them.

import { mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { createHash } from 'node:crypto';

// Short content hash per image: the app re-downloads an image for offline use
// only when its hash changes.
const hashOf = (svg) => createHash('sha1').update(svg).digest('hex').slice(0, 10);

const SIMPLE_ICONS = '16.35.0';
const FLAG_ICONS = '7.6.0';
const OUT = 'web/packs';

const gb = (file) => ({ src: 'gilbarbara', url: `https://cdn.jsdelivr.net/gh/gilbarbara/logos@main/logos/${file}.svg` });
const svgl = (title) => ({ src: 'svgl', title });
const si = (title) => ({ src: 'simple-icons', title });

// [id, display name, source]
const GROUPS = [
  ['streaming', 'Streaming', [
    ['netflix', 'Netflix', gb('netflix-icon')],
    ['youtube', 'YouTube', gb('youtube-icon')],
    ['disney-plus', 'Disney+', svgl('Disney+')],
    ['prime-video', 'Prime Video', svgl('Prime video')],
    ['hulu', 'Hulu', svgl('Hulu')],
    ['hbo-max', 'HBO Max', si('HBO Max')],
    ['crunchyroll', 'Crunchyroll', si('Crunchyroll')],
    ['paramount-plus', 'Paramount+', si('Paramount+')],
    ['twitch', 'Twitch', gb('twitch')],
    ['apple-tv', 'Apple TV', si('Apple TV')],
  ]],
  ['shoes', 'Shoes', [
    ['nike', 'Nike', si('Nike')],
    ['adidas', 'Adidas', si('Adidas')],
    ['puma', 'Puma', si('Puma')],
    ['new-balance', 'New Balance', si('New Balance')],
    ['reebok', 'Reebok', si('Reebok')],
    ['under-armour', 'Under Armour', si('Under Armour')],
    ['fila', 'Fila', si('Fila')],
    ['jordan', 'Jordan', si('Jordan')],
  ]],
  ['laptops', 'Laptops', [
    ['asus', 'ASUS', si('ASUS')],
    ['acer', 'Acer', si('Acer')],
    ['dell', 'Dell', si('Dell')],
    ['hp', 'HP', si('HP')],
    ['lenovo', 'Lenovo', si('Lenovo')],
    ['apple', 'Apple', gb('apple')],
    ['msi', 'MSI', si('MSI')],
    ['razer', 'Razer', si('Razer')],
    ['microsoft', 'Microsoft', gb('microsoft-icon')],
    ['samsung', 'Samsung', gb('samsung')],
    ['huawei', 'Huawei', si('Huawei')],
    ['toshiba', 'Toshiba', si('Toshiba')],
  ]],
  ['phones', 'Phones', [
    ['samsung', 'Samsung', gb('samsung')],
    ['apple', 'Apple', gb('apple')],
    ['xiaomi', 'Xiaomi', si('Xiaomi')],
    ['oppo', 'OPPO', si('OPPO')],
    ['vivo', 'vivo', si('vivo')],
    ['huawei', 'Huawei', si('Huawei')],
    ['google', 'Google', gb('google-icon')],
    ['oneplus', 'OnePlus', si('OnePlus')],
    ['nokia', 'Nokia', si('Nokia')],
    ['motorola', 'Motorola', si('Motorola')],
    ['honor', 'Honor', si('Honor')],
    ['sony', 'Sony', si('Sony')],
  ]],
  ['ai', 'AI', [
    ['chatgpt', 'ChatGPT', gb('openai-icon')],
    ['gemini', 'Gemini', svgl('Gemini')],
    ['grok', 'Grok', svgl('Grok')],
    ['claude', 'Claude', gb('claude-icon')],
    ['copilot', 'Copilot', svgl('Microsoft Copilot')],
    ['meta-ai', 'Meta AI', gb('meta-icon')],
    ['perplexity', 'Perplexity', gb('perplexity-icon')],
    ['deepseek', 'DeepSeek', si('DeepSeek')],
    ['mistral', 'Mistral', gb('mistral-ai-icon')],
    ['midjourney', 'Midjourney', gb('midjourney')],
  ]],
  ['social', 'Social Media', [
    ['facebook', 'Facebook', gb('facebook')],
    ['instagram', 'Instagram', gb('instagram-icon')],
    ['tiktok', 'TikTok', gb('tiktok-icon')],
    ['x', 'X', gb('x')],
    ['youtube', 'YouTube', gb('youtube-icon')],
    ['snapchat', 'Snapchat', si('Snapchat')],
    ['reddit', 'Reddit', gb('reddit-icon')],
    ['pinterest', 'Pinterest', gb('pinterest')],
    ['threads', 'Threads', si('Threads')],
    ['linkedin', 'LinkedIn', gb('linkedin-icon')],
    ['discord', 'Discord', gb('discord-icon')],
  ]],
  ['messaging', 'Messaging', [
    ['whatsapp', 'WhatsApp', gb('whatsapp-icon')],
    ['messenger', 'Messenger', gb('messenger')],
    ['telegram', 'Telegram', gb('telegram')],
    ['viber', 'Viber', si('Viber')],
    ['signal', 'Signal', gb('signal')],
    ['wechat', 'WeChat', si('WeChat')],
    ['line', 'LINE', si('LINE')],
    ['discord', 'Discord', gb('discord-icon')],
  ]],
  ['browsers', 'Browsers', [
    ['chrome', 'Chrome', gb('chrome')],
    ['firefox', 'Firefox', gb('firefox')],
    ['safari', 'Safari', gb('safari')],
    ['edge', 'Edge', gb('microsoft-edge')],
    ['opera', 'Opera', gb('opera')],
    ['brave', 'Brave', gb('brave')],
    ['vivaldi', 'Vivaldi', gb('vivaldi-icon')],
  ]],
  ['consoles', 'Gaming', [
    ['playstation', 'PlayStation', si('PlayStation')],
    ['xbox', 'Xbox', svgl('Xbox')],
    ['steam', 'Steam', gb('steam')],
    ['steam-deck', 'Steam Deck', si('Steam Deck')],
  ]],
  ['music', 'Music', [
    ['spotify', 'Spotify', gb('spotify-icon')],
    ['apple-music', 'Apple Music', si('Apple Music')],
    ['youtube-music', 'YouTube Music', si('YouTube Music')],
    ['soundcloud', 'SoundCloud', gb('soundcloud')],
    ['deezer', 'Deezer', si('Deezer')],
    ['tidal', 'TIDAL', gb('tidal-icon')],
  ]],
  ['cars', 'Cars', ['Toyota', 'Honda', 'BMW', 'Tesla', 'Ford', 'Audi', 'Porsche', 'Ferrari', 'Lamborghini',
    'Hyundai', 'Mitsubishi', 'Nissan', 'Volkswagen', 'Kia', 'Chevrolet', 'Subaru', 'Mazda']
    .map((t) => [slugify(t), t, si(t)])],
  ['fast-food', 'Fast Food', [
    ['mcdonalds', "McDonald's", si("McDonald's")],
    ['kfc', 'KFC', si('KFC')],
    ['burger-king', 'Burger King', si('Burger King')],
    ['starbucks', 'Starbucks', si('Starbucks')],
    ['taco-bell', 'Taco Bell', si('Taco Bell')],
  ]],
];

function slugify(title) {
  const map = { '+': 'plus', '.': 'dot', '&': 'and', đ: 'd', ħ: 'h', ı: 'i', ĸ: 'k', ŀ: 'l', ł: 'l', ß: 'ss', ŧ: 't' };
  return title.toLowerCase().replace(/[+.&đħıĸŀłßŧ]/g, (c) => map[c])
    .normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]/g, '');
}

async function fetchText(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${res.status} ${url}`);
  return res.text();
}

const hex = (h) => '#' + h.replace('#', '').toUpperCase();
const luminance = (h) => {
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(h.replace('#', '').slice(i, i + 2), 16) / 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};

// The first saturated fill in the SVG (logos and flags draw their main color early).
function dominantColor(svg) {
  const colors = [...svg.matchAll(/(?:fill|stop-color)\s*[:=]\s*"?\s*(#[0-9a-fA-F]{3,6})\b/g)].map((m) => m[1]);
  const full = colors.map((c) => (c.length === 4 ? '#' + [...c.slice(1)].map((x) => x + x).join('') : c));
  const saturated = full.find((c) => {
    const [r, g, b] = [0, 2, 4].map((i) => parseInt(c.slice(1 + i, 3 + i), 16));
    return Math.max(r, g, b) - Math.min(r, g, b) > 60;
  });
  return hex(saturated ?? full[0] ?? '#888888');
}

const siData = JSON.parse(await fetchText(`https://cdn.jsdelivr.net/npm/simple-icons@${SIMPLE_ICONS}/data/simple-icons.json`));
const siIcons = Array.isArray(siData) ? siData : siData.icons;
const siByTitle = new Map(siIcons.map((i) => [i.title, i]));
const svglAll = JSON.parse(await fetchText('https://api.svgl.app'));

async function resolve(source) {
  if (source.src === 'gilbarbara') return { svg: await fetchText(source.url), credit: 'gilbarbara/logos (CC0-1.0)' };
  if (source.src === 'svgl') {
    const item = svglAll.find((i) => i.title === source.title);
    if (!item) throw new Error(`svgl: no "${source.title}"`);
    const route = typeof item.route === 'string' ? item.route : item.route.light; // white ball = light background
    return { svg: await fetchText(route), credit: `svgl (${item.url ?? 'svgl.app'})` };
  }
  const icon = siByTitle.get(source.title);
  if (!icon) throw new Error(`simple-icons: no "${source.title}"`);
  const raw = await fetchText(`https://cdn.jsdelivr.net/npm/simple-icons@${SIMPLE_ICONS}/icons/${icon.slug ?? slugify(icon.title)}.svg`);
  // Single-color icon: draw it in the brand color, or black if the brand
  // color would vanish on the white ball.
  const ink = luminance(icon.hex) > 0.8 ? '#000000' : hex(icon.hex);
  return { svg: raw.replace('<svg ', `<svg fill="${ink}" `), credit: 'simple-icons (CC0-1.0)', brandHex: hex(icon.hex) };
}

rmSync(OUT, { recursive: true, force: true });
const catalog = { version: 1, groups: [] };
const credits = [];
const problems = [];

for (const [groupId, groupName, balls] of GROUPS) {
  mkdirSync(`${OUT}/${groupId}`, { recursive: true });
  const group = { id: groupId, name: groupName, style: 'logo', balls: [] };
  for (const [id, name, source] of balls) {
    try {
      const { svg, credit, brandHex } = await resolve(source);
      writeFileSync(`${OUT}/${groupId}/${id}.svg`, svg);
      const brand = brandHex ?? (siByTitle.get(name) ? hex(siByTitle.get(name).hex) : dominantColor(svg));
      group.balls.push({ id, name, image: `${groupId}/${id}.svg`, hash: hashOf(svg), color: brand });
      credits.push(`| ${groupName} | ${name} | ${credit} |`);
    } catch (e) {
      problems.push(`${groupName}/${name}: ${e.message}`);
    }
  }
  catalog.groups.push(group);
}

// Countries: every ISO country flag, square variant, filling the ball.
const countries = JSON.parse(await fetchText(`https://cdn.jsdelivr.net/npm/flag-icons@${FLAG_ICONS}/country.json`))
  .filter((c) => c.iso)
  .sort((a, b) => a.name.localeCompare(b.name));
mkdirSync(`${OUT}/countries`, { recursive: true });
const countryGroup = { id: 'countries', name: 'Countries', style: 'flag', balls: [] };
for (const c of countries) {
  try {
    const svg = await fetchText(`https://cdn.jsdelivr.net/npm/flag-icons@${FLAG_ICONS}/flags/1x1/${c.code}.svg`);
    writeFileSync(`${OUT}/countries/${c.code}.svg`, svg);
    countryGroup.balls.push({ id: c.code, name: c.name, image: `countries/${c.code}.svg`, hash: hashOf(svg), color: dominantColor(svg) });
  } catch (e) {
    problems.push(`Countries/${c.name}: ${e.message}`);
  }
}
catalog.groups.splice(3, 0, countryGroup); // after Laptops, as in the original list
credits.push(`| Countries | all ${countryGroup.balls.length} flags | flag-icons ${FLAG_ICONS} (MIT) |`);

// Yes or No: for decisions. A green ball with a check and a red one with a
// cross, filling the ball (square SVGs, drawn here).
const decisionSvg = (fill, mark) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect width="100" height="100" fill="${fill}"/>` +
  `<path d="${mark}" fill="none" stroke="#FFFFFF" stroke-width="11" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
mkdirSync(`${OUT}/decision`, { recursive: true });
const decisionGroup = { id: 'decision', name: 'Yes or No', style: 'flag', balls: [] };
for (const [id, name, fill, mark] of [
  ['yes', 'YES', '#16A34A', 'M27 52 L44 68 L74 34'],
  ['no', 'NO', '#DC2626', 'M32 32 L68 68 M68 32 L32 68'],
]) {
  const svg = decisionSvg(fill, mark);
  writeFileSync(`${OUT}/decision/${id}.svg`, svg);
  decisionGroup.balls.push({ id, name, image: `decision/${id}.svg`, hash: hashOf(svg), color: fill });
}
catalog.groups.push(decisionGroup);
credits.push('| Yes or No | YES, NO | drawn for Ball Wars |');

// Ulam (Filipino food): Wikimedia Commons photos, fetched as 384 px wide
// JPEG thumbnails; the app crops them to the ball. [id, name, Commons file,
// line color]. Only freely licensed files are accepted (no NC/ND).
const ULAM = [
  ['adobo', 'Adobo', 'Chicken adobo.jpg', '#7A4A22'],
  ['sinigang', 'Sinigang', 'The_Best_Sinigang_Cuisine.jpg', '#D9A21B'],
  ['kare-kare', 'Kare-kare', 'Mac_MG_5939.jpg', '#C2611F'],
  ['lechon', 'Lechon', 'Lechon Cebu 2.jpg', '#B5451B'],
  ['sisig', 'Sisig', 'Authentic_Kapampangan_Sisig.jpg', '#8C3B1E'],
  ['bulalo', 'Bulalo', 'BULALO.jpg', '#C9A227'],
  ['tinola', 'Tinola', 'Chicken_tinola.jpg', '#7FA33A'],
  ['pinakbet', 'Pinakbet', 'Pinakbet_ni_Lakay_Jesse.jpg', '#4E8F3A'],
  ['lumpia', 'Lumpiang Shanghai', 'Lumpiang Shanghai (Philippines).jpg', '#D98E2B'],
  ['pancit', 'Pancit', 'Pancit_Ilonggo_Style_-_12110747826.jpg', '#E0B23C'],
  ['kaldereta', 'Kaldereta', 'Home_cooked_Kaldereta.jpg', '#C0392B'],
  ['menudo', 'Menudo', 'Pork Menudo.jpg', '#D35400'],
  ['bicol-express', 'Bicol Express', 'Bicol_Express.jpg', '#E67E22'],
  ['dinuguan', 'Dinuguan', 'Dinuguan_and_Puto.jpg', '#3B2A24'],
  ['laing', 'Laing', 'Laing,_Bicolano_dish.jpg', '#4A6B2F'],
  ['inasal', 'Chicken Inasal', 'Olympus_EP3_-_Mang_Inasal_Roasted_Chicken_(14456257212).jpg', '#E8A33D'],
  ['crispy-pata', 'Crispy Pata', 'Crispy_Pata_Pork.jpg', '#A0522D'],
  ['bistek', 'Bistek Tagalog', 'Bistek_Tagalog_DSCF3899.jpg', '#6B3A1F'],
  ['afritada', 'Afritada', 'Chicken_Afritada_on_white_rice_with_pineapple_tidbits_(Philippines)_2.jpg', '#E2572B'],
  ['mechado', 'Mechado', 'Cooked_mechado.JPG', '#B03A2E'],
  ['nilaga', 'Nilagang Baka', 'Nilagang Baka.jpg', '#B8A04A'],
  ['tapa', 'Tapa', 'Beef_tapa_with_steamed_rice_and_sliced_tomato_and_cucumber.jpg', '#7B2D26'],
  ['longganisa', 'Longganisa', 'Vigan longganisa.JPG', '#C0392B'],
  ['tortang-talong', 'Tortang Talong', 'EGGPLANT_TORTA.jpg', '#D4A017'],
  ['ginataang-manok', 'Ginataang Manok', '1213Cuisine_of_Bulacan_02.jpg', '#D8B75A'],
  ['batchoy', 'Batchoy', 'Batchoy_of_Iloilo.jpg', '#C87533'],
  ['lechon-kawali', 'Lechon Kawali', 'Lechon_Kawali.jpg', '#B9770E'],
  ['pork-bbq', 'Pork Barbecue', 'Filipino pork barbecue.jpg', '#A93226'],
  ['chopsuey', 'Chopsuey', 'Chopsuey from the Philippines.jpg', '#58A33F'],
  ['pochero', 'Pochero', '08266jfSanta Cruz, Filipino pochero Guiguinto, Bulacanfvf 05.jpg', '#C0782B'],
  ['daing', 'Daing na Bangus', 'Daing_na_bangus.jpg', '#B7950B'],
];
const COMMONS_UA = { 'User-Agent': 'BallWarsPackBuilder/1.0 (https://dbsuarez.github.io/ballwars/)' };
const FREE_LICENSE = /^(CC BY(-SA)? [0-9.]+|CC0|Public domain)/i;
const stripHtml = (html) => (html ?? '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
mkdirSync(`${OUT}/ulam`, { recursive: true });
const ulamGroup = { id: 'ulam', name: 'Ulam (Filipino food)', style: 'flag', balls: [] };
for (const [id, name, file, color] of ULAM) {
  try {
    const api = `https://commons.wikimedia.org/w/api.php?action=query&titles=${encodeURIComponent('File:' + file)}` +
      '&prop=imageinfo&iiprop=extmetadata|url&iiurlwidth=384&format=json';
    const res = await fetch(api, { headers: COMMONS_UA });
    if (!res.ok) throw new Error(`${res.status} commons api`);
    const info = Object.values((await res.json()).query.pages)[0].imageinfo?.[0];
    if (!info) throw new Error(`no file "${file}"`);
    const license = stripHtml(info.extmetadata.LicenseShortName?.value);
    if (!FREE_LICENSE.test(license)) throw new Error(`license "${license}" not allowed`);
    const img = await fetch(info.thumburl, { headers: COMMONS_UA });
    if (!img.ok) throw new Error(`${img.status} ${info.thumburl}`);
    const bytes = Buffer.from(await img.arrayBuffer());
    writeFileSync(`${OUT}/ulam/${id}.jpg`, bytes);
    ulamGroup.balls.push({ id, name, image: `ulam/${id}.jpg`, hash: hashOf(bytes), color });
    const artist = stripHtml(info.extmetadata.Artist?.value) || 'unknown';
    credits.push(`| Ulam | ${name} | "${file}" by ${artist}, ${license}, ${info.descriptionurl} |`);
  } catch (e) {
    problems.push(`Ulam/${name}: ${e.message}`);
  }
}
catalog.groups.push(ulamGroup);

writeFileSync(`${OUT}/packs.json`, JSON.stringify(catalog, null, 1));
writeFileSync(`${OUT}/LICENSES.md`, [
  '# Built-in ball images',
  '',
  'Generated by `tool/build_packs.mjs`. Brand logos are trademarks of their owners and are',
  'used only to identify them; no endorsement is implied.',
  '',
  '- gilbarbara/logos: CC0-1.0, https://github.com/gilbarbara/logos',
  '- svgl: https://svgl.app (repository MIT; logos belong to their owners)',
  `- simple-icons ${SIMPLE_ICONS}: CC0-1.0, https://simpleicons.org`,
  `- flag-icons ${FLAG_ICONS}: MIT, https://github.com/lipis/flag-icons`,
  '- Wikimedia Commons photos (Ulam): each under the license named below, by the',
  '  author named below; resized to 384 px wide. CC BY-SA files stay under CC BY-SA.',
  '',
  '| Group | Ball | Source |',
  '| --- | --- | --- |',
  ...credits,
  '',
].join('\n'));

const total = catalog.groups.reduce((n, g) => n + g.balls.length, 0);
console.log(`groups: ${catalog.groups.length}, balls: ${total}`);
for (const g of catalog.groups) console.log(`  ${g.name}: ${g.balls.length}`);
if (problems.length) console.log('problems:\n  ' + problems.join('\n  '));
