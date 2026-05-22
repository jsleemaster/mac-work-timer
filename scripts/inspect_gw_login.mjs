import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { pathToFileURL } from "node:url";

async function loadPlaywright() {
  try {
    return await import("playwright");
  } catch {
    const pathEntries = process.env.PATH?.split(":") ?? [];
    for (const entry of pathEntries) {
      if (!entry.endsWith("/node_modules/.bin")) {
        continue;
      }

      const packagePath = join(dirname(entry), "playwright", "index.mjs");
      if (existsSync(packagePath)) {
        return await import(pathToFileURL(packagePath).href);
      }
    }

    throw new Error("Playwright package is not available. Run with: npm exec --yes --package=playwright -- node scripts/inspect_gw_login.mjs");
  }
}

const target = process.argv[2] ?? "https://gw.evar.co.kr/gw/bizbox.do";
const { chromium } = await loadPlaywright();
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();
const requests = [];

page.on("request", (request) => {
  const url = request.url();
  if (url.includes("/gw/")) {
    requests.push({
      method: request.method(),
      resourceType: request.resourceType(),
      url,
    });
  }
});

await page.goto(target, { waitUntil: "domcontentloaded" });

const snapshot = await page.evaluate(() => ({
  title: document.title,
  url: location.href,
  forms: Array.from(document.forms).map((form) => ({
    action: form.action,
    method: form.method,
    inputs: Array.from(form.elements).map((element) => ({
      name: element.getAttribute("name"),
      id: element.getAttribute("id"),
      type: element.getAttribute("type"),
    })),
  })),
  text: document.body?.innerText?.slice(0, 700) ?? "",
}));

console.log(JSON.stringify({ snapshot, requests }, null, 2));
await browser.close();
