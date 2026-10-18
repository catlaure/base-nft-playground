// Pure helpers for generating ERC-721 metadata. No dependencies.

/** Small deterministic PRNG so the same seed always yields the same collection. */
export function mulberry32(seed) {
  let a = seed >>> 0;
  return function next() {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Picks one option, with probability proportional to its weight. */
export function pickWeighted(rng, options) {
  const total = options.reduce((sum, o) => sum + o.weight, 0);
  let roll = rng() * total;
  for (const option of options) {
    roll -= option.weight;
    if (roll < 0) return option.value;
  }
  return options[options.length - 1].value;
}

export function validateConfig(config) {
  if (!config || typeof config !== "object") throw new Error("config must be an object");
  if (!Number.isInteger(config.count) || config.count < 1 || config.count > 100_000) {
    throw new Error("count must be an integer between 1 and 100000");
  }
  for (const key of ["name", "description", "imageBaseUri"]) {
    if (typeof config[key] !== "string" || config[key].length === 0) {
      throw new Error(`${key} must be a non-empty string`);
    }
  }
  for (const [trait, options] of Object.entries(config.traits ?? {})) {
    if (!Array.isArray(options) || options.length === 0) {
      throw new Error(`trait "${trait}" needs at least one option`);
    }
    for (const option of options) {
      if (typeof option.value !== "string" || !(option.weight > 0)) {
        throw new Error(`trait "${trait}" has an option with a missing value or non-positive weight`);
      }
    }
  }
}

/** Builds the metadata object for one token (OpenSea-style attributes). */
export function buildMetadata({ id, collectionName, description, imageBaseUri, attributes }) {
  const base = imageBaseUri.endsWith("/") ? imageBaseUri : `${imageBaseUri}/`;
  return {
    name: `${collectionName} #${id}`,
    description,
    image: `${base}${id}.png`,
    attributes: attributes.map(([trait_type, value]) => ({ trait_type, value })),
  };
}

/** Generates metadata for token ids 1..count. Returns an array indexed from 0 (id = index + 1). */
export function generateCollection(config) {
  validateConfig(config);
  const rng = mulberry32(config.seed ?? 1);
  const traits = Object.entries(config.traits ?? {});

  return Array.from({ length: config.count }, (_, i) =>
    buildMetadata({
      id: i + 1,
      collectionName: config.name,
      description: config.description,
      imageBaseUri: config.imageBaseUri,
      attributes: traits.map(([trait, options]) => [trait, pickWeighted(rng, options)]),
    }),
  );
}
