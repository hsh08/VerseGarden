import { cp, mkdir, stat } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const source = resolve(scriptDirectory, "../../VerseGarden/Data/bible_krv_full.json");
const destination = resolve(scriptDirectory, "../assets/bible/bible_krv_full.json");

await stat(source);
await mkdir(dirname(destination), { recursive: true });
await cp(source, destination);

console.log("Synced VerseGarden Bible data from the iOS source asset.");
