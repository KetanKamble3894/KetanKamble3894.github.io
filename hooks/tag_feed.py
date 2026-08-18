"""
Post-process the RSS feeds after the mkdocs-rss-plugin writes them:

1. Fix ``<enclosure … length="None">`` — the plugin can only fill the byte
   length if it can fetch the image over the network at build time; when it
   can't (freshly-added banners not yet deployed, or an offline/CI build), it
   emits the literal ``None``, which is invalid RSS 2.0 and can make strict
   aggregators drop the thumbnail. We compute the real size from the built
   file on disk, so it is always correct and never depends on the network.

2. Fix ``<image><url>None</url></image>`` — give the channel a real logo.

3. Emit a tag-scoped feed ``feed_intune.xml`` — the plugin produces a single
   whole-site feed, but some communities/aggregators want just one topic. We
   keep only the ``<item>`` blocks carrying ``<category>Intune</category>``
   (the rss plugin is configured with ``categories: [categories, tags]``).

Runs at low event priority so it executes AFTER the rss plugin's own
on_post_build handler has written the feeds.
"""
import os
import re

from mkdocs.plugins import event_priority

TAG = "Intune"
CREATED = "feed_rss_created.xml"
UPDATED = "feed_rss_updated.xml"
TARGET = "feed_intune.xml"
LOGO_PATH = "assets/img/avatar/ketan-avatar.png"
FEED_DESCRIPTION = (
    "Intune-tagged posts from Ketan Kamble — Microsoft Intune, "
    "read-only by design, explained underneath the portal."
)


def _abs(site_url, rel):
    return (site_url or "/").rstrip("/") + "/" + rel.lstrip("/")


def _fix_enclosure_lengths(xml, site_dir):
    """Replace length="None" on each enclosure with the real on-disk byte size."""
    def repl(m):
        tag = m.group(0)
        um = re.search(r'url="([^"]+)"', tag)
        if not um:
            return tag
        path_m = re.search(r'https?://[^/]+/(.+)$', um.group(1))
        rel = path_m.group(1) if path_m else um.group(1).lstrip("/")
        local = os.path.join(site_dir, rel)
        if os.path.isfile(local):
            size = os.path.getsize(local)
            tag = re.sub(r'length="[^"]*"', 'length="%d"' % size, tag)
        return tag

    return re.sub(r"<enclosure\b[^>]*/>", repl, xml)


def _fix_channel_image(xml, logo_url):
    """Replace the placeholder <image><url>None</url> with a real logo URL."""
    return re.sub(
        r"(<image>\s*<url>)None(</url>)",
        r"\g<1>%s\g<2>" % logo_url,
        xml,
        count=1,
    )


def _clean_feed(xml, site_dir, logo_url):
    xml = _fix_enclosure_lengths(xml, site_dir)
    xml = _fix_channel_image(xml, logo_url)
    return xml


def _build_intune_feed(created_xml):
    """Filter the (already-cleaned) full feed down to Intune-tagged items."""
    first = created_xml.find("<item>")
    if first == -1:
        return None
    head = created_xml[:first]
    rest = created_xml[first:]

    items = re.findall(r"<item>.*?</item>", rest, re.S)
    tag_re = re.compile(r"<category>%s</category>" % re.escape(TAG))
    keep = [it for it in items if tag_re.search(it)]

    last_end = rest.rfind("</item>") + len("</item>")
    tail = rest[last_end:]

    head = head.replace(CREATED, TARGET)  # fix the atom:link rel="self" href
    head = re.sub(
        r"<title>(.*?)</title>",
        lambda m: "<title>%s — Intune</title>" % m.group(1),
        head,
        count=1,
    )
    head = re.sub(
        r"<description>.*?</description>",
        "<description>%s</description>" % FEED_DESCRIPTION,
        head,
        count=1,
    )
    return head + "\n".join(keep) + tail


@event_priority(-100)
def on_post_build(config, **kwargs):
    site_dir = config["site_dir"]
    site_url = config.get("site_url") or ""
    logo_url = _abs(site_url, LOGO_PATH)

    created_path = os.path.join(site_dir, CREATED)
    if not os.path.isfile(created_path):
        return

    # 1) Clean the full "created" feed (enclosure lengths + channel logo).
    created_xml = _clean_feed(
        open(created_path, encoding="utf-8").read(), site_dir, logo_url
    )
    with open(created_path, "w", encoding="utf-8") as fh:
        fh.write(created_xml)

    # 2) Clean the "updated" feed the same way, if present.
    updated_path = os.path.join(site_dir, UPDATED)
    if os.path.isfile(updated_path):
        updated_xml = _clean_feed(
            open(updated_path, encoding="utf-8").read(), site_dir, logo_url
        )
        with open(updated_path, "w", encoding="utf-8") as fh:
            fh.write(updated_xml)

    # 3) Emit the Intune-only feed from the cleaned "created" feed so it
    #    inherits the corrected enclosure lengths and channel logo.
    intune_xml = _build_intune_feed(created_xml)
    if intune_xml is not None:
        with open(os.path.join(site_dir, TARGET), "w", encoding="utf-8") as fh:
            fh.write(intune_xml)