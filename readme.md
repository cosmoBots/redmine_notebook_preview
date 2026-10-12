# Redmine Notebook Preview

A Redmine plugin that renders Jupyter notebook (`.ipynb`) previews inline — directly on issue pages, wiki pages, and documents, without leaving Redmine.

> **EXPERIMENTAL:** This integration is available for evaluation, not yet a
> settled or generally supported feature. Keep it within the existing
> deployment flow rather than creating deployment branches or extra variants
> solely to isolate it. Compatibility and behavior may still change.

## Features

- **Inline previews** of `.ipynb` attachments on issues, wiki pages, and documents
- **Wiki macro** `{{notebook_preview(filename.ipynb)}}` for embedding previews in wiki content
- LaTeX formulas in notebook previews are rendered by the separate `redmine_cbots_latex` plugin.
- **Cache management** — previews are generated once and cached; admins can purge the cache from the plugin settings page
- **Report export** — usable in cosmoSys reports exported to PDF, ODT and DOCX; LaTeX formulas are converted to images
- **Permission-aware** — regenerate button is only shown to users with edit rights

---

## Requirements

- Redmine 6.x
- `redmine_cbots_latex` is a required plugin dependency, not an optional
  enhancement. Notebook Preview will refuse to load if it is missing; it also
  provides MathJax and static formula rendering.
- Python 3 with `nbconvert` installed and accessible to the Redmine process
- A writable directory for the preview cache

---

## Installation

### 1. Copy the plugin

```bash
git clone https://github.com/cosmobots/redmine_notebook_preview \
  plugins/redmine_notebook_preview
```

Instala primero
[`redmine_cbots_latex`](https://github.com/cosmoBots/redmine_cbots_latex) en
`plugins/redmine_cbots_latex`. `redmine_notebook_preview` comprueba esta
dependencia obligatoria al cargar y genera un error si no está instalada.

### 2. Install nbconvert

The plugin delegates conversion to `jupyter nbconvert`. Install it in a virtual environment:

```bash
python3 -m venv /opt/nbconvert-env
/opt/nbconvert-env/bin/pip install nbconvert nbformat jupyter_core matplotlib
```

### 3. Restart Redmine

Restart your Redmine process to load the plugin.

### 4. Configure the plugin

Go to **Administration → Plugins → Notebook Preview → Configure** and set:

| Setting | Description |
|---------|-------------|
| Jupyter binary path | Full path to the `jupyter` binary, e.g. `/opt/nbconvert-env/bin/jupyter` |
| Cache directory | Writable directory for cached HTML previews, e.g. `/var/cache/redmine/notebook_preview` |

---

## Usage

### Automatic previews on issues

Attach a `.ipynb` file to any issue. The preview will appear automatically below the issue description.

### Wiki macro

Embed a preview of a notebook attached to the current wiki page:

```
{{notebook_preview(analysis.ipynb)}}
```

### Regenerating a preview

If a preview fails or becomes stale, users with edit rights will see a **Regenerate preview** button below the preview area.

### Cache management

Admins can purge all cached previews at once from **Administration → Plugins → Notebook Preview → Configure**.

### Report export (PDF, ODT, DOCX)

When a page that uses `{{notebook_preview(...)}}` is exported to PDF, ODT or
DOCX (for example a cosmoSys report), the preview is included as static HTML:

- Images are embedded as plain base64 data URIs.
- LaTeX formulas are converted to PNG images by `redmine_cbots_latex`, because
  exporters cannot run MathJax. This uses matplotlib's `mathtext`, so it needs
  `matplotlib` in the same virtual environment as `jupyter` (see installation). It covers the common
  subset of LaTeX (fractions, roots, sums, Greek letters, sub/superscripts).
  Environments such as `align` or `matrix` are not supported and stay as text.
  If `matplotlib` is missing, formulas also stay as text.

Previews cached before this behaviour existed must be regenerated (purge the
cache from the plugin settings page).


---

## Notes

> **Air-gapped deployments:** MathJax is loaded from a CDN for LaTeX rendering.
> In environments without internet access, mathematical notation will not render.
> To support air-gapped deployments, configure `redmine_cbots_latex` to load
> MathJax locally.

---

## Uninstalling

```bash
bundle exec rake redmine:plugins:migrate NAME=redmine_notebook_preview VERSION=0 RAILS_ENV=production
```

Then delete the plugin folder and restart Redmine.

---

---

# Development

## Requirements

- Docker
- VS Code with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)


## Quick Start

### 1. Configure environment variables

```bash
cp .devcontainer/.env.example .devcontainer/.env
# Edit .env and set DB_PASSWORD and SECRET_KEY
```

### 2. Open in devcontainer

In VS Code: **F1 → Dev Containers: Reopen in Container**

This will:
- Build a Redmine image with Python and nbconvert pre-installed
- Start PostgreSQL and Redmine containers
- Mount the plugin folder into the container
- Forward port 3000 to your host

Redmine will be available at **http://localhost:3000**  
Default credentials: `admin` / `admin`


## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_PASSWORD` | `redmine` | PostgreSQL password |
| `SECRET_KEY` | `supersecretkey` | Rails secret key base |
| `JUPYTER_BIN` | Set in Dockerfile | Override jupyter binary path |
| `NOTEBOOK_CACHE_DIR` | Set in Dockerfile | Override cache directory |

`JUPYTER_BIN` and `NOTEBOOK_CACHE_DIR` are baked into the Docker image and work out of the box.
Only add them to `.env` if you need to override the image defaults.

## Useful Commands

```bash
# View logs
docker compose -f .devcontainer/docker-compose.yml logs -f redmine

# Open a shell in the Redmine container
docker compose -f .devcontainer/docker-compose.yml exec redmine bash

# Stop the environment
docker compose -f .devcontainer/docker-compose.yml down

# Reset everything including the database
docker compose -f .devcontainer/docker-compose.yml down -v

# Run tests (inside container)
bundle exec rake test TEST=plugins/redmine_notebook_preview/test/**/*_test.rb RAILS_ENV=test
```

## Production Notes

This Docker setup is intended for development only. For production:

- Generate a strong secret: `openssl rand -hex 64`
- Mount persistent volumes for `redmine_data` and `notebook_cache`
- Consider a reverse proxy (nginx, Caddy) in front of Redmine
- Set `JUPYTER_BIN` to the correct path for your Python environment

## License and contact

This plugin is distributed under GNU GPL v3; see [`LICENSE.txt`](LICENSE.txt).
For questions about this plugin, contact
[cosmobots.eu@gmail.com](mailto:cosmobots.eu@gmail.com).
