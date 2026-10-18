import test from "node:test";
import assert from "node:assert/strict";
import {
  buildMetadata,
  generateCollection,
  mulberry32,
  pickWeighted,
  validateConfig,
} from "./metadata.mjs";

const config = {
  name: "Playground",
  description: "A test collection",
  imageBaseUri: "ipfs://images",
  count: 50,
  seed: 42,
  traits: {
    Background: [
      { value: "Blue", weight: 3 },
      { value: "Red", weight: 1 },
    ],
    Hat: [{ value: "None", weight: 1 }],
  },
};

test("mulberry32 is deterministic and in [0, 1)", () => {
  const a = mulberry32(7);
  const b = mulberry32(7);
  for (let i = 0; i < 100; i++) {
    const x = a();
    assert.equal(x, b());
    assert.ok(x >= 0 && x < 1);
  }
});

test("pickWeighted respects weights roughly and never returns unknown values", () => {
  const rng = mulberry32(1);
  const counts = { A: 0, B: 0 };
  for (let i = 0; i < 4000; i++) {
    counts[pickWeighted(rng, [{ value: "A", weight: 3 }, { value: "B", weight: 1 }])]++;
  }
  assert.ok(counts.A > counts.B * 2, `A=${counts.A} B=${counts.B}`);
  assert.equal(counts.A + counts.B, 4000);
});

test("pickWeighted works with a single option", () => {
  assert.equal(pickWeighted(mulberry32(1), [{ value: "only", weight: 5 }]), "only");
});

test("buildMetadata formats name, image and attributes", () => {
  const meta = buildMetadata({
    id: 12,
    collectionName: "Playground",
    description: "d",
    imageBaseUri: "ipfs://images",
    attributes: [["Hat", "Cap"]],
  });
  assert.deepEqual(meta, {
    name: "Playground #12",
    description: "d",
    image: "ipfs://images/12.png",
    attributes: [{ trait_type: "Hat", value: "Cap" }],
  });
});

test("buildMetadata does not double the trailing slash", () => {
  const meta = buildMetadata({
    id: 1,
    collectionName: "X",
    description: "d",
    imageBaseUri: "ipfs://images/",
    attributes: [],
  });
  assert.equal(meta.image, "ipfs://images/1.png");
});

test("generateCollection is reproducible for the same seed", () => {
  assert.deepEqual(generateCollection(config), generateCollection(config));
});

test("generateCollection differs between seeds", () => {
  assert.notDeepEqual(generateCollection(config), generateCollection({ ...config, seed: 43 }));
});

test("generateCollection numbers tokens from 1 and includes every trait", () => {
  const items = generateCollection(config);
  assert.equal(items.length, 50);
  assert.equal(items[0].name, "Playground #1");
  assert.equal(items[49].name, "Playground #50");
  for (const item of items) {
    assert.deepEqual(item.attributes.map((a) => a.trait_type), ["Background", "Hat"]);
  }
});

test("validateConfig rejects bad input", () => {
  assert.throws(() => validateConfig(null), /object/);
  assert.throws(() => validateConfig({ ...config, count: 0 }), /count/);
  assert.throws(() => validateConfig({ ...config, count: 1.5 }), /count/);
  assert.throws(() => validateConfig({ ...config, name: "" }), /name/);
  assert.throws(() => validateConfig({ ...config, traits: { Hat: [] } }), /at least one option/);
  assert.throws(
    () => validateConfig({ ...config, traits: { Hat: [{ value: "x", weight: 0 }] } }),
    /non-positive weight/,
  );
});
