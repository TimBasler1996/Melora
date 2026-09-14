// Small deterministic RNG helpers. Seeded so genPersonas.js is reproducible;
// the runtime loops use Math.random via `rng()` with no seed.

function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function hashString(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function make(seed) {
  const r = seed === undefined ? Math.random : mulberry32(typeof seed === "number" ? seed : hashString(String(seed)));
  const api = {
    float: () => r(),
    between: (min, max) => min + r() * (max - min),
    int: (min, max) => Math.floor(min + r() * (max - min + 1)),
    chance: (p) => r() < p,
    pick: (arr) => arr[Math.floor(r() * arr.length)],
    weighted(entries) {
      // entries: [[value, weight], ...]
      const total = entries.reduce((s, [, w]) => s + w, 0);
      let x = r() * total;
      for (const [v, w] of entries) {
        x -= w;
        if (x <= 0) return v;
      }
      return entries[entries.length - 1][0];
    },
    shuffle(arr) {
      const a = arr.slice();
      for (let i = a.length - 1; i > 0; i--) {
        const j = Math.floor(r() * (i + 1));
        [a[i], a[j]] = [a[j], a[i]];
      }
      return a;
    },
  };
  return api;
}

module.exports = { make, hashString };
