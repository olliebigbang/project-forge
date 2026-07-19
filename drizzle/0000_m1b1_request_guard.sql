CREATE TABLE IF NOT EXISTS `forge_request_ledger` (
  `namespace` text NOT NULL,
  `request_id` text NOT NULL,
  `fingerprint` text NOT NULL,
  `owner_token` text NOT NULL,
  `status` text NOT NULL CHECK (`status` IN ('inflight', 'complete')),
  `result_json` text,
  `created_at` integer NOT NULL,
  `updated_at` integer NOT NULL,
  `expires_at` integer NOT NULL,
  PRIMARY KEY (`namespace`, `request_id`)
);
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS `forge_request_ledger_expiry_idx`
  ON `forge_request_ledger` (`expires_at`);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS `forge_rate_windows` (
  `scope` text NOT NULL,
  `window_start` integer NOT NULL,
  `request_count` integer NOT NULL DEFAULT 0,
  `expires_at` integer NOT NULL,
  PRIMARY KEY (`scope`, `window_start`)
);
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS `forge_rate_windows_expiry_idx`
  ON `forge_rate_windows` (`expires_at`);
