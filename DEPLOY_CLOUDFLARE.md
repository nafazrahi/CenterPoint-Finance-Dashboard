# Cloudflare Pages deployment

1. Create a Git repository and push this project (do not commit `.env.local`).
2. In Cloudflare Pages, create a Pages project from the repository.
3. Build command: `npm run build`
4. Build output directory: `dist`
5. Add these environment variables to the Pages project:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
6. Deploy.

The app is a single-page Vite application and does not require a Node server at runtime.
