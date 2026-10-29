// Builds the LIFF app into the SalesReport_LiffApp static resource folder (deployed as a zip by the Salesforce CLI).
// Usage: npm run build:liff
import { build } from "esbuild";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const outdir = path.resolve(
  here,
  "../sales-report/main/default/staticresources/SalesReport_LiffApp"
);

await build({
  entryPoints: { app: path.join(here, "src/main.js") },
  bundle: true,
  minify: true,
  format: "iife",
  target: ["es2020", "safari14"],
  legalComments: "eof",
  outdir,
  logLevel: "info"
});

await build({
  entryPoints: { app: path.join(here, "src/app.css") },
  bundle: true,
  minify: true,
  outdir,
  logLevel: "info"
});
