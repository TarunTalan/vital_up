# Hosting Guide for `vitalup.live`

This directory (`website/`) contains a static web suite ready to host on your domain **`vitalup.live`**:
- **`index.html`** — Homepage / App showcase
- **`privacy.html`** — Google Play & Health Connect compliant Privacy Policy (`https://vitalup.live/privacy`)
- **`terms.html`** — Terms of Service (`https://vitalup.live/terms`)
- **`delete-account.html`** — Account & Data Deletion portal (`https://vitalup.live/delete-account`) required by Google Play Console Data Safety
- **`_redirects`** & **`vercel.json`** — Clean URL rewrites (so `/privacy` works without `.html`)

---

## 🥇 Recommended Option: Cloudflare Pages (100% Free, Instant SSL)

Cloudflare Pages provides global CDN speed, zero cold starts, unlimited free bandwidth, and automatic HTTPS for custom domains.

### Step-by-Step Instructions:
1. Go to [dash.cloudflare.com](https://dash.cloudflare.com/) and log in (or sign up for a free account).
2. On the left sidebar, click **Compute (Workers) & Pages** &rarr; **Pages** &rarr; **Create application**.
3. Select **Upload assets** (Direct Upload):
   - Project name: `vitalup`
   - Drag and drop the `vitalup/website` folder directly into the upload area (or zip the folder contents and upload).
   - Click **Deploy site**.
4. **Connect your domain `vitalup.live`:**
   - In your newly deployed project, go to the **Custom domains** tab.
   - Click **Set up a custom domain**.
   - Enter `vitalup.live` (and optionally `www.vitalup.live`).
   - If your domain's DNS is already with Cloudflare, it configures in 1 click!
   - If your domain was purchased elsewhere (GoDaddy, Namecheap, Google Domains / Squarespace, Hostinger):
     - Cloudflare will provide a simple `CNAME` record to add in your domain registrar's DNS settings (e.g. `vitalup.pages.dev`).
5. **Done!** Your privacy policy is live immediately at:
   - `https://vitalup.live/privacy`
   - `https://vitalup.live/terms`
   - `https://vitalup.live/delete-account`

---

## 🥈 Option 2: Vercel (Free Tier, 60-Second Setup)

If you already use Vercel:

1. Install Vercel CLI (or connect via GitHub):
   ```bash
   npx vercel website --prod
   ```
2. In the Vercel Dashboard, go to **Project Settings** &rarr; **Domains**.
3. Add `vitalup.live`.
4. Point the DNS A record / CNAME as shown in the Vercel prompt:
   - `A` record: `@` &rarr; `76.76.21.21`
   - `CNAME` record: `www` &rarr; `cname.vercel-dns.com`

---

## 🥉 Option 3: GitHub Pages (Directly from your repo)

Since your code is in a Git repository:
1. You can push the `website` directory to a branch named `gh-pages` or set GitHub Pages to serve from the `docs` directory.
2. In GitHub repository settings &rarr; **Pages**:
   - Custom domain: `vitalup.live`
   - Check **Enforce HTTPS**.
3. Add the GitHub Pages IP addresses (`185.199.108.153`, etc.) to your DNS.

---

## 📋 Google Play Console Submission Checklist

When filling out your Google Play Console app listing:
1. **Privacy Policy Field:**
   - URL: `https://vitalup.live/privacy`
2. **Data Safety & Account Deletion:**
   - Provide account deletion URL: `https://vitalup.live/delete-account`
3. **Health Connect Declarations:**
   - When submitting Health Connect access requests in the Play Console, provide:
     - Policy URL: `https://vitalup.live/privacy`
     - Health rationale: State that health metrics are accessed solely for user-facing health logs, daily rings, and recovery insights without advertising or third-party resale.
