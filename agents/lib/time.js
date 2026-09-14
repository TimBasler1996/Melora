const config = require("../config");

/** Local wall-clock parts in the configured time zone. */
function local(date = new Date()) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: config.timeZone,
    year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", hour12: false, weekday: "short",
  }).formatToParts(date);
  const get = (t) => parts.find((p) => p.type === t)?.value;
  const hour = Number(get("hour")) % 24;
  const weekday = get("weekday");
  return {
    dateKey: `${get("year")}-${get("month")}-${get("day")}`,
    hour,
    minute: Number(get("minute")),
    isWeekend: weekday === "Sat" || weekday === "Sun",
    weekday,
  };
}

function curveFor(isWeekend) {
  return isWeekend ? config.hourCurve.weekend : config.hourCurve.weekday;
}

/** Sum of the hour curve over the ticks left today, starting at hour/minute. */
function remainingCurveMass(isWeekend, hour, minute) {
  const curve = curveFor(isWeekend);
  const ticksPerHour = 3600000 / config.tickMs;
  let mass = curve[hour] * ((60 - minute) / 60) * ticksPerHour;
  for (let h = hour + 1; h < 24; h++) mass += curve[h] * ticksPerHour;
  return mass;
}

function inWindow(hour, [from, to]) {
  return from <= to ? hour >= from && hour < to : hour >= from || hour < to;
}

module.exports = { local, curveFor, remainingCurveMass, inWindow };
