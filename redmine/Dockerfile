FROM redmine:6.1.2

USER root

# Install Python and venv
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Install nbconvert in an isolated venv
RUN python3 -m venv /opt/nbconvert-env \
    && /opt/nbconvert-env/bin/pip install --no-cache-dir \
        nbconvert \
        nbformat \
        jupyter_core

# Create cache directory with correct permissions
RUN mkdir -p /usr/src/redmine/notebook_cache \
    && chown -R redmine:redmine /usr/src/redmine/notebook_cache

ENV NBCONVERT_BIN=/opt/nbconvert-env/bin/jupyter
ENV NOTEBOOK_CACHE_DIR=/usr/src/redmine/notebook_cache

USER redmine