# Floral Essence Studio: Phase 1 (database + customer site + Google sign-in)

## Files
index.html (the whole customer site) | config.js (your settings) | supabase.sql (database) | assets/ (logo.png, ad1.jpg, ad2.jpg, ad3.jpg)

## Setup
1. supabase.com > New project (free). Copy Project URL and the **anon public** key (Settings > API) into config.js. Never use the service_role key.
2. Supabase > SQL Editor > paste all of supabase.sql > Run.
3. Google sign-in: Google Cloud Console > APIs & Services > Credentials > Create OAuth client ID (Web). Add the Authorized redirect URI shown in Supabase > Authentication > Providers > Google (looks like https://YOUR-PROJECT.supabase.co/auth/v1/callback). Paste Client ID and Secret into Supabase and enable Google.
4. Supabase > Authentication > URL Configuration: set Site URL to your GitHub Pages address (https://YOUR-NAME.github.io/REPO/) and add it under Redirect URLs. For local testing also add http://localhost:8000.
5. Put logo.png, ad1.jpg, ad2.jpg, ad3.jpg in the assets folder (same names).
6. GitHub: create a repo, upload all files, Settings > Pages > Deploy from branch (main, root). Open the link.

## Test (Phase 1)
- Home shows logo, 3 moving ad cards, categories, favourites, footer, floating WhatsApp button.
- Add 1 item: delivery Rs. 100. Add items to total quantity 6: delivery Rs. 200 (5 stays Rs. 100).
- Place a COD order as guest, then track it with Order ID + phone (Orders tab).
- Continue with Google, place an order, see it in Orders.
- A tampered price in the browser does nothing: totals are calculated in the database.

## Coming next
Phase 2: UPI QR with fixed amount, 12-digit UPI Ref No, 10-minute COD cancel (enforced in the database). Phase 3: admin login, product upload with images, orders table, monthly sales dashboard.
Note: saved phone and address in Profile are stored in the browser only.
