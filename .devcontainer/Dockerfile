ARG CLAUDE_CODE_VERSION=latest

# Stage 1: nushell
FROM ghcr.io/nushell/nushell:latest-bookworm AS nushell-stage

# Stage 3: Elm compiler
FROM debian:bookworm-slim AS elm-stage
# https://github.com/elm/compiler/blob/master/installers/linux/README.md
RUN apt-get update && apt-get install -y curl \
    && curl -L -o elm.gz https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz \
    && gunzip elm.gz \
    && chmod +x elm \
    && mv elm /usr/local/bin/ \
    && rm -rf /var/lib/apt/lists/*

# Stage 4: Base tools installation using official Playwright image
FROM node:22-bookworm AS base-tools

RUN npm install -g npm@latest

# Install basic development tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    less \
    git \
    procps \
    fzf \
    zsh \
    man-db \
    unzip \
    gnupg2 \
    gh \
    jq \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Stage 5: Development environment without Agent CLI
FROM base-tools AS without-agent-cli

# Copy tools from build stages
COPY --from=nushell-stage /usr/bin/nu /usr/local/bin/nu
COPY --from=elm-stage /usr/local/bin/elm /usr/local/bin/elm

ARG USERNAME=node

RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && npm install -g elm-format elm-test elm-review elm-verify-examples elm-pages \
    && mkdir -p /home/$USERNAME/.elm \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/$USERNAME/.cursor && \
    chown -R $USERNAME:$USERNAME /workspace /home/$USERNAME/.cursor

WORKDIR /workspace


# Stage 6: Final development environment with Claude CLI
FROM without-agent-cli

# Install Codex CLI
RUN npm install -g @openai/codex@latest

# Install Cursor CLI
# https://docs.cursor.com/en/cli/installation
USER $USERNAME
RUN curl https://cursor.com/install -fsS | bash
ENV PATH="/home/$USERNAME/.local/bin:$PATH"

# Install Claude CLI
USER root
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

USER $USERNAME
