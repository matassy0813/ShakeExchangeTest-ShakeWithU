// functions/src/index.ts
import {onCall, HttpsError, CallableRequest} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();
const storage = admin.storage();

interface GraphNode {
  id: string;
  x: number;
  y: number;
}

interface GraphEdge {
  source: string;
  target: string;
}

interface PhotoRequestData {
    photoId: string;
}


/**
 * Generates a pseudo-random coordinate based on a given ID.
 * @param {string} id - Unique identifier.
 * @return {{x: number, y: number}} An object containing x and y coordinates.
 */
function pseudoRandomCoord(id: string): { x: number; y: number } {
  let hash = 0;
  for (let i = 0; i < id.length; i++) {
    hash = id.charCodeAt(i) + ((hash << 5) - hash);
  }
  const x = ((hash >> 3) % 400) - 200;
  const y = ((hash >> 5) % 400) - 200;
  return {x, y};
}

/**
 * Callable Cloud Function to construct the social network graph.
 */
export const getNetworkGraph = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const nodes = new Map<string, GraphNode>();
  const edges = new Set<string>();

  /**
   * Loads the friend IDs of a given user.
   * @param {string} userId - The user's UID.
   * @return {Promise<Set<string>>} Set of friend UIDs.
   */
  async function loadFriends(userId: string): Promise<Set<string>> {
    const snapshot = await db
      .collection("users")
      .doc(userId)
      .collection("friends")
      .get();
    const friends = new Set<string>();
    snapshot.forEach((doc) => friends.add(doc.id));
    return friends;
  }

  const userDocs = await db.collection("users").listDocuments();

  for (const userDocRef of userDocs) {
    const userId = userDocRef.id;
    const friends = await loadFriends(userId);

    if (!nodes.has(userId)) {
      const pos = pseudoRandomCoord(userId);
      nodes.set(userId, {id: userId, x: pos.x, y: pos.y});
    }

    for (const friendId of friends) {
      if (!nodes.has(friendId)) {
        const pos = pseudoRandomCoord(friendId);
        nodes.set(friendId, {id: friendId, x: pos.x, y: pos.y});
      }

      const edgeKey = [userId, friendId].sort().join("-");
      edges.add(edgeKey);
    }
  }

  const connectedNodeIds = new Set<string>();
  for (const edge of edges) {
    const [source, target] = edge.split("-");
    connectedNodeIds.add(source);
    connectedNodeIds.add(target);
  }

  const filteredNodes: GraphNode[] = [];
  const filteredEdges: GraphEdge[] = [];

  for (const id of connectedNodeIds) {
    const node = nodes.get(id);
    if (node) filteredNodes.push(node);
  }

  for (const edge of edges) {
    const [source, target] = edge.split("-");
    filteredEdges.push({source, target});
  }

  return {nodes: filteredNodes, edges: filteredEdges};
});


// functions.https.onCall を onCall に変更し、v2のCallableRequestを使用
export const getSignedFeedPhotoUrl = onCall(async (request: CallableRequest<PhotoRequestData>) => { // ★修正: onCall と requestの型をv2形式に
  // context.auth は request.auth に、data は request.data に変更されます

  // 1. 認証チェック
  if (!request.auth) { // ★修正: context.auth を request.auth に
    console.log("DEBUG: Unauthenticated request.");
    throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
  }

  const photoId = request.data.photoId; // ★修正: data.photoId を request.data.photoId に
  console.log("DEBUG: Received photoId:", photoId);

  if (!photoId || typeof photoId !== "string") {
    console.log("DEBUG: Invalid photoId received.");
    throw new HttpsError("invalid-argument", "The function must be called with a photoId.");
  }

  try {
    // 2. Firestoreから写真メタデータを取得
    const photoDocRef = db.collection("feedPhotos").doc(photoId);
    const photoDoc = await photoDocRef.get();

    if (!photoDoc.exists) {
      console.log("DEBUG: Photo document not found for photoId:", photoId);
      throw new HttpsError("not-found", "Photo not found.");
    }

    const photoData = photoDoc.data() as { outerImage: string, viewerUUIDs?: string[] };
    console.log("DEBUG: Photo data from Firestore:", photoData);

    // 3. viewerUUIDsのチェック
    if (!photoData.viewerUUIDs || !photoData.viewerUUIDs.includes(request.auth.uid)) { // ★修正: context.auth.uid を request.auth.uid に
      console.log("DEBUG: User not authorized to view this photo. User UID:", request.auth.uid, "Viewer UUIDs:", photoData.viewerUUIDs); // ★修正
      throw new HttpsError("permission-denied", "You do not have permission to view this photo.");
    }

    // 4. Storageから署名付きURLを生成
    const filePath = photoData.outerImage;
    console.log("DEBUG: Generating signed URL for filePath:", filePath);

    const file = storage.bucket().file(filePath);
    const [url] = await file.getSignedUrl({
      action: "read",
      expires: Date.now() + 60 * 60 * 1000, // 1時間有効
    });

    console.log("DEBUG: Successfully generated signed URL.");
    return {url: url};
  } catch (error: any) {
    console.error("ERROR in getSignedFeedPhotoUrl:", error);
    if (error.code) {
      throw error; // HttpsErrorの場合はそのまま再スロー
    }
    throw new HttpsError("internal", "Failed to get signed URL.", error.message);
  }
});
