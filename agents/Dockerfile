# Autonomous agent container for heart (Flutter) and heart-api (Dart + Python).
# Built by agents/agent; FLUTTER_VERSION comes from .flutter-version.
FROM ubuntu:24.04
ARG FLUTTER_VERSION=3.47.0

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      git curl ca-certificates unzip xz-utils zip jq sudo \
      clang cmake ninja-build pkg-config libgtk-3-dev \
      iptables ipset dnsutils \
      python3 \
 && rm -rf /var/lib/apt/lists/*

# GitHub CLI (issue triage; agents have read-only PATs, so no push risk)
RUN mkdir -p -m 755 /etc/apt/keyrings \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

# uv — heart-api's Python entrypoint
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# Non-root user; sudo is limited to the firewall script and nothing else.
# (Claude Code refuses bypassPermissions as root — non-root is load-bearing.)
RUN useradd -m -s /bin/bash agent \
 && echo "agent ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/agent

# Flutter pinned to the repo's .flutter-version; shallow clone of the tag is
# enough to run the tool, tests, and codegen.
RUN git clone --depth 1 -b ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /opt/flutter \
 && chown -R agent:agent /opt/flutter
ENV PATH="/opt/flutter/bin:/home/agent/.local/bin:${PATH}"

USER agent
WORKDIR /home/agent

# Download the Dart SDK and Linux test artifacts while the build still has an
# open network (anything missed is fetched on demand — storage.googleapis.com
# is allowlisted at runtime). Linux only: the full precache pulls every
# platform and reliably stalls on the android bundles. Retry once — these
# CDN fetches are flaky and a stall here wedges the whole build.
RUN flutter --version \
 && (flutter precache --linux || flutter precache --linux) \
 && flutter config --enable-native-assets

# Claude Code (native installer)
RUN curl -fsSL https://claude.ai/install.sh | bash

# AWS CLI v2, user-local so this layer stays after the big cached ones.
# Only useful with `--aws` session creds; harmless without.
RUN curl -fsS "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/awscli.zip \
 && unzip -q /tmp/awscli.zip -d /tmp \
 && /tmp/aws/install --install-dir /home/agent/aws-cli --bin-dir /home/agent/.local/bin \
 && rm -rf /tmp/awscli.zip /tmp/aws
# Config lives on a named volume so auth/session state survives --rm.
ENV CLAUDE_CONFIG_DIR=/home/agent/.claude

# Scripts last: they change most often, and here that costs seconds, not a
# toolchain re-download.
COPY --chmod=755 init-firewall.sh /usr/local/bin/init-firewall.sh
COPY --chmod=755 entrypoint.sh /usr/local/bin/agent-entrypoint

ENTRYPOINT ["/usr/local/bin/agent-entrypoint"]
CMD ["bash"]
