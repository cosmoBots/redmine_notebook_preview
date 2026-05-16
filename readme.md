# Redmine Test Environment

Local Redmine environment for testing plugins using Docker.

## Requirements
- Docker Desktop with WSL2
- VS Code with Docker extension

## Getting Started

```bash
# Start the environment
docker compose up -d

# Access Redmine at http://localhost:3000
# Default credentials: admin / admin
```

## Installing a Plugin

1. Copy or clone the plugin into the `plugins/` folder
2. Run migrations:
```bash
docker compose exec redmine bash -c "bundle install && rake redmine:plugins:migrate RAILS_ENV=production"
```
3. Restart Redmine:
```bash
docker compose restart redmine
```

## Removing a Plugin

```bash
docker compose exec redmine rake redmine:plugins:migrate NAME=plugin_name VERSION=0 RAILS_ENV=production
```

Then delete the plugin folder and restart:
```bash
docker compose restart redmine
```

## Stop the Environment

```bash
docker compose down
```

## Reset Everything (including database)

```bash
docker compose down -v
```