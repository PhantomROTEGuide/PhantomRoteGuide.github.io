# Phantom RoTE Guide — shared setup

The site is a static GitHub Pages app. Team recommendations are stored in Supabase so all visitors see the same data. Visitors can read without signing in; only accounts listed in the `editors` table can change content.

## 1. Create the shared database

1. Create a project at https://supabase.com/.
2. In the project, open **SQL Editor**, create a query, paste the contents of `supabase-setup.sql`, and run it.
3. Open **Project Settings → API** (or **Data API / API Keys**, depending on the dashboard layout). Copy the **Project URL** and the **anon / publishable public key**.
4. In this repository, open `index.html` and replace `YOUR_SUPABASE_PROJECT_URL` and `YOUR_SUPABASE_ANON_PUBLIC_KEY` with those two values. Commit the change.

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

Planet → mission (editable title) → multiple team recommendations. Each recommendation expands independently and has its own squad, relic/gear requirements, and strategy notes. Editors can add/remove missions and recommendations. All saved changes go to the same shared database.

## Current status

The frontend and database schema are prepared in this repository. Shared editing will not work until you create the Supabase project, run the SQL, and add its Project URL and public anon key to `index.html`.
