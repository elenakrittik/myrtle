--
-- Migration: split placeholders out of ui_message_keys, add i18n_engine to
-- ui_messages.
--
-- Placeholders are being moved to their own table so the engine column can
-- pick a different placeholder model per locale later; for now this is a pure
-- data relocation, the new table is authoritative and the old column is gone.
--

--
-- 1. Extract ui_message_keys.placeholders into its own table.
--
CREATE TABLE IF NOT EXISTS ui_message_key_placeholders (
    key           text PRIMARY KEY REFERENCES ui_message_keys(key) ON DELETE CASCADE,
    placeholders  jsonb NOT NULL DEFAULT '[]'::jsonb
);

INSERT INTO ui_message_key_placeholders (key, placeholders)
SELECT key, placeholders
FROM ui_message_keys
WHERE placeholders IS NOT NULL
  AND placeholders <> '[]'::jsonb
ON CONFLICT (key) DO UPDATE
    SET placeholders = EXCLUDED.placeholders;

ALTER TABLE ui_message_keys DROP COLUMN IF EXISTS placeholders;

--
-- 2. Add i18n_engine to ui_messages.
--
-- The engine is per (key, locale) rather than per key: nothing stops a future
-- locale from being authored in Fluent while the rest of the catalog stays on
-- the current engine, and the alternative - a locale-level or key-level column
-- - would have to be split back apart the first time that happens.
--
ALTER TABLE ui_messages
    ADD COLUMN IF NOT EXISTS i18n_engine varchar(16) NOT NULL DEFAULT 'myrrh';

ALTER TABLE ui_messages
    DROP CONSTRAINT IF EXISTS ui_messages_i18n_engine_check;

ALTER TABLE ui_messages
    ADD CONSTRAINT ui_messages_i18n_engine_check
        CHECK (i18n_engine IN ('myrrh', 'fluent'));

-- Existing rows were populated by the DEFAULT; make that explicit so the
-- intent survives anyone reading the schema later.
-- UPDATE ui_messages SET i18n_engine = 'myrrh' WHERE i18n_engine IS NULL;

-- CREATE INDEX IF NOT EXISTS idx_ui_messages_locale_engine ON ui_messages(locale, i18n_engine);
