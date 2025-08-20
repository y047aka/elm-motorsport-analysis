# Multi-language development environment: Elm + Node.js + Rust

# Stage 0: nushell
FROM ghcr.io/nushell/nushell:latest-bookworm AS nushell-stage

# Stage 1: Rust tools
FROM rust:1.88-bookworm AS rust-stage
RUN apt-get update && apt-get install -y build-essential pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/* \
    && rustup component add rustfmt clippy \
    && cargo install cargo-watch cargo-expand

# Stage 2: Node.js with latest npm
FROM node:22-bookworm-slim AS node-stage
RUN npm install -g npm@latest

# Stage 3: Elm compiler
FROM debian:bookworm-slim AS elm-stage
# Install Elm and its tools
# https://github.com/elm/compiler/blob/master/installers/linux/README.md
RUN apt-get update && apt-get install -y curl \
    && curl -L -o elm.gz https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz \
    && gunzip elm.gz \
    && chmod +x elm \
    && mv elm /usr/local/bin/ \
    && rm -rf /var/lib/apt/lists/*

# Stage 4: Final development environment
FROM mcr.microsoft.com/devcontainers/base:ubuntu

ARG USERNAME=node

# Install system packages
RUN apt-get update && apt-get install -y \
    curl wget git build-essential pkg-config libssl-dev ca-certificates sudo \
    && rm -rf /var/lib/apt/lists/* \
    && adduser $USERNAME

# Copy tools from build stages
COPY --from=nushell-stage /usr/bin/nu /usr/local/bin/nu
COPY --from=rust-stage /usr/local/cargo /usr/local/cargo
COPY --from=rust-stage /usr/local/rustup /usr/local/rustup
COPY --from=node-stage /usr/local/bin/node /usr/local/bin/node
COPY --from=node-stage /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=elm-stage /usr/local/bin/elm /usr/local/bin/elm

# Setup environment and tools
ENV CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH=/usr/local/cargo/bin:$PATH

RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && npm install -g elm-format elm-test elm-review elm-verify-examples elm-pages \
    && mkdir -p /home/$USERNAME/.elm /home/$USERNAME/.cargo /home/$USERNAME/.rustup \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME /usr/local/cargo /usr/local/rustup

# Install Cursor CLI
# https://docs.cursor.com/en/cli/installation
USER $USERNAME
RUN curl https://cursor.com/install -fsS | bash
ENV PATH="/home/$USERNAME/.local/bin:$PATH"

# Setup Claude Code
USER root
RUN npm install -g @anthropic-ai/claude-code

USER $USERNAME
WORKDIR /workspace
