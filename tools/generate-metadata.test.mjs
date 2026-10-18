import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile, readdir, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { writeCollection } from "./generate-metadata.mjs";

const exampleConfig = path.join(path.dirname(fileURLToPath(import.meta.url)), "example-config.json");

test("writeCollection writes one JSON file per token", async () => {
  const dir = await mkdtemp(path.join(os.tmpdir(), "nft-meta-"));
  try {
    const count = await writeCollection(exampleConfig, dir);
    assert.equal(count, 100);

    const files = await readdir(dir);
    assert.equal(files.length, 100);
    assert.ok(files.includes("1.json") && files.includes("100.json"));

    const first = JSON.parse(await readFile(path.join(dir, "1.json"), "utf8"));
    assert.equal(first.name, "Base Playground #1");
    assert.equal(first.image, "ipfs://REPLACE_WITH_IMAGES_CID/1.png");
    assert.deepEqual(first.attributes.map((a) => a.trait_type), ["Background", "Shape"]);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("writeCollection is reproducible across runs", async () => {
  const a = await mkdtemp(path.join(os.tmpdir(), "nft-meta-a-"));
  const b = await mkdtemp(path.join(os.tmpdir(), "nft-meta-b-"));
  try {
    await writeCollection(exampleConfig, a);
    await writeCollection(exampleConfig, b);
    for (const id of [1, 37, 100]) {
      assert.equal(
        await readFile(path.join(a, `${id}.json`), "utf8"),
        await readFile(path.join(b, `${id}.json`), "utf8"),
      );
    }
  } finally {
    await rm(a, { recursive: true, force: true });
    await rm(b, { recursive: true, force: true });
  }
});

test("writeCollection rejects a missing config file", async () => {
  await assert.rejects(() => writeCollection("/nonexistent/config.json", os.tmpdir()), /ENOENT/);
});
