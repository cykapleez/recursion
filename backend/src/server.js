// Recursion — Alpha Backend
// In-memory state only. Run: npm run dev
// For production: replace in-memory maps with DB (pg) + Redis.

import express from "express";
import { createServer } from "http";
import { Server } from "socket.io";
import { readFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "..");

function loadContent(path) {
  return JSON.parse(readFileSync(join(ROOT, "content", path), "utf8"));
}

const OBJECTS = Object.fromEntries(
  loadContent("objects/objects.json").map(o => [o.id, o])
);

const app  = express();
const http = createServer(app);
const io   = new Server(http, { cors: { origin: "*" } });

// In-memory state (alpha only — replaced by DB + Redis in production)
const players = new Map();       // socket.id → { playerId, cart }
const placedObjects = new Map(); // object_instance_id → { object_id, x, y, placed_by }

app.get("/health", (_req, res) => res.json({ status: "ok", players: players.size }));

app.get("/content/objects", (_req, res) => res.json(Object.values(OBJECTS)));

io.on("connection", (socket) => {
  const playerId = socket.handshake.query.player_id || socket.id;

  players.set(socket.id, {
    playerId,
    strength: 15,    // alpha: Warrior defaults
    classId:  "class-warrior",
    cart: { items: [], maxWeight: 150, currentWeight: 0 },
  });

  console.log(`[+] ${playerId} connected (${players.size} online)`);

  // Send current world state to the new player
  socket.emit("world:state", {
    objects: Object.fromEntries(placedObjects),
    players: [...players.values()].map(p => ({ playerId: p.playerId })),
  });

  // --- Object placement ---
  socket.on("object:place", ({ object_id, x, y }) => {
    const obj = OBJECTS[object_id];
    if (!obj) return;

    // TODO: validate player has required materials
    const instanceId = `${Date.now()}_${Math.random().toString(36).slice(2)}`;
    placedObjects.set(instanceId, { object_id, x, y, placed_by: playerId });
    io.emit("object:state_change", { action: "placed", instanceId, object_id, x, y, placed_by: playerId });
  });

  // --- Lift attempt ---
  socket.on("object:lift_attempt", ({ instance_id }) => {
    const placed = placedObjects.get(instance_id);
    if (!placed) return;

    const obj      = OBJECTS[placed.object_id];
    const player   = players.get(socket.id);
    const liftCap  = player.strength * 6;

    if (obj.weight <= liftCap) {
      placedObjects.delete(instance_id);
      io.emit("object:state_change", { action: "picked_up", instanceId: instance_id, by: playerId });
      socket.emit("lift:update", { instance_id, success: true });
      // TODO: add to player's server-side cart
    } else {
      // TODO: initiate cooperative lift session in Redis
      socket.emit("lift:update", {
        instance_id,
        success: false,
        message: `Too heavy (${obj.weight}kg). Need combined STR ≥ ${obj.weight}. You have ${liftCap}.`,
        requires_coop: true,
      });
    }
  });

  // --- Throw resolution ---
  socket.on("cart:throw", ({ object_id, target_x, target_y }) => {
    const obj    = OBJECTS[object_id];
    const player = players.get(socket.id);
    if (!obj || !player) return;

    const base       = obj.throw_damage_base * obj.throw_effectiveness;
    const strBonus   = player.strength * 1.4;  // Warrior multiplier
    const damage     = Math.round(base + strBonus);

    io.emit("throw:result", {
      object_id,
      damage,
      target_x,
      target_y,
      thrown_by: playerId,
    });

    console.log(`[throw] ${playerId} threw ${object_id} → ${damage} damage`);
  });

  socket.on("disconnect", () => {
    players.delete(socket.id);
    console.log(`[-] ${playerId} disconnected (${players.size} online)`);
  });
});

const PORT = process.env.PORT || 3000;
http.listen(PORT, () => {
  console.log(`Recursion alpha server :${PORT}`);
  console.log(`Objects loaded: ${Object.keys(OBJECTS).length}`);
});
