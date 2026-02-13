# TODO

## Setup
- [x] Run `rake ynab:setup` to configure budget, account mappings, and minimum balances
- [x] Verify setup with `rake ynab:list_accounts`
- [x] Run tests: `rails test test/services/ynab_client_test.rb`

## Email Alerting
- [x] Configure SMTP settings in `.env` (Gmail SMTP)
- [x] Set ALERT_EMAIL_TO and ALERT_EMAIL_FROM in `.env`
- [ ] Test alert email: `DRY_RUN=1 rake ynab:check` to preview, then run without DRY_RUN
- [ ] Add mailer unit tests for AlertMailer

## Deployment
- [ ] Set YNAB_ACCESS_TOKEN in production environment
- [ ] Export config for production: `rake ynab:export_config` and set YNAB_CONFIG env var
- [ ] Schedule `rake ynab:check` via cron or similar

## Improvements
- [ ] Add unit tests with stubbed API responses for CoverageChecker and BalanceChecker
- [ ] Handle YNAB API token expiration/rotation gracefully
- [ ] Fix `.env.example` — inline comments can cause dotenv parsing issues (use separate comment lines)
