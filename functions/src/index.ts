import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {defineString} from "firebase-functions/params";

admin.initializeApp();

const spotifyClientId = defineString("SPOTIFY_CLIENT_ID");
const spotifyClientSecret = defineString("SPOTIFY_CLIENT_SECRET");

const db = admin.firestore();

export const getSpotifyAccessToken = functions.https.onCall(async () => {
  const response = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "Authorization": "Basic " +
        Buffer.from(
          spotifyClientId.value() + ":" + spotifyClientSecret.value()
        ).toString("base64"),
    },
    body: "grant_type=client_credentials",
  });

  if (!response.ok) {
    throw new functions.https.HttpsError(
      "internal",
      "Failed to get Spotify token"
    );
  }

  const data = await response.json();
  return {accessToken: data.access_token};
});

// ──────────────────────────────────────────────────
// Push Notifications via FCM
// ──────────────────────────────────────────────────

/**
 * Helper: fetch FCM token for a user from Firestore.
 */
async function getFcmToken(userId: string): Promise<string | null> {
  const userDoc = await db.collection("users").doc(userId).get();
  return userDoc.data()?.fcmToken ?? null;
}

/**
 * Helper: fetch display name for a user.
 */
async function getDisplayName(userId: string): Promise<string> {
  const userDoc = await db.collection("users").doc(userId).get();
  return userDoc.data()?.displayName ?? "Someone";
}

/**
 * Trigger: new like received.
 * Sends a push notification to the receiver when someone likes their broadcast track.
 */
export const onLikeCreated = functions.firestore
  .document("users/{userId}/likesReceived/{likeId}")
  .onCreate(async (snap, context) => {
    const {userId} = context.params;
    const data = snap.data();
    if (!data) return;

    const token = await getFcmToken(userId);
    if (!token) return;

    const fromName = data.fromUserDisplayName ??
      await getDisplayName(data.fromUserId ?? "");
    const trackTitle = data.trackTitle ?? "a track";

    const message: admin.messaging.Message = {
      token,
      notification: {
        title: `${fromName} liked your track!`,
        body: `"${trackTitle}" got a new like.`,
      },
      data: {
        type: "likeReceived",
        likeId: context.params.likeId,
      },
      apns: {
        payload: {
          aps: {sound: "default"},
        },
      },
    };

    try {
      await admin.messaging().send(message);
    } catch (err) {
      console.error("Failed to send like notification:", err);
    }
  });

/**
 * Trigger: like status updated to accepted.
 * Sends a push notification to the original liker when their like is accepted.
 */
export const onLikeAccepted = functions.firestore
  .document("users/{userId}/likesGiven/{likeId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (!before || !after) return;

    // Only trigger when status changes to "accepted"
    if (before.status === "accepted" || after.status !== "accepted") return;

    const likerId = context.params.userId;
    const token = await getFcmToken(likerId);
    if (!token) return;

    const receiverName = await getDisplayName(after.toUserId ?? "");
    const trackTitle = after.trackTitle ?? "a track";
    const hasMessage = after.message &&
      after.message.trim().length > 0;

    const body = hasMessage
      ? `Your message on "${trackTitle}" was delivered. Start chatting!`
      : `Your like on "${trackTitle}" was accepted. Start chatting now!`;

    const message: admin.messaging.Message = {
      token,
      notification: {
        title: `${receiverName} accepted your interaction!`,
        body,
      },
      data: {
        type: "likeAccepted",
        likeId: context.params.likeId,
      },
      apns: {
        payload: {
          aps: {sound: "default"},
        },
      },
    };

    try {
      await admin.messaging().send(message);
    } catch (err) {
      console.error("Failed to send like-accepted notification:", err);
    }
  });

