"""
For blog posts, use the post's own cover banner (1200x630, with official
Microsoft product icons) as the OpenGraph / Twitter share image, instead of
the plugin-generated card. Non-post pages keep the auto-generated social card.

Runs AFTER the social plugin (event_priority < 0) so it can rewrite the meta
tags the plugin appended to page.meta["meta"].
"""
import os
import posixpath
from mkdocs.plugins import event_priority


@event_priority(-50)
def on_page_content(html, page, config, files, **kwargs):
    src = page.file.src_uri
    if not src.startswith("blog/posts/"):
        return html

    stem = os.path.splitext(os.path.basename(src))[0]
    base = (config.site_url or "/").rstrip("/") + "/"
    banner = posixpath.join(base, f"assets/img/banners/{stem}.png")

    # Confirm the banner exists in the build; fall back to the plugin card if not.
    banner_src = f"assets/img/banners/{stem}.png"
    if files.get_file_from_path(banner_src) is None:
        return html

    for tag in page.meta.get("meta", []):
        if tag.get("property") == "og:image":
            tag["content"] = banner
        elif tag.get("property") == "og:image:type":
            tag["content"] = "image/png"
        elif tag.get("name") == "twitter:image":
            tag["content"] = banner
    return html
