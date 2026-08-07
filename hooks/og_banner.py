"""
Two SEO/social jobs, run as an mkdocs build hook:

1.  Social share image — for blog posts, use the post's own 1200x630 cover
    banner (with official Microsoft product icons) as the OpenGraph / Twitter
    image instead of the plugin-generated card. Also promotes og:type to
    "article" and adds article:published_time for posts.

2.  Structured data (JSON-LD) — the single highest-leverage discoverability
    fix. Emits schema.org markup so Google, Bing and AI answer engines
    (Gemini, Perplexity, ChatGPT search) can recognise Ketan as the author
    entity and cite the articles:
      * a canonical Person node (with sameAs to LinkedIn / GitHub / ...),
      * a WebSite node on the home page,
      * a BlogPosting node on every post, authored by that Person.

Runs AFTER the social plugin (event_priority < 0) so it can rewrite the meta
tags the plugin appended to page.meta["meta"].
"""
import datetime
import json
import os
import posixpath
import re

from mkdocs.plugins import event_priority

SITE = "https://ketankamble.com"

# Canonical author entity. Add YouTube / Instagram / X profile URLs to sameAs
# to strengthen the identity graph (more verified profiles = stronger E-E-A-T).
PERSON = {
    "@type": "Person",
    "@id": SITE + "/#ketan",
    "name": "Ketan Kamble",
    "url": SITE + "/about/",
    "jobTitle": "Modern Workplace Architect",
    "knowsAbout": [
        "Microsoft Intune",
        "Microsoft Entra ID",
        "Microsoft Graph",
        "Windows Autopilot",
        "Endpoint management",
        "PowerShell",
    ],
    "sameAs": [
        "https://www.linkedin.com/in/ketan-kamble-012a1582",
        "https://github.com/KetanKamble3894",
    ],
}


def _script(obj):
    payload = json.dumps(obj, ensure_ascii=False, separators=(",", ":"))
    return '\n<script type="application/ld+json">' + payload + "</script>\n"


def _iso(value):
    # Full ISO 8601 with timezone (Google & OG prefer datetime over date-only).
    if isinstance(value, datetime.datetime):
        return value.isoformat()
    if isinstance(value, datetime.date):
        return value.isoformat() + "T00:00:00+00:00"
    if value:
        s = str(value)
        if len(s) == 10 and s.count("-") == 2:
            return s + "T00:00:00+00:00"
        return s
    return None


def _post_date(page):
    created = page.meta.get("date")
    # blog plugin may expose it via page.config.date.created instead
    if created is None:
        cfg = getattr(page, "config", None)
        date_obj = getattr(cfg, "date", None) if cfg is not None else None
        created = getattr(date_obj, "created", None) if date_obj is not None else None
    if isinstance(created, dict):
        created = created.get("created")
    return _iso(created)


@event_priority(-50)
def on_page_content(html, page, config, files, **kwargs):
    src = page.file.src_uri

    # ---- Home page: WebSite + Person entity ---------------------------------
    if src == "index.md":
        graph = {
            "@context": "https://schema.org",
            "@graph": [
                {
                    "@type": "WebSite",
                    "@id": SITE + "/#website",
                    "url": SITE + "/",
                    "name": "Ketan Kamble",
                    "description": (config.site_description or ""),
                    "inLanguage": "en",
                    "publisher": {"@id": SITE + "/#ketan"},
                },
                PERSON,
            ],
        }
        return html + _script(graph)

    # ---- About page: ProfilePage wrapping the authoritative Person node ------
    # Google supports ProfilePage for an "About Me" page on a blog; mainEntity is
    # the Person the page is about (required), with a recommended description
    # (byline / credential). Strengthens author-entity / E-E-A-T signals.
    if src == "about/index.md":
        person = dict(PERSON)
        person["description"] = (
            "Modern Workplace Architect with 10 years in end-user computing; "
            "MD-102 and SC-300 certified; Workplace Ninja User Group Finland "
            "speaker. Builds read-only Intune, Entra and Microsoft Graph tooling "
            "in the open."
        )
        profile = {
            "@context": "https://schema.org",
            "@type": "ProfilePage",
            "@id": page.canonical_url,
            "mainEntity": person,
        }
        return html + _script(profile)

    # ---- Blog posts: banner rewrite + article meta + BlogPosting ------------
    if not src.startswith("blog/posts/"):
        return html

    stem = os.path.splitext(os.path.basename(src))[0]
    base = (config.site_url or "/").rstrip("/") + "/"
    banner = posixpath.join(base, f"assets/img/banners/{stem}.png")
    banner_src = f"assets/img/banners/{stem}.png"
    have_banner = files.get_file_from_path(banner_src) is not None

    published = _post_date(page)

    # Rewrite the share image + promote og:type; add article:published_time.
    meta = page.meta.get("meta", [])
    has_type = False
    for tag in meta:
        if have_banner and tag.get("property") == "og:image":
            tag["content"] = banner
        elif have_banner and tag.get("property") == "og:image:type":
            tag["content"] = "image/png"
        elif have_banner and tag.get("name") == "twitter:image":
            tag["content"] = banner
        elif tag.get("property") == "og:type":
            tag["content"] = "article"
            has_type = True
    if not has_type:
        meta.append({"property": "og:type", "content": "article"})
    if published:
        meta.append({"property": "article:published_time", "content": published})
    meta.append({"property": "article:author", "content": PERSON["url"]})
    page.meta["meta"] = meta

    # BlogPosting structured data. author & publisher are BOTH inlined (Google
    # evaluates each URL in isolation and won't dereference an @id defined on
    # another page) — the shared @id still consolidates the site-wide entity.
    entity = {
        "@id": SITE + "/#ketan",
        "@type": "Person",
        "name": PERSON["name"],
        "url": PERSON["url"],
    }
    node = {
        "@context": "https://schema.org",
        "@type": "BlogPosting",
        "author": entity,
        "publisher": entity,
        "mainEntityOfPage": {"@type": "WebPage", "@id": page.canonical_url},
        "url": page.canonical_url,
        "inLanguage": "en",
        "isAccessibleForFree": True,
    }
    headline = page.meta.get("title") or (page.title or "")
    if headline:
        node["headline"] = headline[:110]  # Google truncates long headlines
    description = page.meta.get("description")
    if description:
        node["description"] = description
    # BlogPosting needs an image for Article rich-result eligibility. Prefer the
    # filename-matched banner; otherwise fall back to the post's own .post-cover
    # image (resolved to an absolute URL) so no post is ever left without one.
    if have_banner:
        node["image"] = banner
    else:
        cover = None
        cm = re.search(r'!\[[^\]]*\]\(([^)]+)\)\{[^}]*\.post-cover', page.markdown or "")
        if not cm:
            cm = re.search(r'<img[^>]*class="[^"]*post-cover[^"]*"[^>]*src="([^"]+)"', page.markdown or "")
        if cm:
            rel = re.sub(r'^(\.\./)+', "", cm.group(1).strip())  # strip leading ../
            cover = posixpath.join(base, rel)
        if cover:
            node["image"] = cover
    if published:
        node["datePublished"] = published
        node["dateModified"] = published

    # BreadcrumbList — Home › Blog › Post (matches what mature MVP blogs emit;
    # eligible for Google breadcrumb rich results, and helps AI map structure).
    crumbs = {
        "@context": "https://schema.org",
        "@type": "BreadcrumbList",
        "itemListElement": [
            {"@type": "ListItem", "position": 1, "name": "Home", "item": SITE + "/"},
            {"@type": "ListItem", "position": 2, "name": "Blog", "item": SITE + "/blog/"},
            {"@type": "ListItem", "position": 3, "name": headline or "Article", "item": page.canonical_url},
        ],
    }

    return html + _script(node) + _script(crumbs)
