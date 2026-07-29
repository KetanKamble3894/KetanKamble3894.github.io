# Adding content (the 2-minute version)

Everything here is Markdown. You edit a file, commit to `main`, and GitHub Actions
rebuilds and deploys the site automatically. No build tools needed on your side.

## Add a new script (e.g. a Teams / M365 / AD script)

1. Put the `.ps1` file in `docs/assets/scripts/`.
2. Copy `_templates/script-page.md` to `docs/scripts/<your-slug>.md` and fill it in
   (title, one-liner, tags, and point the snippet at your `.ps1`).
3. (Optional) Drop the Power BI `.pbit` in `docs/assets/pbit/` and a screenshot in
   `docs/assets/img/`, then update the two links in the page.
4. Add one line to `mkdocs.yml` under `nav: > Scripts:` —
   `      - Your Title: scripts/<your-slug>.md`
5. Commit + push. Done — it's live in ~1 minute.

**Tags to choose from** (use as many as fit):
`Intune` · `Entra ID` · `Microsoft Graph` · `Microsoft 365` · `Windows / Autopilot` ·
`Defender / Security` · `Azure Automation` · `Power BI`

## Add a Power BI report page

Same idea: copy an existing file in `docs/powerbi/`, rename, edit, add a nav line under
`Power BI:`. Cross-link it to its script.

## Add a blog post

1. Copy `_templates/blog-post.md` to `docs/blog/posts/<your-slug>.md`.
2. Set the `date:`, `categories:`, `tags:`, write the post. The blog index, tags, RSS
   feed and archive all update themselves — no nav edit needed.

## Add a new project (e.g. Jarvis)

1. Create `docs/projects/<project>/index.md` (copy the Zero-Access one as a model).
2. Add it to `mkdocs.yml` under `Projects:` and to the shelf in `docs/projects/index.md`.

## Preview locally before pushing (optional)

```
pip install -r requirements-docs.txt
python -m mkdocs serve
```
Open http://127.0.0.1:8000/ — it live-reloads as you edit.
