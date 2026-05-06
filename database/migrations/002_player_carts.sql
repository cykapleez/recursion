-- 002_player_carts.sql
-- Cart system: each player owns one cart with upgradeable perks and stored items.
-- Requires: 001_players.sql
-- Rollback: DROP TABLE player_cart_items; DROP TABLE player_carts; DROP FUNCTION touch_player_cart;

CREATE TABLE player_carts (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id       UUID        NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  cart_type_id    VARCHAR(64) NOT NULL DEFAULT 'cart-standard',
  installed_perks JSONB       NOT NULL DEFAULT '[]',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (player_id)
);

CREATE INDEX idx_player_carts_player_id ON player_carts(player_id);

CREATE TABLE player_cart_items (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  cart_id       UUID        NOT NULL REFERENCES player_carts(id) ON DELETE CASCADE,
  object_id     VARCHAR(64) NOT NULL,
  item_category VARCHAR(16) NOT NULL CHECK (item_category IN ('material', 'crafted')),
  quantity      INTEGER     NOT NULL DEFAULT 1 CHECK (quantity > 0),
  stored_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_player_cart_items_cart_id ON player_cart_items(cart_id);

-- Touch player_carts.updated_at whenever items change
CREATE OR REPLACE FUNCTION touch_player_cart()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE player_carts
  SET updated_at = NOW()
  WHERE id = COALESCE(NEW.cart_id, OLD.cart_id);
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_cart_items_touch
AFTER INSERT OR UPDATE OR DELETE ON player_cart_items
FOR EACH ROW EXECUTE FUNCTION touch_player_cart();
