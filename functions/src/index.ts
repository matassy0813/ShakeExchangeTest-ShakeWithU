// functions/src/index.ts
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

interface GraphNode {
  id: string;
  x: number;
  y: number;
}

interface GraphEdge {
  source: string;
  target: string;
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
