const EARTH_M = 6371000;

function toRad(d) { return (d * Math.PI) / 180; }

/** Great-circle distance in metres. */
function distanceM(a, b) {
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const s = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_M * Math.asin(Math.sqrt(s));
}

/** Point `metres` away from `origin` in direction `bearingDeg`. */
function offset(origin, metres, bearingDeg) {
  const br = toRad(bearingDeg);
  const dLat = (metres * Math.cos(br)) / EARTH_M;
  const dLng = (metres * Math.sin(br)) / (EARTH_M * Math.cos(toRad(origin.lat)));
  return { lat: origin.lat + (dLat * 180) / Math.PI, lng: origin.lng + (dLng * 180) / Math.PI };
}

/** Random point within [minM, maxM] of origin. */
function jitter(origin, minM, maxM, rng) {
  return offset(origin, rng.between(minM, maxM), rng.between(0, 360));
}

/** Linear interpolation between two points (t in 0..1). */
function lerp(a, b, t) {
  return { lat: a.lat + (b.lat - a.lat) * t, lng: a.lng + (b.lng - a.lng) * t };
}

function round(p, digits = 6) {
  const f = 10 ** digits;
  return { lat: Math.round(p.lat * f) / f, lng: Math.round(p.lng * f) / f };
}

module.exports = { distanceM, offset, jitter, lerp, round };
