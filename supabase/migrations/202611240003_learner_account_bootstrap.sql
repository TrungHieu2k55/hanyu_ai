BEGIN;

GRANT INSERT (id, owner_id, display_name, hsk_target, daily_minutes)
  ON app.profiles TO app_api;
GRANT INSERT (id, owner_id, purpose, policy_version, granted, operation_id, occurred_at)
  ON app.consent_events TO app_api;

COMMIT;
