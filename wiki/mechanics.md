# Mechanics

How Recursion works — controls, modes, and core systems.

## Modes

### Free Mode

The default state. Move freely, interact with the world, pick up objects, and enter other modes.

You return to Free Mode by pressing the active mode key again or right-clicking during Throw Aim. Most actions are only available while in Free Mode.

### Build Mode  `B`

Enters Build Mode. Select an object from the palette at the bottom of the screen, then click anywhere in the world to place it.

A transparent ghost of the selected object follows your cursor. Placement snaps to the build grid by default. Hold ALT while clicking to place freely without snapping. Press B again to cancel.

**Tips:**
- Stone Wall Sections snap perfectly edge-to-edge on the default grid.
- Hold ALT for precise off-grid placement of decorative objects.
- Placed objects persist in the world and can be picked up by anyone with enough Strength.

### Throw Aim Mode  `T`

Enters Throw Aim Mode. An arc previews the trajectory of the object currently selected in your cart.

Left-click on a target to throw. Right-click or press T again to cancel. The throw arc is clamped to a maximum range — you cannot throw infinitely far. Heavier objects deal more damage but do not travel further.

**Tips:**
- Aim slightly ahead of moving enemies.
- Click directly on the enemy for maximum accuracy.
- If your cart has multiple items, use the cart UI to select which one to throw.

## Actions

### Pick Up  `E`

Picks up the nearest world object within reach and stores it in your cart.

You must be standing close to the object. If the object's weight exceeds your solo lift capacity, you cannot pick it up alone — a party is required. The object is removed from the world and added to your cart.

**Tips:**
- Warrior class has the highest solo lift capacity.
- The Wooden House cannot be lifted solo by anyone — it requires a coordinated party.
- Picked-up objects count toward your cart's weight limit.

### Throw  `T, then Left Click`

Throws the selected cart item at a target location. Damage scales with the object's weight and your Strength stat.

Enter Throw Aim Mode with T, then left-click to launch. The object flies in a ballistic arc and deals damage on contact with an enemy. The item is consumed from your cart on throw.

**Tips:**
- Higher throw_tier objects deal more base damage.
- Your class's throw damage multiplier affects total damage.
- Thrown objects are gone after use — pick up more before engaging.

### Smash  `R`

A melee attack. Lunges toward the nearest enemy and smashes the selected cart item directly into them, dealing bonus damage compared to a throw.

You must be within melee range of an enemy. On activation the player dashes toward the target and deals smash damage on contact. Smash damage applies a multiplier on top of the base throw damage. The item is consumed from your cart.

**Tips:**
- Smash deals significantly more damage than throwing the same object.
- You must be close enough — if no enemy is in range, nothing happens.
- Use heavy objects for maximum smash damage.

## Building

### Grid Snapping

When placing objects in Build Mode, placement snaps to a fixed grid by default.

The grid cell size matches the Stone Wall Section footprint, so walls placed side-by-side fit perfectly with no gaps. Hold ALT while clicking to bypass snapping and place freely at any position.

**Tips:**
- Use the grid for structural builds — walls, barriers, fortifications.
- Use ALT+click for decorative placement where exact alignment matters less.
- The grid lines are visible on the ground to help with alignment.

## Systems

### Cart

Your cart stores the objects you pick up. It trails behind you as you move.

Every cart has a maximum weight capacity. The cart UI on the right side of the screen shows all stored items. Select an item from the cart before throwing or smashing.

**Tips:**
- Fill your cart before engaging enemies.
- Heavier carts slow you down — see Overload.
- Cart tiers can be upgraded to increase capacity and unlock perk slots.

### Overload

If your cart's total weight exceeds its capacity, you are overloaded and move slower.

An overloaded cart applies a movement speed penalty. Throw or smash items to reduce the load. Upgrading your cart tier increases the weight limit.

**Tips:**
- Prioritize throwing heavy items first if overloaded.
- The Reinforced and Siege Cart tiers reduce the overload penalty.

### Cooperative Lift

Objects too heavy for any single player can be lifted cooperatively by a party standing nearby.

When multiple players attempt to pick up an object at the same time, their Strength stats are combined. If the combined value meets or exceeds the object's weight, the lift succeeds. The object goes into the initiating player's cart.

**Tips:**
- The Wooden House requires a full coordinated party.
- Warrior class players contribute the most Strength to a cooperative lift.
- Position matters — all lifting players must be in close range.
