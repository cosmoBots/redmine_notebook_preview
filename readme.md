# Redmine Notebook Preview — Dev & Test Environment

Local Redmine environment for developing and testing the `redmine_notebook_preview` plugin.
Uses Docker and VS Code devcontainers for a consistent, reproducible setup.

## Requirements

- Docker Desktop with WSL2 backend
- VS Code with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

## Quick Start

### 1. Configure environment variables

```bash
cp .env.example .env
# Edit .env and set DB_PASSWORD and SECRET_KEY
```

### 2. Open in devcontainer

In VS Code: **F1 → Dev Containers: Reopen in Container**

This will:
- Build the Redmine image with Python and nbconvert pre-installed
- Start PostgreSQL and Redmine containers
- Mount the `plugins/` and `themes/` folders into the container
- Forward port 3000 to your host

Redmine will be available at **http://localhost:3000**  
Default credentials: `admin` / `admin`

### 3. Run plugin migrations (first time only)

```bash
docker compose -f .devcontainer/docker-compose.yml exec redmine \
  bash -c "bundle install && rake redmine:plugins:migrate RAILS_ENV=production"
```

Then restart:
```bash
docker compose -f .devcontainer/docker-compose.yml restart redmine
```

---

## Plugin Configuration

After first login go to **Administration → Plugins → Notebook Preview → Configure**:

| Setting | Default | Description |
|---------|---------|-------------|
| Jupyter binary path | `/opt/nbconvert-env/bin/jupyter` | Full path to the `jupyter` binary |
| Cache directory | `/usr/src/redmine/notebook_cache` | Where converted HTML previews are stored |

The defaults are baked into the Docker image and work out of the box for this dev environment.
For production deployments with a different Python environment, update these settings.

---

## Environment Variables

Variables are loaded from `.env` (gitignored). Copy `.env.example` to get started.

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_PASSWORD` | `redmine` | PostgreSQL password |
| `SECRET_KEY` | `supersecretkey` | Rails secret key base |
| `JUPYTER_BIN` | Set in Dockerfile | Override jupyter binary path |
| `NOTEBOOK_CACHE_DIR` | Set in Dockerfile | Override cache directory |

`JUPYTER_BIN` and `NOTEBOOK_CACHE_DIR` are already set in the Dockerfile — only add them
to `.env` if you need to override the image defaults.

---

## Installing / Removing Plugins

**Install:**

1. Copy or clone the plugin into `plugins/`
```bash
git clone https://github.com/cosmobots/redmine_notebook_preview \
  plugins/redmine_notebook_preview
```
2. Run migrations and restart (see Quick Start step 3)

**Remove:**
```bash
docker compose -f .devcontainer/docker-compose.yml exec redmine \
  rake redmine:plugins:migrate NAME=plugin_name VERSION=0 RAILS_ENV=production
```
Then delete the plugin folder and restart.

---

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

---

## Production Deployment

This Docker setup is intended for development only. For production:

- Use a proper secret for `SECRET_KEY_BASE` — generate with `openssl rand -hex 64`
- Mount a persistent volume for `redmine_data` (user uploaded files)
- Configure a reverse proxy (nginx/caddy) in front of Redmine
- Ensure `notebook_cache` is on a persistent volume or an external storage path
- Set `JUPYTER_BIN` to the correct path for your Python environment

---

## Notes

> **Air-gapped deployments:** MathJax is loaded from a CDN for LaTeX rendering in notebook
> previews. In environments without internet access, mathematical notation will not render.
> To support air-gapped deployments, download MathJax locally and update
> `assets/javascripts/notebook_preview.js` to load it from a local path.