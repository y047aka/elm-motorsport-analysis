ARG CLAUDE_CODE_VERSION=latest

# Stage 1: nushell
FROM ghcr.io/nushell/nushell:latest-bookworm AS nushell-stage

# Stage 2: Rust tools
FROM rust:1.88-bookworm AS rust-stage
RUN rustup component add rustfmt clippy \
    && cargo install cargo-watch cargo-expand

# Stage 3: Elm compiler
FROM debian:bookworm-slim AS elm-stage
# https://github.com/elm/compiler/blob/master/installers/linux/README.md
RUN apt-get update && apt-get install -y curl \
    && curl -L -o elm.gz https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz \
    && gunzip elm.gz \
    && chmod +x elm \
    && mv elm /usr/local/bin/ \
    && rm -rf /var/lib/apt/lists/*

# Stage 4: Development environment without Agent CLI
FROM node:22-bookworm AS without-agent-cli

RUN npm install -g npm@latest

# Copy tools from build stages
COPY --from=nushell-stage /usr/bin/nu /usr/local/bin/nu
COPY --from=rust-stage /usr/local/cargo /usr/local/cargo
COPY --from=rust-stage /usr/local/rustup /usr/local/rustup
COPY --from=elm-stage /usr/local/bin/elm /usr/local/bin/elm

# Setup environment and tools
ENV CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH=/usr/local/cargo/bin:$PATH

ARG USERNAME=node

RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && npm install -g elm-format elm-test elm-review elm-verify-examples elm-pages \
    && mkdir -p /home/$USERNAME/.elm /home/$USERNAME/.cargo /home/$USERNAME/.rustup \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME /usr/local/cargo /usr/local/rustup

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/$USERNAME/.cursor && \
    chown -R $USERNAME:$USERNAME /workspace /home/$USERNAME/.cursor

WORKDIR /workspace


# Stage 5: Final development environment with Claude CLI
FROM without-agent-cli

# Install Cursor CLI
# https://docs.cursor.com/en/cli/installation
USER $USERNAME
RUN curl https://cursor.com/install -fsS | bash
ENV PATH="/home/$USERNAME/.local/bin:$PATH"

# Install Claude CLI
USER root
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

USER $USERNAME
