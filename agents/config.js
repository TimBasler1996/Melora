// Every probability, curve, radius and interval the agent scripts use.
// Tune here, not in the scripts.

module.exports = {
  projectId: "socialsound-5fdd9",
  storageBucket: "socialsound-5fdd9.firebasestorage.app",
  timeZone: "Europe/Zurich",

  // Firestore document read by every loop; {enabled: false} stops everything.
  killSwitchPath: "config/agents",

  // Discover shows a live doc for 5 min after its last `updatedAt`; the
  // sweeper ends it after 10. Half of the client window keeps agents visible.
  tickMs: 2 * 60 * 1000,

  // --debug multiplies session-start and like probabilities by this.
  debugBoost: 12,

  cities: {
    kilchberg: { name: "Kilchberg", label: "Kilchberg ZH", lat: 47.3225, lng: 8.55, language: "de-CH", count: 12 },
    lausanne: { name: "Lausanne", label: "Lausanne", lat: 46.5197, lng: 6.6323, language: "fr-CH", count: 6 },
    brig: { name: "Brig", label: "Brig VS", lat: 46.3167, lng: 7.9875, language: "de-CH", count: 4 },
    cransmontana: { name: "Crans-Montana", label: "Crans-Montana", lat: 46.3122, lng: 7.4792, language: "fr-CH", count: 5 },
  },

  // Anchors are scattered this far from the city centre (metres).
  anchorRadiusM: { min: 500, max: 4000 },
  // Per-session jitter on top of the anchor (metres).
  sessionOffsetM: { min: 40, max: 150 },

  userTypes: {
    heavy: { sessionsPerDay: [3, 4], restDayProbability: 0.05 },
    medium: { sessionsPerDay: [1, 2], restDayProbability: 0.2 },
    light: { sessionsPerDay: [0, 1], restDayProbability: 0.4 },
  },
  // Share of the population per type (used by genPersonas.js).
  userTypeMix: { heavy: 0.2, medium: 0.5, light: 0.3 },

  session: {
    tracks: [3, 8],
    trackMinutes: [2.5, 4.5],
    minGapMinutes: 90,
    transitProbability: 0.15,
  },

  travel: {
    dailyProbability: 0.03,
    days: [1, 2],
  },

  // Multiplier per local hour on the chance that a session starts now.
  hourCurve: {
    weekday: [
      0.05, 0.05, 0.05, 0.05, 0.05, 0.05, // 00-05
      0.30, // 06
      1.00, 1.00, // 07-08 commute
      0.50, 0.50, 0.50, // 09-11
      0.80, 0.80, // 12-13 lunch
      0.50, 0.50, 0.50, // 14-16
      1.00, 1.00, // 17-18 commute
      0.90, 0.90, 0.90, // 19-21
      0.40, 0.40, // 22-23
    ],
    weekend: [
      0.35, 0.20, 0.05, 0.05, 0.05, 0.05, // 00-05 (late nights)
      0.10, // 06
      0.15, 0.25, // 07-08 no commute peak
      0.50, 0.70, 0.80, // 09-11
      0.80, 0.80, // 12-13
      0.80, 0.80, 0.80, // 14-16
      0.90, 0.90, // 17-18
      1.00, 1.00, 1.00, // 19-21
      0.80, 0.60, // 22-23
    ],
  },

  likes: {
    // Chance to like one visible broadcast, checked once per session start
    // and once more halfway through the session.
    probabilityPerSession: 0.25,
    radiusKm: 15,
    // Weight multiplier for a broadcast whose track shares a cluster with the
    // agent's taste (unknown tracks, e.g. from real users, get weight 1).
    genreMatchWeight: 3,
    maxPerAgentPerDay: 4,
    // After a like: chance to also follow that person.
    followProbability: 0.35,
    // After liking a *real* user: chance to open a message request with a
    // canned opener in the agent's language.
    messageRealUserProbability: 0.3,
    maxRequestsPerAgentPerDay: 1,
  },

  // Reacting to likes and message requests the agent received.
  respond: {
    delayMinutes: [5, 90],
    acceptProbability: 0.7,
    declineProbability: 0.1, // rest: ignore
    // Agents never react between these local hours (they are asleep).
    quietHours: [1, 7],
  },

  chat: {
    model: "claude-haiku-4-5",
    maxTokens: 200,
    contextMessages: 10,
    replyDelayMinutes: [1, 10],
    // Between these local hours a message waits for the morning window.
    nightHours: [0, 8],
    morningWindow: [8, 10],
    // Rate limits so a runaway conversation cannot burn the API.
    maxRepliesPerConversationPerDay: 40,
    maxRepliesPerHourTotal: 120,
  },

  trackPool: {
    // Spotify Search per cluster; queries are combined with market=CH.
    clusters: {
      indie: ['genre:"indie" year:2016-2025', 'genre:"indie pop"', 'genre:"indie rock"'],
      electronic: ['genre:"electronic" year:2018-2025', 'genre:"house"', 'genre:"electro"'],
      techno: ['genre:"techno"', 'genre:"minimal techno"', 'genre:"melodic techno"'],
      hiphop: ['genre:"hip hop" year:2018-2025', 'genre:"rap" year:2019-2025', 'genre:"trap"'],
      deutschrap: ['genre:"german hip hop"', 'genre:"deutschrap"', 'genre:"swiss hip hop"'],
      rapfr: ['genre:"french hip hop"', 'genre:"rap francais"', 'genre:"french pop"'],
      pop: ['genre:"pop" year:2019-2025', 'genre:"dance pop"', 'genre:"synthpop"'],
      rnb: ['genre:"r&b"', 'genre:"neo soul"', 'genre:"alternative r&b"'],
      rock: ['genre:"rock" year:2010-2025', 'genre:"alternative rock"', 'genre:"punk"'],
      latin: ['genre:"reggaeton"', 'genre:"latin pop"', 'genre:"latin"'],
      afrobeats: ['genre:"afrobeats"', 'genre:"afropop"', 'genre:"amapiano"'],
      jazz: ['genre:"jazz"', 'genre:"nu jazz"', 'genre:"soul"'],
    },
    perQueryLimit: 50,
    pagesPerQuery: 2,
    targetPerCluster: 80,
  },
};
