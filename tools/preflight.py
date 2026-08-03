#!/usr/bin/env python3
"""
preflight.py — the automated pre-publish gate for ketankamble.com.

Run after `mkdocs build`, before pushing. Catches the silent misses that only
a human eyeball used to catch (blank cover cards, broken cross-post links,
dead social images, layout-shifting banner sizes, invalid structured data).
Exit code is non-zero on any FAIL — wire into a git pre-push hook or CI.

    python3 -m mkdocs build
    python3 tools/preflight.py

NOTE: this covers everything cheaply checkable from files. Two classes still
need a human/browser pass and are intentionally OUT of scope: rendered visual
regressions ("too big at 100%") and how an animated hook *looks* frozen on a
phone. Do those with the Chrome pass on the live pages after deploy.
"""
import json, pathlib, re, struct, sys
from urllib.parse import urldefrag, urlsplit

ROOT  = pathlib.Path(__file__).resolve().parent.parent
POSTS = ROOT / "docs" / "blog" / "posts"
SITE  = ROOT / "site"
HOOKS = ROOT / "docs" / "assets" / "hooks"

FAILS, WARNS = [], []
def fail(who, msg): FAILS.append(f"[FAIL] {who}: {msg}")
def warn(who, msg): WARNS.append(f"[WARN] {who}: {msg}")

PLACEHOLDERS = re.compile(r'\b(TODO|FIXME|lorem ipsum|coming soon|xxx placeholder)\b', re.I)

def image_size(path: pathlib.Path):
    """Return (w,h) for png/webp without external deps, else None."""
    try:
        b = path.read_bytes()
    except OSError:
        return None
    if b[:8] == b'\x89PNG\r\n\x1a\n' and b[12:16] == b'IHDR':
        return struct.unpack(">II", b[16:24])
    if b[:4] == b'RIFF' and b[8:12] == b'WEBP':
        fmt = b[12:16]
        if fmt == b'VP8 ':
            return (struct.unpack("<H", b[26:28])[0] & 0x3fff,
                    struct.unpack("<H", b[28:30])[0] & 0x3fff)
        if fmt == b'VP8L':
            n = struct.unpack("<I", b[21:25])[0]
            return ((n & 0x3fff) + 1, ((n >> 14) & 0x3fff) + 1)
        if fmt == b'VP8X':
            w = b[24] | (b[25] << 8) | (b[26] << 16)
            h = b[27] | (b[28] << 8) | (b[29] << 16)
            return (w + 1, h + 1)
    return None

# ---- 1. Per-post source checks ----------------------------------------------
def frontmatter(text):
    m = re.match(r'^---\n(.*?)\n---\n', text, re.S)
    return m.group(1) if m else ""

for md in sorted(POSTS.glob("*.md")):
    name = md.name
    t = md.read_text(encoding="utf-8")
    fm = frontmatter(t)

    dm = re.search(r'^\s*description:\s*(.+)$', fm, re.M)
    if not dm or not dm.group(1).strip():
        fail(name, "no frontmatter `description:` (SEO / OG)")
    elif len(dm.group(1).strip().strip('"\'')) > 200:
        warn(name, f"description is {len(dm.group(1).strip())} chars (search snippets truncate ~160)")

    if not re.search(r'^\s*date:\s*\S', fm, re.M):
        fail(name, "no frontmatter `date:`")
    # categories: block list OR inline flow list, with at least one item
    has_cat = re.search(r'^\s*categories:\s*\n\s*-\s*\S', fm, re.M) or re.search(r'^\s*categories:\s*\[[^\]]*\S[^\]]*\]', fm, re.M)
    if not has_cat:
        fail(name, "no `categories:` with at least one entry")
    if "<!-- more -->" not in t:
        fail(name, "no `<!-- more -->` excerpt marker")

    # cover: markdown image w/ .post-cover, OR <img class="...post-cover...">
    covers = re.findall(r'!\[[^\]]*\]\(([^)]+)\)\{[^}]*\.post-cover[^}]*\}', t)
    html_covers = re.findall(r'<img[^>]*class="[^"]*post-cover[^"]*"[^>]*src="([^"]+)"', t)
    covers += html_covers
    if not covers:
        fail(name, "no `.post-cover` image — blog-index card will be blank")
    for c in covers:
        target = (md.parent / c).resolve()
        if not target.exists():
            fail(name, f"cover image missing on disk: {c}")
            continue
        # declared vs actual dimensions (layout-shift guard)
        block = re.search(re.escape(c) + r'\)\{([^}]*)\}', t)
        decl = block.group(1) if block else ""
        dw = re.search(r'width="(\d+)"', decl); dh = re.search(r'height="(\d+)"', decl)
        actual = image_size(target)
        if actual and dw and dh:
            if (int(dw.group(1)), int(dh.group(1))) != actual:
                fail(name, f"cover declares {dw.group(1)}x{dh.group(1)} but file is {actual[0]}x{actual[1]} (layout shift)")

    if '!!! success "The payoff"' not in t:
        warn(name, 'no `!!! success "The payoff"` beat')
    if "hook-embed" not in t:
        warn(name, "no animated hook embed (ok if intentional)")
    if PLACEHOLDERS.search(t):
        fail(name, f"placeholder text present: {PLACEHOLDERS.search(t).group(0)!r}")

# ---- 2. Hook fallbacks (cheap guard for the mobile frozen-frame class) -------
for hk in HOOKS.glob("*.html"):
    h = hk.read_text(encoding="utf-8", errors="ignore")
    if "prefers-reduced-motion" not in h:
        warn(f"hooks/{hk.name}", "no prefers-reduced-motion fallback")
    if "/*rest-state*/" not in h and "opacity:0}" not in h:
        warn(f"hooks/{hk.name}", "no base rest-state (may garble when frozen)")

# ---- 3. Built-site checks (links, images, OG images, JSON-LD) ---------------
if not SITE.exists():
    fail("site/", "not built — run `python3 -m mkdocs build` first")
else:
    url_re = re.compile(r'(?:href|src)\s*=\s*["\']([^"\']+)["\']', re.I)
    meta_img_re = re.compile(r'<meta[^>]+(?:property|name)="(?:og:image|twitter:image)"[^>]+content="([^"]+)"', re.I)
    srcset_re = re.compile(r'srcset\s*=\s*["\']([^"\']+)["\']', re.I)

    def external(u):
        return u.startswith(("http://","https://","mailto:","tel:","data:","//","#")) or not u.strip()

    def resolve(base, u):
        u, _ = urldefrag(u)
        u = urlsplit(u).path  # drop ?query
        if not u: return None
        path = u if u.startswith("/") else base + u
        parts = []
        for seg in path.split("/"):
            if seg in ("", "."): continue
            if seg == "..":
                if parts: parts.pop()
            else: parts.append(seg)
        fsp = SITE / "/".join(parts)
        if fsp.is_dir(): fsp = fsp / "index.html"
        elif not fsp.suffix: fsp = SITE / "/".join(parts) / "index.html"
        return fsp

    for f in SITE.rglob("*.html"):
        base = "/" + str(f.relative_to(SITE).parent).replace("\\","/")
        if base != "/": base += "/"
        html = re.sub(r"<!--.*?-->", "", f.read_text(encoding="utf-8", errors="ignore"), flags=re.S)

        candidates = []
        candidates += [u for u in url_re.findall(html) if not external(u)]
        # OG/twitter images are absolute site URLs; keep only same-site path
        for u in meta_img_re.findall(html):
            p = urlsplit(u)
            if p.netloc in ("", "ketankamble.com"): candidates.append(p.path)
        for ss in srcset_re.findall(html):
            for part in ss.split(","):
                u = part.strip().split(" ")[0]
                if u and not external(u): candidates.append(u)

        for u in candidates:
            fsp = resolve(base, u)
            if fsp and not fsp.exists():
                fail(str(f.relative_to(SITE)), f"dead link/image: {u}")

    # every real blog post: JSON-LD parses AND BlogPosting has required fields
    for f in (SITE / "blog").rglob("index.html"):
        s = str(f)
        if any(x in s for x in ("/category/", "/archive/", "/page/")): continue
        if len(f.relative_to(SITE).parts) < 3: continue
        html = f.read_text(encoding="utf-8", errors="ignore")
        blocks = re.findall(r'<script type="application/ld\+json">(.*?)</script>', html, re.S)
        posting = None
        for b in blocks:
            try:
                d = json.loads(b)
            except json.JSONDecodeError as e:
                fail(str(f.relative_to(SITE)), f"invalid JSON-LD: {e}")
                continue
            if isinstance(d, dict) and d.get("@type") == "BlogPosting":
                posting = d
        if posting is None:
            warn(str(f.relative_to(SITE)), "no BlogPosting JSON-LD")
        else:
            for req in ("headline", "datePublished", "author"):
                if not posting.get(req):
                    fail(str(f.relative_to(SITE)), f"BlogPosting missing `{req}`")

# ---- 4. Report --------------------------------------------------------------
print("=" * 64)
print(f"PREFLIGHT — {len(FAILS)} fail(s), {len(WARNS)} warning(s)")
print("=" * 64)
for line in FAILS: print(line)
for line in WARNS: print(line)
if not FAILS and not WARNS:
    print("All clear. Safe to push.")
print("\nReminder: run the Chrome pass on live pages for visual + mobile-frozen-hook checks (not automatable here).")
sys.exit(1 if FAILS else 0)
