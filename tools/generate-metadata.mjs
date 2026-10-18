#!/usr/bin/env node
// Usage: node tools/generate-metadata.mjs <config.json> [outDir]
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { generateCollection } from "./metadata.mjs";

/** Reads a config file and writes `<outDir>/<id>.json` for every token. Returns the number of files. */
export async function writeCollection(configPath, outDir) {
  const config = JSON.parse(await readFile(configPath, "utf8"));
  const items = generateCollection(config);

  await mkdir(outDir, { recursive: true });
  await Promise.all(
    items.map((item, i) =>
      writeFile(path.join(outDir, `${i + 1}.json`), `${JSON.stringify(item, null, 2)}\n`),
    ),
  );
  return items.length;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [configPath, outDir = "metadata"] = process.argv.slice(2);
  if (!configPath) {
    console.error("Usage: node tools/generate-metadata.mjs <config.json> [outDir]");
    process.exit(1);
  }
  writeCollection(configPath, outDir)
    .then((n) => console.log(`Wrote ${n} files to ${outDir}/`))
    .catch((err) => {
      console.error(err.message);
      process.exit(1);
    });
}
