FROM redmine:6.1.2

USER root

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/nbconvert-env \
    && /opt/nbconvert-env/bin/pip install --no-cache-dir \
        nbconvert \
        nbformat \
        jupyter_core

RUN mkdir -p /usr/src/redmine/notebook_cache \
    && chown -R redmine:redmine /usr/src/redmine/notebook_cache

ENV JUPYTER_BIN=/opt/nbconvert-env/bin/jupyter
ENV NOTEBOOK_CACHE_DIR=/usr/src/redmine/notebook_cache

USER redmine