# Ketan Kamble — personal hub site

Your MkDocs (Material) site: a personal brand hub with Blog, Projects, Scripts,
Power BI, About, and topic tags. The home page is a custom landing splash.

## Cost & scale (the short version)
This is a **static site on GitHub Pages** — a global CDN serves plain HTML/CSS/JS.
There is no server, no database, no compute. Traffic spikes can't make it slow or
"unresponsive," and it stays on the **free** tier. Nothing here costs money to run.

## One-time setup
1. Create a new GitHub repo for the site (recommended name: `KetanKamble3894.github.io`
   so it serves at https://ketankamble3894.github.io/). Push these files to `main`.
2. Repo → Settings → Pages → Source: **GitHub Actions**.
3. First push triggers the "Deploy site" workflow; the site goes live in ~1–2 min.

## Local preview
```
pip install -r requirements-docs.txt
python -m mkdocs serve
```

## Assets to drop in (placeholders are in place — nothing is blocked)
- **Headshot** → replace `docs/assets/headshot/ketan.jpg` with your photo (square, ~440px).
- **Power BI templates** → `.pbit` files into `docs/assets/pbit/`, then enable the
  download buttons on the matching report/script pages.
- **Report screenshots** → into `docs/assets/img/`, then point each report page at yours
  (currently they use `report-placeholder.svg`).
- **Buy Me a Coffee** → set your real URL in `mkdocs.yml` (nav `☕ Support`) and in
  `overrides/home.html` (currently `https://www.buymeacoffee.com/ketankamble`).
- **LinkedIn** → add your URL in `docs/about/index.md` and the profile card in
  `overrides/home.html`.

## Adding content later
See `ADDING-CONTENT.md` — adding a new script or post is a 2-minute Markdown edit.

## Optional add-ons (free, documented, not enabled yet)
- **Comments** on blog posts via giscus (GitHub Discussions).
- **Newsletter** signup (Buttondown / MailerLite embed).
- **Privacy-friendly analytics** (GoatCounter / Plausible) if you want visitor stats
  without a cookie banner.
Ask and I'll wire any of these in.

## Engagement features (added) — how to finish them
- **Social preview cards** — a branded `docs/assets/img/social-card.png` + Open Graph/Twitter
  meta on every page. Works now. If you move to a custom domain, update `site_url` in
  `mkdocs.yml` (the card URL is built from it) and the absolute URLs in `overrides/home.html`.
- **Share buttons** — LinkedIn / X / copy-link on every blog post. Nothing to configure.
- **Comments + reactions (giscus)** — free, via GitHub Discussions:
  1. On your site repo: Settings → General → enable **Discussions**.
  2. Install the giscus app: https://github.com/apps/giscus (grant it the repo).
  3. Go to https://giscus.app, enter your repo, copy the 4 values.
  4. In `overrides/partials/comments.html`, replace `data-repo`, `PLACEHOLDER_REPO_ID`,
     `data-category`, and `PLACEHOLDER_CATEGORY_ID`. Done — comments appear on every post.
- **Newsletter** — a signup form is on the Blog and About pages. It's wired for **Buttondown**
  (free tier): create an account, then replace `YOUR-BUTTONDOWN-USERNAME` (2 spots each in
  `docs/blog/index.md` and `docs/about/index.md`). Prefer MailerLite/Substack? Say the word.

## Monetization-ready (built in, switch on when ready)
The site is reputation-first but wired so you can monetize the moment it makes sense —
no rebuild required.

- **"Work with me" page** (`docs/work-with-me.md`) — the page to point any sponsor/advertiser to.
  Add your email + LinkedIn, and fill the audience numbers once analytics has data.
- **Ad slot** — a ready, commented AdSense/sponsor block sits in `overrides/partials/comments.html`
  (renders under every blog post). When you're approved by an ad network or land a sponsor, paste
  the ad code between the markers — one edit, live everywhere.
- **Analytics** — commented GA4 + cookie-consent config in `mkdocs.yml`. Turn it on at launch so
  traffic history accrues; sponsors and ad networks will ask "how much traffic?" and you'll have the answer.

### Honest note on ads + platform (so you can plan)
Display-ad income follows **traffic** — it pays little until you have real volume (Ezoic starts
~10k visits/month; Mediavine ~50k sessions/month). Big niche sites (Anoop C Nair / HTMD,
Prajwal Desai) earn from ads because they run **WordPress on paid hosting** at large scale —
GitHub Pages' terms don't allow a site that exists *primarily* for ads.

So the plan that keeps every door open:
1. **Now:** launch the free hub, publish weekly, build audience + reputation. Take sponsorships,
   affiliate, consulting, and a light AdSense unit anytime — all fine here.
2. **Later, if ad revenue becomes the goal:** your content is Markdown and fully portable — migrate
   it to WordPress + an ad network when your traffic is worth it. Nothing you build now is wasted.
