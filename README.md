# Building Finance App

Mobile-first family property finance app using React + Vite + Supabase.

## Important database step
After opening the project in VS Code, run these SQL files in Supabase SQL Editor in this order:

1. `db/000_complete_database.sql` (if starting from a blank project)
2. `db/003_expense_void.sql`
3. `db/004_property_management.sql`
4. `db/005_hardening.sql`
5. `db/006_recurring_income.sql` **(new — required for automatic monthly recurring income)**

If the first four are already installed in your existing Supabase project, run **only `db/006_recurring_income.sql`**.

## Recurring income workflow
Admin adds a recurring source once (flat/shop + category + monthly amount + start month). The database RPC automatically creates the missing expectation for each month. Manager records payments from Expected. Partial payments are supported. Deactivating a source stops future expectations while preserving old history.

## Roles
- Admin: everything, including recurring-source management and permanent financial-record deletion.
- Manager: record income, expected income, payments, expenses, receipts; no permanent deletion or reference-data management.
- Viewer: read-only.

## Local setup
Create `.env.local` from `.env.example` and add the Supabase project URL and publishable key. Do not commit secrets.

```bash
npm install
npm run dev
```

For phone testing through ngrok, keep Vite configured with `host: '0.0.0.0'` and `allowedHosts: true`, then run:

```bash
ngrok http 5173
```


## Production checklist
Before hosting, test these flows with separate Admin, Manager and Viewer accounts:

1. Admin creates a recurring apartment/shop income source.
2. Open Dashboard or Expected for the month and confirm exactly one expectation appears.
3. Manager records a partial payment; confirm outstanding decreases and Dashboard actual income increases.
4. Record the remaining payment; confirm the item becomes fully received.
5. Admin deactivates the recurring source; confirm future months stop generating it while old months remain.
6. Admin adds a new recurring source with a future start month; confirm it does not appear early.
7. Confirm Manager cannot access Admin settings or permanently delete records.
8. Confirm Admin can delete income, expense and expected-income records.
9. Test receipt upload/view on a phone.
10. Test Bengali/English switching and the mobile layout.

For Cloudflare Pages, build with `npm run build` and publish the generated `dist` directory. Vite's production build is a static bundle suitable for static hosting. Keep `.env.local` out of version control; Vite embeds `VITE_*` values into the browser bundle, so only use the Supabase publishable/anon key there—not a service-role secret.
