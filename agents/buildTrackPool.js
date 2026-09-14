// One-off: pulls a catalogue from the Spotify Search API per genre cluster
// and writes agents/trackPool.json. Runtime scripts never call Spotify.
//
//   SPOTIFY_CLIENT_ID=… SPOTIFY_CLIENT_SECRET=… node buildTrackPool.js
//   or: SPOTIFY_TOKEN=<any valid access token> node buildTrackPool.js
//
// Client id and secret: developer.spotify.com → your app → Settings.
// The client-credentials flow is enough for Search; no user login needed.

const fs = require("fs");
const config = require("./config");
const { POOL_PATH } = require("./lib/pool");

async function getToken() {
  if (process.env.SPOTIFY_TOKEN) return process.env.SPOTIFY_TOKEN;
  const id = process.env.SPOTIFY_CLIENT_ID;
  const secret = process.env.SPOTIFY_CLIENT_SECRET;
  if (!id || !secret) {
    console.error("Set SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET (or SPOTIFY_TOKEN).");
    process.exit(1);
  }
  const res = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: {
      Authorization: "Basic " + Buffer.from(`${id}:${secret}`).toString("base64"),
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });
  if (!res.ok) throw new Error(`token: ${res.status} ${await res.text()}`);
  return (await res.json()).access_token;
}

async function search(token, q, offset) {
  const url = new URL("https://api.spotify.com/v1/search");
  url.searchParams.set("q", q);
  url.searchParams.set("type", "track");
  url.searchParams.set("market", "CH");
  url.searchParams.set("limit", String(config.trackPool.perQueryLimit));
  url.searchParams.set("offset", String(offset));
  for (let attempt = 0; attempt < 5; attempt++) {
    const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
    if (res.status === 429) {
      const wait = Number(res.headers.get("retry-after") || 2) * 1000;
      console.log(`  429, waiting ${wait} ms`);
      await new Promise((r) => setTimeout(r, wait));
      continue;
    }
    if (!res.ok) throw new Error(`search "${q}": ${res.status} ${await res.text()}`);
    return (await res.json()).tracks?.items ?? [];
  }
  return [];
}

function toPoolTrack(item, cluster) {
  const images = item.album?.images ?? [];
  const art = images.find((i) => i.width >= 300) ?? images[0];
  return {
    trackId: item.id,
    name: item.name,
    artist: item.artists.map((a) => a.name).join(", "),
    artistId: item.artists[0]?.id ?? null,
    album: item.album?.name ?? null,
    albumArtUrl: art?.url ?? null,
    durationMs: item.duration_ms,
    genreCluster: cluster,
    popularity: item.popularity ?? 0,
  };
}

async function main() {
  const token = await getToken();
  const seen = new Set();
  const tracks = [];
  const { clusters, pagesPerQuery, perQueryLimit, targetPerCluster } = config.trackPool;

  for (const [cluster, queries] of Object.entries(clusters)) {
    let added = 0;
    for (const q of queries) {
      for (let page = 0; page < pagesPerQuery && added < targetPerCluster; page++) {
        const items = await search(token, q, page * perQueryLimit);
        for (const item of items) {
          if (!item?.id || seen.has(item.id)) continue;
          if (!item.duration_ms || item.duration_ms < 60_000) continue;
          seen.add(item.id);
          tracks.push(toPoolTrack(item, cluster));
          added++;
          if (added >= targetPerCluster) break;
        }
        if (items.length < perQueryLimit) break;
      }
    }
    console.log(`${cluster}: ${added} tracks`);
  }

  fs.writeFileSync(POOL_PATH, JSON.stringify({ builtAt: new Date().toISOString(), tracks }, null, 1) + "\n");
  console.log(`wrote ${POOL_PATH}: ${tracks.length} tracks in ${Object.keys(clusters).length} clusters`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
