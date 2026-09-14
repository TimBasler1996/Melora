const fs = require("fs");
const path = require("path");

const POOL_PATH = path.join(__dirname, "..", "trackPool.json");

let cache;

/** Loads trackPool.json once; throws with a hint when it is missing. */
function load() {
  if (cache) return cache;
  if (!fs.existsSync(POOL_PATH)) {
    throw new Error("agents/trackPool.json missing. Run `node buildTrackPool.js` first.");
  }
  const raw = JSON.parse(fs.readFileSync(POOL_PATH, "utf8"));
  const tracks = raw.tracks || raw;
  const byCluster = {};
  const byId = {};
  for (const t of tracks) {
    (byCluster[t.genreCluster] ||= []).push(t);
    byId[t.trackId] = t;
  }
  cache = { tracks, byCluster, byId, clusters: Object.keys(byCluster) };
  return cache;
}

function exists() { return fs.existsSync(POOL_PATH); }

/** Picks a cluster by the persona's genre weights, restricted to clusters the pool has. */
function pickCluster(genreWeights, rng) {
  const { byCluster } = load();
  const entries = Object.entries(genreWeights).filter(([c]) => byCluster[c]?.length);
  if (!entries.length) return rng.pick(Object.keys(byCluster));
  return rng.weighted(entries);
}

/** `count` distinct tracks from one cluster (a session never mixes clusters). */
function sessionTracks(cluster, count, rng) {
  const { byCluster } = load();
  const list = byCluster[cluster] || [];
  return rng.shuffle(list).slice(0, Math.min(count, list.length));
}

function clusterOf(trackId) {
  return load().byId[trackId]?.genreCluster;
}

module.exports = { load, exists, pickCluster, sessionTracks, clusterOf, POOL_PATH };
