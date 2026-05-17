# Redmine Notebook Preview

A Redmine plugin that renders Jupyter notebook (`.ipynb`) previews inline — directly on issue pages, wiki pages, and documents, without leaving Redmine.

## Features

- **Inline previews** of `.ipynb` attachments on issues, wiki pages, and documents
- **Wiki macro** `{{notebook_preview(filename.ipynb)}}` for embedding previews in wiki content
- **LaTeX rendering** via MathJax
- **Cache management** — previews are generated once and cached; admins can purge the cache from the plugin settings page
- **Permission-aware** — regenerate button is only shown to users with edit rights

---

## Requirements

- Redmine 6.x
- Python 3 with `nbconvert` installed and accessible to the Redmine process
- A writable directory for the preview cache

---

## Installation

### 1. Copy the plugin

```bash
git clone https://github.com/cosmobots/redmine_notebook_preview \
  plugins/redmine_notebook_preview
```

### 2. Install nbconvert

The plugin delegates conversion to `jupyter nbconvert`. Install it in a virtual environment:

```bash
python3 -m venv /opt/nbconvert-env
/opt/nbconvert-env/bin/pip install nbconvert nbformat jupyter_core
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

---

## Notes

> **Air-gapped deployments:** MathJax is loaded from a CDN for LaTeX rendering.
> In environments without internet access, mathematical notation will not render.
> To support air-gapped deployments, download MathJax locally and update
> `assets/javascripts/notebook_preview.js` to load it from a local path.

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
```

## Production Notes

This Docker setup is intended for development only. For production:

- Generate a strong secret: `openssl rand -hex 64`
- Mount persistent volumes for `redmine_data` and `notebook_cache`
- Consider a reverse proxy (nginx, Caddy) in front of Redmine
- Set `JUPYTER_BIN` to the correct path for your Python environment