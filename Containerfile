# syntax=docker/dockerfile:1

# Developer/runtime image. Builds locally to install Kiro via the installer.
# No binaries are distributed by this repo; the image downloads Kiro during build.
FROM debian:stable-slim

# Allow CI to optionally bypass verification during smoke builds without changing defaults
ARG KIRO_SKIP_VERIFY=false

ENV DEBIAN_FRONTEND=noninteractive \
    KIRO_REQUIRE_VERIFY=true \
    KIRO_SKIP_VERIFY=${KIRO_SKIP_VERIFY}

# Base runtime deps + tools needed by the installer
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget jq openssl tar coreutils \
    # Common Electron runtime deps (may vary by environment)
    libnss3 libxss1 libasound2 libx11-6 libxkbfile1 libxkbcommon0 libxdamage1 libxrandr2 libgbm1 libxshmfence1 libdrm2 libxtst6 libgtk-3-0 \
    xdg-utils fonts-liberation \
  && rm -rf /var/lib/apt/lists/*

# Create app directory and copy the installer repo
WORKDIR /app
COPY . /app

# Install Kiro inside the image using the orchestrator
# We run as root during build and install system-wide to /opt/kiro
RUN bash -lc "./scripts/install-kiro.sh --force" \
  && ln -sf /opt/kiro/bin/kiro /usr/local/bin/kiro

# Default to a non-root user for runtime safety
RUN id -u kiro &>/dev/null || useradd -m -u 10001 kiro
USER kiro
WORKDIR /home/kiro

# Display hint by default; override with `--entrypoint kiro` or specify CMD at runtime
CMD ["bash", "-lc", "echo 'Container built. To run Kiro: set DISPLAY, mount /tmp/.X11-unix, and run \"kiro\".'"]
