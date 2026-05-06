import { readFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "..");

function load(path) {
  return JSON.parse(readFileSync(join(ROOT, "content", path), "utf8"));
}

const CARTS    = load("carts/carts.json");
const UPGRADES = load("carts/upgrades.json");
const OBJECTS  = load("objects/objects.json");
const CLASSES  = load("classes/classes.json");

const cartsById    = Object.fromEntries(CARTS.map(c => [c.id, c]));
const upgradesById = Object.fromEntries(UPGRADES.map(u => [u.id, u]));
const objectsById  = Object.fromEntries(OBJECTS.map(o => [o.id, o]));
const classesById  = Object.fromEntries(CLASSES.map(c => [c.id, c]));

// --- Pure computation ---

function computeCartStats(cartTypeId, installedPerks) {
  const base = cartsById[cartTypeId];
  if (!base) throw new Error(`Unknown cart type: ${cartTypeId}`);

  let maxWeight           = base.max_weight;
  let overloadPenalty     = base.overload_speed_penalty;
  let overloadThreshold   = 1.0;
  let speedBonus          = 0;
  let speedBonusCondition = null;
  let throwDamageBonus    = 0;
  let throwDamageCategory = null;
  let perkSlots           = base.perk_slots;

  for (const perkId of installedPerks) {
    const perk = upgradesById[perkId];
    if (!perk) continue;
    const { type, value, condition, category } = perk.effect;

    if (type === "weight_capacity")    maxWeight += value;
    if (type === "perk_slot")          perkSlots += value;
    if (type === "overload_threshold") overloadThreshold = 1 + value;
    if (type === "speed_bonus")        { speedBonus = value; speedBonusCondition = condition; }
    if (type === "throw_damage_bonus") { throwDamageBonus = value; throwDamageCategory = category; }
  }

  return { maxWeight, overloadPenalty, overloadThreshold, speedBonus, speedBonusCondition, throwDamageBonus, throwDamageCategory, perkSlots };
}

function computeCurrentWeight(cartItems) {
  return cartItems.reduce((sum, item) => {
    const obj = objectsById[item.object_id];
    return sum + (obj ? obj.weight * item.quantity : 0);
  }, 0);
}

// Returns a speed multiplier applied to base movement speed.
// 1.0 = no change, < 1.0 = slowed (overloaded), > 1.0 = boosted (sprinter perk)
function getSpeedModifier(stats, currentWeight) {
  const overloadLine = stats.maxWeight * stats.overloadThreshold;

  if (currentWeight > overloadLine) {
    return 1.0 - stats.overloadPenalty;
  }

  if (stats.speedBonus > 0 && stats.speedBonusCondition === "under_50_pct") {
    if (currentWeight <= stats.maxWeight * 0.5) {
      return 1.0 + stats.speedBonus;
    }
  }

  return 1.0;
}

// Throw damage formula:
//   base = object.throw_damage_base * object.throw_effectiveness
//   strength bonus = playerStrength * class.throw_damage_multiplier
//   perk bonus = (base + strengthBonus) * perk.throw_damage_bonus   (crafted only)
function calculateThrowDamage(objectId, playerStrength, classId, cartStats) {
  const obj = objectsById[objectId];
  if (!obj) throw new Error(`Unknown object: ${objectId}`);
  if (!obj.throwable) throw new Error(`Object '${objectId}' is not throwable`);

  const cls = classesById[classId];
  const throwMultiplier = cls ? cls.throw_damage_multiplier : 1.0;

  const base = obj.throw_damage_base * obj.throw_effectiveness;
  const strengthBonus = playerStrength * throwMultiplier;
  const subtotal = base + strengthBonus;

  let perkBonus = 0;
  if (cartStats.throwDamageBonus > 0 && cartStats.throwDamageCategory === obj.item_category) {
    perkBonus = subtotal * cartStats.throwDamageBonus;
  }

  return Math.round(subtotal + perkBonus);
}

// --- DB operations ---

export async function getCart(db, playerId) {
  const { rows: cartRows } = await db.query(
    "SELECT * FROM player_carts WHERE player_id = $1",
    [playerId]
  );
  if (!cartRows.length) return null;

  const cart = cartRows[0];
  const { rows: items } = await db.query(
    "SELECT * FROM player_cart_items WHERE cart_id = $1 ORDER BY stored_at ASC",
    [cart.id]
  );

  const stats         = computeCartStats(cart.cart_type_id, cart.installed_perks);
  const currentWeight = computeCurrentWeight(items);
  const speedModifier = getSpeedModifier(stats, currentWeight);

  return {
    ...cart,
    items,
    stats,
    currentWeight,
    isOverloaded: currentWeight > stats.maxWeight * stats.overloadThreshold,
    speedModifier,
  };
}

export async function createCart(db, playerId) {
  await db.query(
    "INSERT INTO player_carts (player_id) VALUES ($1) ON CONFLICT (player_id) DO NOTHING",
    [playerId]
  );
  return getCart(db, playerId);
}

export async function storeItem(db, playerId, objectId, quantity = 1) {
  const obj = objectsById[objectId];
  if (!obj) throw new Error(`Unknown object: ${objectId}`);

  const cart = await getCart(db, playerId);
  if (!cart) throw new Error("Player has no cart");

  if (obj.stackable) {
    const { rows: existing } = await db.query(
      "SELECT id FROM player_cart_items WHERE cart_id = $1 AND object_id = $2",
      [cart.id, objectId]
    );
    if (existing.length) {
      await db.query(
        "UPDATE player_cart_items SET quantity = quantity + $1 WHERE id = $2",
        [quantity, existing[0].id]
      );
    } else {
      await db.query(
        "INSERT INTO player_cart_items (cart_id, object_id, item_category, quantity) VALUES ($1, $2, $3, $4)",
        [cart.id, objectId, obj.item_category, quantity]
      );
    }
  } else {
    // Non-stackable items each occupy their own slot (crafted items)
    for (let i = 0; i < quantity; i++) {
      await db.query(
        "INSERT INTO player_cart_items (cart_id, object_id, item_category, quantity) VALUES ($1, $2, $3, 1)",
        [cart.id, objectId, obj.item_category]
      );
    }
  }

  const newWeight = cart.currentWeight + obj.weight * quantity;
  return {
    success: true,
    newWeight,
    isOverloaded: newWeight > cart.stats.maxWeight * cart.stats.overloadThreshold,
    speedModifier: getSpeedModifier(cart.stats, newWeight),
  };
}

export async function retrieveItem(db, playerId, cartItemId, quantity = 1) {
  const { rows } = await db.query(
    `SELECT pci.* FROM player_cart_items pci
     JOIN player_carts pc ON pc.id = pci.cart_id
     WHERE pci.id = $1 AND pc.player_id = $2`,
    [cartItemId, playerId]
  );
  if (!rows.length) throw new Error("Cart item not found");

  const item = rows[0];
  if (item.quantity <= quantity) {
    await db.query("DELETE FROM player_cart_items WHERE id = $1", [cartItemId]);
  } else {
    await db.query(
      "UPDATE player_cart_items SET quantity = quantity - $1 WHERE id = $2",
      [quantity, cartItemId]
    );
  }

  return { success: true, objectId: item.object_id, quantity: Math.min(quantity, item.quantity) };
}

export async function throwItem(db, playerId, cartItemId, playerStrength, classId) {
  const { rows } = await db.query(
    `SELECT pci.*, pc.cart_type_id, pc.installed_perks
     FROM player_cart_items pci
     JOIN player_carts pc ON pc.id = pci.cart_id
     WHERE pci.id = $1 AND pc.player_id = $2`,
    [cartItemId, playerId]
  );
  if (!rows.length) throw new Error("Cart item not found");

  const item      = rows[0];
  const cartStats = computeCartStats(item.cart_type_id, item.installed_perks);
  const damage    = calculateThrowDamage(item.object_id, playerStrength, classId, cartStats);

  if (item.quantity <= 1) {
    await db.query("DELETE FROM player_cart_items WHERE id = $1", [cartItemId]);
  } else {
    await db.query(
      "UPDATE player_cart_items SET quantity = quantity - 1 WHERE id = $1",
      [cartItemId]
    );
  }

  return { success: true, damage, objectId: item.object_id, itemCategory: item.item_category };
}

export async function installPerk(db, playerId, perkId) {
  const perk = upgradesById[perkId];
  if (!perk) throw new Error(`Unknown perk: ${perkId}`);

  const cart = await getCart(db, playerId);
  if (!cart) throw new Error("Player has no cart");

  if (!perk.compatible_carts.includes(cart.cart_type_id)) {
    throw new Error(`Perk '${perkId}' is not compatible with ${cart.cart_type_id}`);
  }
  if (cart.installed_perks.includes(perkId)) {
    throw new Error("Perk already installed");
  }
  if (cart.installed_perks.length >= cart.stats.perkSlots) {
    throw new Error("No perk slots available");
  }

  const newPerks = [...cart.installed_perks, perkId];
  await db.query(
    "UPDATE player_carts SET installed_perks = $1, updated_at = NOW() WHERE player_id = $2",
    [JSON.stringify(newPerks), playerId]
  );

  return { success: true, installedPerks: newPerks };
}

export async function removePerk(db, playerId, perkId) {
  const cart = await getCart(db, playerId);
  if (!cart) throw new Error("Player has no cart");

  const newPerks = cart.installed_perks.filter(p => p !== perkId);
  if (newPerks.length === cart.installed_perks.length) {
    throw new Error("Perk not installed");
  }

  await db.query(
    "UPDATE player_carts SET installed_perks = $1, updated_at = NOW() WHERE player_id = $2",
    [JSON.stringify(newPerks), playerId]
  );

  return { success: true, installedPerks: newPerks };
}

export async function upgradeCart(db, playerId, newCartTypeId) {
  const newCartDef = cartsById[newCartTypeId];
  if (!newCartDef) throw new Error(`Unknown cart type: ${newCartTypeId}`);

  const cart = await getCart(db, playerId);
  if (!cart) throw new Error("Player has no cart");

  const currentTier = cartsById[cart.cart_type_id]?.tier ?? 0;
  if (newCartDef.tier <= currentTier) {
    throw new Error("Can only upgrade to a higher tier cart");
  }

  // Perks that aren't compatible with the new cart are silently dropped
  const compatiblePerks = cart.installed_perks.filter(perkId => {
    const perk = upgradesById[perkId];
    return perk && perk.compatible_carts.includes(newCartTypeId);
  });

  await db.query(
    "UPDATE player_carts SET cart_type_id = $1, installed_perks = $2, updated_at = NOW() WHERE player_id = $3",
    [newCartTypeId, JSON.stringify(compatiblePerks), playerId]
  );

  return { success: true, cartTypeId: newCartTypeId, installedPerks: compatiblePerks };
}
