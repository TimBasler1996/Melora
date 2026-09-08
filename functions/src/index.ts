import {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

// ──────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────

async function getFcmToken(userId: string): Promise<string | null> {
  if (!userId) return null;
  const userDoc = await db.collection("users").doc(userId).get();
  return userDoc.data()?.fcmToken ?? null;
}

async function getDisplayName(userId: string): Promise<string> {
  if (!userId) return "Someone";
  const userDoc = await db.collection("users").doc(userId).get();
  return userDoc.data()?.displayName ?? "Someone";
}

function truncate(text: string, max: number): string {
  return text.length > max ? text.slice(0, max - 1) + "…" : text;
}

/**
 * Sends a push and clears the stored token if FCM reports it as dead.
 */
async function sendPush(
  recipientUid: string,
  message: admin.messaging.Message
): Promise<void> {
  try {
    await admin.messaging().send(message);
  } catch (err) {
    const code = (err as {code?: string}).code;
    logger.error(`Push failed for ${recipientUid}`, err);
    if (
      code === "messaging/invalid-registration-token" ||
      code === "messaging/registration-token-not-registered"
    ) {
      await db.collection("users").doc(recipientUid).update({
        fcmToken: admin.firestore.FieldValue.delete(),
      });
    }
  }
}

// ──────────────────────────────────────────────────
// Users: keep lowercase search fields in sync
// ──────────────────────────────────────────────────

/**
 * The client searches `firstNameLower` / `displayNameLower` with prefix
 * queries. Derive them server-side so every profile is searchable even if it
 * was written by an older client that never set them.
 */
export const onUserWritten = onDocumentWritten(
  "users/{userId}",
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;
    const data = after.data() ?? {};

    const firstNameLower = String(data.firstName ?? "").trim().toLowerCase();
    const displayNameLower = String(data.displayName ?? "")
      .trim()
      .toLowerCase();

    const updates: Record<string, string> = {};
    if (firstNameLower && data.firstNameLower !== firstNameLower) {
      updates.firstNameLower = firstNameLower;
    }
    if (displayNameLower && data.displayNameLower !== displayNameLower) {
      updates.displayNameLower = displayNameLower;
    }
    if (Object.keys(updates).length === 0) return;

    await after.ref.set(updates, {merge: true});
  }
);

// ──────────────────────────────────────────────────
// Likes
// ──────────────────────────────────────────────────

/**
 * New like received → push to the receiver.
 * With a message attached it is surfaced as a message request.
 */
export const onLikeCreated = onDocumentCreated(
  "users/{userId}/likesReceived/{likeId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const receiverUid = event.params.userId;
    const data = snap.data();

    // Public counter shown on other people's profiles (clients may not list
    // someone else's likesReceived).
    await db.collection("users").doc(receiverUid).set(
      {likesReceivedCount: admin.firestore.FieldValue.increment(1)},
      {merge: true}
    );

    const token = await getFcmToken(receiverUid);
    if (!token) return;

    const fromName: string =
      data.fromUserDisplayName ?? (await getDisplayName(data.fromUserId ?? ""));
    const trackTitle: string = data.trackTitle ?? "a track";
    const messageText = String(data.message ?? "").trim();
    const hasMessage = messageText.length > 0;

    const message: admin.messaging.Message = {
      token,
      notification: {
        title: hasMessage ?
          `${fromName} sent you a message` :
          `${fromName} liked your track!`,
        body: hasMessage ?
          truncate(messageText, 140) :
          `"${trackTitle}" got a new like.`,
      },
      data: {
        type: hasMessage ? "messageRequest" : "likeReceived",
        likeId: event.params.likeId,
      },
      apns: {payload: {aps: {sound: "default"}}},
    };

    await sendPush(receiverUid, message);
  }
);

/**
 * Like accepted → push to the original liker.
 * Watches the liker's `likesGiven` mirror, which the receiver updates.
 */
export const onLikeAccepted = onDocumentUpdated(
  "users/{userId}/likesGiven/{likeId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === "accepted" || after.status !== "accepted") return;

    const likerUid = event.params.userId;
    const token = await getFcmToken(likerUid);
    if (!token) return;

    const receiverName = await getDisplayName(after.toUserId ?? "");
    const trackTitle: string = after.trackTitle ?? "a track";
    const hasMessage = String(after.message ?? "").trim().length > 0;

    const message: admin.messaging.Message = {
      token,
      notification: {
        title: `${receiverName} accepted your interaction!`,
        body: hasMessage ?
          `Your message on "${trackTitle}" was delivered. Start chatting!` :
          `Your like on "${trackTitle}" was accepted. Start chatting now!`,
      },
      data: {
        type: "likeAccepted",
        likeId: event.params.likeId,
      },
      apns: {payload: {aps: {sound: "default"}}},
    };

    await sendPush(likerUid, message);
  }
);

// ──────────────────────────────────────────────────
// Chat
// ──────────────────────────────────────────────────

/**
 * New chat message → push to the other participant.
 * Skipped for the first message of a pending message request, because
 * `onLikeCreated` already notified the receiver about it.
 */
export const onNewChatMessage = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const conversationId = event.params.conversationId;
    const senderUid: string = data.senderId ?? "";
    const text = String(data.text ?? "");

    const convoDoc = await db
      .collection("conversations")
      .doc(conversationId)
      .get();
    if (!convoDoc.exists) return;
    const convo = convoDoc.data() ?? {};

    if (convo.status === "pending" && convo.initiatorId === senderUid) {
      const existing = await convoDoc.ref.collection("messages").limit(2).get();
      if (existing.size <= 1) return;
    }

    const participants: string[] = convo.participantIds ?? [];
    const recipientUid = participants.find((uid) => uid !== senderUid);
    if (!recipientUid) return;

    const token = await getFcmToken(recipientUid);
    if (!token) return;

    const senderName = await getDisplayName(senderUid);

    const message: admin.messaging.Message = {
      token,
      notification: {
        title: senderName,
        body: truncate(text, 100),
      },
      data: {
        type: "chatMessage",
        conversationId,
        messageId: event.params.messageId,
      },
      apns: {payload: {aps: {sound: "default"}}},
    };

    await sendPush(recipientUid, message);
  }
);

/**
 * Conversation deleted by a participant → remove its messages too.
 * Client SDKs cannot delete subcollections.
 */
export const onConversationDeleted = onDocumentDeleted(
  "conversations/{conversationId}",
  async (event) => {
    const ref = event.data?.ref;
    if (!ref) return;
    await db.recursiveDelete(ref.collection("messages"));
  }
);

// ──────────────────────────────────────────────────
// Broadcasts: expire orphans
// ──────────────────────────────────────────────────

const BROADCAST_TTL_MINUTES = 10;

/**
 * A client that is killed mid-broadcast never removes its `broadcasts/{uid}`
 * doc or clears `users/{uid}.isBroadcasting`. Sweep anything that has not
 * been refreshed within the TTL. Discover additionally filters client-side.
 */
export const expireStaleBroadcasts = onSchedule(
  "every 10 minutes",
  async () => {
    const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - BROADCAST_TTL_MINUTES * 60 * 1000
    );

    const stale = await db
      .collection("broadcasts")
      .where("updatedAt", "<", cutoff)
      .limit(200)
      .get();

    if (stale.empty) return;

    const batch = db.batch();
    for (const doc of stale.docs) {
      batch.delete(doc.ref);
      const userId: string | undefined = doc.data().userId;
      if (userId) {
        batch.set(
          db.collection("users").doc(userId),
          {
            isBroadcasting: false,
            currentTrack: admin.firestore.FieldValue.delete(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true}
        );
      }
    }
    await batch.commit();
    logger.info(`Expired ${stale.size} stale broadcast(s)`);
  }
);
