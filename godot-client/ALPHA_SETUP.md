# Recursion Alpha — Setup & Run Guide

This is the 3D throw-mechanics demo. All scenes and scripts are pre-built — no editor assembly required.

---

## Prerequisites

- **Godot 4.6.2** — download from [godotengine.org](https://godotengine.org/download)
- No Node.js, no backend, no assets needed for the alpha.

---

## Running

1. Open Godot 4.6.2
2. **Import Project** → select `godot-client/project.godot`
3. Let Godot import (first run takes ~10 seconds)
4. Press **F5** (or the Play button) — the game starts immediately

That's it. Everything runs locally. No server, no art downloads.

---

## What You'll See

- **Isometric 3D view** — fixed camera above the player
- **Green ground plane** — infinite, flat
- **Blue-tinted capsule** — your player (placeholder geometry)
- **Red cylinder** — the test enemy (300 HP)
- **Right panel** — cart contents + weight bar
- **Bottom bar** — buildable object buttons

All world objects are colored 3D boxes sized proportionally to their weight. No art assets are required — the alpha uses procedural geometry.

---

## Controls

| Input | Action |
|---|---|
| W / A / S / D | Move |
| B | Enter Build mode → click world to place selected object |
| E | Pick up nearest object (within 2.5 units) → into cart |
| T | Enter Throw Aim mode → click near enemy to throw |
| Click (Build) | Place selected object at cursor |
| Click (Throw Aim) | Launch top cart item in a ballistic arc |
| Cart panel T button | Enter throw aim for a specific cart slot |

---

## Basic Loop to Test

1. **Select an object** from the bottom palette (e.g. Wooden House)
2. **B** → click somewhere on the ground → object appears as a colored box
3. Walk close to the box → **E** → it enters your cart (right panel updates)
4. **T** → an orange arc appears pointing at your cursor
5. Click near the red cylinder → the object flies in a physics arc and deals damage
6. Watch the HP label on the enemy update; floating red damage number appears
7. Enemy dies at 0 HP — squash animation then disappears

---

## Throw Damage Reference (Warrior class, STR 15)

| Object | Weight | Damage |
|---|---|---|
| Flower Pot | 5 kg | 33 |
| Iron Fence | 15 kg | 43 |
| Wooden Crate | 20 kg | 39 |
| Garden Bench | 25 kg | 41 |
| Cherry Tree | 40 kg | 49 |
| Stone Wall | 60 kg | 56 |
| Stone Block | 80 kg | 66 |
| Iron Spike Trap | 35 kg | 81 |
| Small Shed | 120 kg | 86 |
| **Wooden House** | **200 kg** | **121** |

A raw building material (stone chunk) deals only **~23 damage** with the same STR.
This gap is intentional — build things, then throw them.

---

## Cart Weight

- Cart holds **150 kg** before overload
- Past 150 kg: movement drops to **65% speed**
- Overload shows in red on the cart panel

---

## Running With Backend (Optional)

Only needed when testing multiplayer sync. Not required for throw mechanics.

```bash
cd backend
cp .env.example .env
npm install
npm run dev
```

Then in `scripts/network.gd`, change `LOCAL_MODE = true` to `false`.
The client will connect to `ws://localhost:3000`.

---

## 3D Assets (Future)

The alpha uses procedural placeholder geometry. When ready to add real art:

| What | Asset Pack | Source |
|---|---|---|
| World objects (houses, trees, etc.) | Kenney Nature Kit / City Kit Residential | kenney.nl |
| Player character | Kenney Character Pack | kenney.nl |
| Enemy | Kenney Shooter Pack 3D | kenney.nl |

All packs are CC0. Swap the `BoxMesh`/`CylinderMesh` in the scripts for GLTF models.
