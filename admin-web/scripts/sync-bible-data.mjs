import { copyFileSync, mkdirSync, statSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const adminRoot = resolve(__dirname, "..");
const repoRoot = resolve(adminRoot, "..");

const sourcePath = resolve(repoRoot, "VerseGarden", "Data", "bible_krv_full.json");
const generatedDir = resolve(adminRoot, "src", "generated");
const targetPath = resolve(generatedDir, "bible_krv_full.json");
const readmePath = resolve(generatedDir, "README.md");

statSync(sourcePath);
mkdirSync(generatedDir, { recursive: true });
copyFileSync(sourcePath, targetPath);
writeFileSync(
  readmePath,
  [
    "# Generated Bible Data",
    "",
    "`bible_krv_full.json` is generated from `../../VerseGarden/Data/bible_krv_full.json`.",
    "",
    "Do not edit this generated JSON manually. Run `npm run sync:bible` from `admin-web/`.",
    ""
  ].join("\n")
);

console.log(`Synced Bible data: ${sourcePath} -> ${targetPath}`);
