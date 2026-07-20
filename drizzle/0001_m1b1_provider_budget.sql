CREATE TABLE IF NOT EXISTS `forge_provider_budget` (
  `budget_key` text NOT NULL PRIMARY KEY,
  `limit_microusd` integer NOT NULL CHECK (`limit_microusd` > 0),
  `spent_microusd` integer NOT NULL DEFAULT 0 CHECK (`spent_microusd` >= 0),
  `reserved_microusd` integer NOT NULL DEFAULT 0 CHECK (`reserved_microusd` >= 0),
  `locked` integer NOT NULL DEFAULT 0 CHECK (`locked` IN (0, 1)),
  `updated_at` integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS `forge_provider_charges` (
  `budget_key` text NOT NULL,
  `namespace` text NOT NULL,
  `request_id` text NOT NULL,
  `provider` text NOT NULL,
  `model` text NOT NULL,
  `status` text NOT NULL CHECK (`status` IN ('reserved', 'settled', 'conservative', 'released')),
  `reservation_microusd` integer NOT NULL CHECK (`reservation_microusd` > 0),
  `actual_microusd` integer,
  `input_tokens` integer,
  `output_tokens` integer,
  `created_at` integer NOT NULL,
  `updated_at` integer NOT NULL,
  PRIMARY KEY (`budget_key`, `namespace`, `request_id`)
);
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS `forge_provider_charges_status_idx`
  ON `forge_provider_charges` (`budget_key`, `status`);
