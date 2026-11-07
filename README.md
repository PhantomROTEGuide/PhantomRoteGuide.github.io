# Phantom RoTE Guide — shared setup

The site is a static GitHub Pages app. Team recommendations are stored in Supabase so all visitors see the same data. Visitors can read without signing in; only accounts listed in the `editors` table can change content.

## 1. Create the shared database

1. Create a project at https://supabase.com/.
2. The website is already configured with this project's URL and publishable public key.
3. In the project, open **SQL Editor**, create a query, paste the contents of `supabase-setup.sql` from this repository, and run it.

**Important:** Use only the anon/publishable public key in the website. Never put the `service_role` or secret key in browser code.

## 2. Add approved editors

1. In Supabase, open **Authentication → Users** and create an account for yourself (and each officer) using an email and password.
2. Copy each account's **User UID**.
3. In **SQL Editor**, run this once per editor, replacing the UUID:
   ```sql
   insert into public.editors (user_id) values ('PASTE-AUTH-USER-UUID-HERE');
   ```
4. Officers use **Officer login** on the site. Everyone else can view but cannot edit.

Do not enable public sign-ups unless you intentionally want anyone to create an account. Being signed in alone does not grant editing permission; the UUID must be in `public.editors`.

## 3. Publish

GitHub Pages should publish from `main` and the repository root. After the Supabase values are committed, wait for the Pages deployment and open:

https://rotske1.github.io/Phantom-Rote-Guide/

## How recommendations are organized

Planet → mission (editable title) → multiple team recommendations. Each recommendation expands independently and has its own editable title, five circular squad-portrait slots, and strategy notes. Officers can upload, replace, or remove a JPEG, PNG, WebP, or GIF image (up to 8 MB) in each slot; portraits are displayed as circular crops and stored in the public `team-recommendations` Supabase Storage bucket so all visitors can see them. Existing text squad fields are retained in saved data for compatibility but are no longer shown in the recommendation editor. Relic-level and datacron suggestions are not part of the guide. Editors can add/remove missions and recommendations. All saved changes go to the same shared database.

## Current status

The frontend is connected to the Supabase project. Shared reading and saving require `supabase-setup.sql` to be run in the project's SQL Editor and approved editor user IDs to be added to `public.editors`. If you already ran an older version of the setup SQL, run the updated `supabase-setup.sql` again to create the shared image bucket and its access policies. This is required before squad image uploads will work. The website currently has no credentials for any service-role secret.
