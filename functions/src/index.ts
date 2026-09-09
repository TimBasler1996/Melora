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

/**
 * Returns the user's push token, or null when the user has no token or has
 * switched the given notification category off in Settings (the app mirrors
 * the toggles to `notifyLikes` / `notifyMessages` / `notifyFollowers`;
 * missing means enabled).
 */
async function getFcmToken(
  userId: string,
  preferenceKey?: "notifyLikes" | "notifyMessages" | "notifyFollowers"
): Promise<string | null> {
  if (!userId) return null;
  const userDoc = await db.collection("users").doc(userId).get();
  const data = userDoc.data();
  if (!data) return null;
  if (preferenceKey && data[preferenceKey] === false) return null;
  return data.fcmToken ?? null;
}

async function getDisplayName(userId: string): Promise<string> {
  if (!userId) return "Someone";
  const userDoc = await db.collection("users").doc(userId).get();
  return userDoc.data()?.displayName ?? "Someone";
}

/** Same derivation as `ChatApiService.conversationId` in the app. */
function conversationIdFor(a: string, b: string): string {
  return [a.toLowerCase(), b.toLowerCase()].sort().join("_");
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
 * The client searches `firstNameLower` / `lastNameLower` / `displayNameLower` with prefix
 * queries. Derive them server-side so every profile is searchable even if it
 * was written by an older client that never set them.
 */
export const onUserWritten = onDocumentWritten(
  "users/{userId}",
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;
    const data = after.data() ?? {};

    // The app asks for deletion by stamping `deletionRequestedAt` (clients
    // cannot delete subcollections or other users' documents).
    if (data.deletionRequestedAt) {
      await deleteAccountData(event.params.userId);
      return;
    }

    const firstNameLower = String(data.firstName ?? "").trim().toLowerCase();
    const lastNameLower = String(data.lastName ?? "").trim().toLowerCase();
    const displayNameLower = String(data.displayName ?? "")
      .trim()
      .toLowerCase();

    const updates: Record<string, string> = {};
    if (firstNameLower && data.firstNameLower !== firstNameLower) {
      updates.firstNameLower = firstNameLower;
    }
    if (lastNameLower && data.lastNameLower !== lastNameLower) {
      updates.lastNameLower = lastNameLower;
    }
    if (displayNameLower && data.displayNameLower !== displayNameLower) {
      updates.displayNameLower = displayNameLower;
    }
    if (Object.keys(updates).length === 0) return;

    await after.ref.set(updates, {merge: true});
  }
);

// ──────────────────────────────────────────────────
// Account deletion
// ──────────────────────────────────────────────────

/**
 * Removes everything that belongs to a user: profile document (with its
 * likes subcollections), photos, follow edges in both directions, blocks,
 * their broadcast, every conversation they took part in, and finally the
 * auth user. Idempotent; safe to re-run.
 */
async function deleteAccountData(uid: string): Promise<void> {
  logger.info(`Deleting account data for ${uid}`);

  const deleteQuery = async (q: FirebaseFirestore.Query) => {
    const snap = await q.get();
    if (snap.empty) return;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  };

  await deleteQuery(db.collection("follows").where("followerId", "==", uid));
  await deleteQuery(db.collection("follows").where("followingId", "==", uid));
  await deleteQuery(db.collection("blocks").where("blockerId", "==", uid));
  await deleteQuery(db.collection("blocks").where("blockedUserId", "==", uid));

  // Likes this user gave live in other users' `likesReceived`; mirrors of
  // likes this user received live in other users' `likesGiven`.
  await deleteQuery(db.collectionGroup("likesReceived").where("fromUserId", "==", uid));
  await deleteQuery(db.collectionGroup("likesGiven").where("toUserId", "==", uid));

  const convos = await db
    .collection("conversations")
    .where("participantIds", "array-contains", uid)
    .get();
  for (const convo of convos.docs) {
    await db.recursiveDelete(convo.ref);
  }

  await db.collection("broadcasts").doc(uid).delete().catch(() => undefined);

  const bucket = admin.storage().bucket();
  await bucket.deleteFiles({prefix: `userPhotos/${uid}/`}).catch((err) => {
    logger.warn(`Photo cleanup failed for ${uid}`, err);
  });

  await db.recursiveDelete(db.collection("users").doc(uid));

  await admin.auth().deleteUser(uid).catch((err) => {
    logger.warn(`Auth user delete failed for ${uid}`, err);
  });

  logger.info(`Account ${uid} deleted`);
}

// ──────────────────────────────────────────────────
// Follows
// ──────────────────────────────────────────────────

/**
 * Someone started following a user → push to that user (honours the
 * "New followers" toggle).
 */
export const onFollowCreated = onDocumentCreated(
  "follows/{followId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const followerUid: string = data.followerId ?? "";
    const followedUid: string = data.followingId ?? "";
    if (!followerUid || !followedUid || followerUid === followedUid) return;

    const token = await getFcmToken(followedUid, "notifyFollowers");
    if (!token) return;

    const followerName = await getDisplayName(followerUid);
    const message: admin.messaging.Message = {
      token,
      notification: {
        title: `${followerName} started following you`,
        body: "Open their profile to follow back.",
      },
      data: {
        type: "newFollower",
        userId: followerUid,
      },
      apns: {payload: {aps: {sound: "default"}}},
    };

    await sendPush(followedUid, message);
  }
);

// ──────────────────────────────────────────────────
// Reports
// ──────────────────────────────────────────────────

/**
 * Reports are write-only for clients. Log them so they show up in Cloud
 * Logging (filter on `report.received`) until there is a review tool.
 */
export const onReportCreated = onDocumentCreated(
  "reports/{reportId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    logger.warn("report.received", {
      reportId: event.params.reportId,
      reporterId: data.reporterId,
      reportedUserId: data.reportedUserId,
      reason: data.reason,
      details: data.details ?? "",
    });
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

    const token = await getFcmToken(receiverUid, "notifyLikes");
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
        conversationId: conversationIdFor(receiverUid, data.fromUserId ?? ""),
      },
      apns: {payload: {aps: {sound: "default"}}},
    };

    await sendPush(receiverUid, message);
  }
);

/**
 * A message was attached to an existing pending like (the liker sent a
 * message after a plain like). `onLikeCreated` did not see it and
 * `onNewChatMessage` skips the first message of a request, so push here.
 */
export const onLikeMessageAttached = onDocumentUpdated(
  "users/{userId}/likesReceived/{likeId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const beforeText = String(before.message ?? "").trim();
    const afterText = String(after.message ?? "").trim();
    if (beforeText.length > 0 || afterText.length === 0) return;
    if (after.status === "rejected") return;

    const receiverUid = event.params.userId;
    const token = await getFcmToken(receiverUid, "notifyLikes");
    if (!token) return;

    const fromName: string =
      after.fromUserDisplayName ?? (await getDisplayName(after.fromUserId ?? ""));

    const message: admin.messaging.Message = {
      token,
      notification: {
        title: `${fromName} sent you a message`,
        body: truncate(afterText, 140),
      },
      data: {
        type: "messageRequest",
        likeId: event.params.likeId,
        conversationId: conversationIdFor(receiverUid, after.fromUserId ?? ""),
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
    const token = await getFcmToken(likerUid, "notifyLikes");
    if (!token) return;

    const receiverName = await getDisplayName(after.toUserId ?? "");
    const trackTitle: string = after.trackTitle ?? "a track";
    const hasMessage = String(after.message ?? "").trim().length > 0;

    const message: admin.messaging.Message = {
      token,
      notification: {
        title: hasMessage ?
          `${receiverName} accepted your message request` :
          `${receiverName} accepted your like`,
        body: `You can chat about "${trackTitle}" now.`,
      },
      data: {
        type: "likeAccepted",
        likeId: event.params.likeId,
        conversationId: conversationIdFor(likerUid, after.toUserId ?? ""),
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

    const token = await getFcmToken(recipientUid, "notifyMessages");
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
// Broadcasts: expire orphans, keep "recently live" for a day
// ──────────────────────────────────────────────────

const BROADCAST_LIVE_TTL_MINUTES = 10;
const BROADCAST_KEEP_HOURS = 24;

/**
 * A client that is killed mid-broadcast never ends its `broadcasts/{uid}` doc
 * or clears `users/{uid}.isBroadcasting`. Every 10 minutes:
 *  1. live docs not refreshed within the TTL are marked ended (they stay
 *     visible in Discover as "recently live"),
 *  2. docs untouched for a day are deleted.
 */
export const expireStaleBroadcasts = onSchedule(
  "every 10 minutes",
  async () => {
    const now = Date.now();
    const liveCutoff = admin.firestore.Timestamp.fromMillis(
      now - BROADCAST_LIVE_TTL_MINUTES * 60 * 1000
    );
    const keepCutoff = admin.firestore.Timestamp.fromMillis(
      now - BROADCAST_KEEP_HOURS * 60 * 60 * 1000
    );

    const stale = await db
      .collection("broadcasts")
      .where("isLive", "==", true)
      .where("updatedAt", "<", liveCutoff)
      .limit(200)
      .get();

    if (!stale.empty) {
      const batch = db.batch();
      for (const doc of stale.docs) {
        batch.set(
          doc.ref,
          {isLive: false, endedAt: doc.data().updatedAt ?? liveCutoff},
          {merge: true}
        );
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
      logger.info(`Ended ${stale.size} stale broadcast(s)`);
    }

    const old = await db
      .collection("broadcasts")
      .where("updatedAt", "<", keepCutoff)
      .limit(200)
      .get();

    if (!old.empty) {
      const batch = db.batch();
      old.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      logger.info(`Deleted ${old.size} broadcast(s) older than a day`);
    }
  }
);
