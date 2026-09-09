FROM rust:bookworm AS base

RUN mkdir -p /root/.ssh && ssh-keyscan github.com >> /root/.ssh/known_hosts

RUN apt-get update && apt-get install -y libclang-dev clang gcc-aarch64-linux-gnu && \
	rm -rf /var/lib/apt/lists/*

RUN rustup target add aarch64-unknown-linux-gnu

#----------------------------------

FROM base AS builder

ARG BUILD_PROFILE=release
ARG APP_NAME=nextui
ENV DEP_LV_CONFIG_PATH=/app/common/lvgl_configs/linux
ENV CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
ENV CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc
ENV CXX_aarch64_unknown_linux_gnu=aarch64-linux-gnu-g++

WORKDIR /app

COPY . .
RUN --mount=type=ssh \
    --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,target=/app/target,sharing=locked \
    if [ "$BUILD_PROFILE" = "release" ]; then \
        cargo build --target=aarch64-unknown-linux-gnu --release -p $APP_NAME && \
        cp /app/target/aarch64-unknown-linux-gnu/release/$APP_NAME /app/binary; \
    else \
        cargo build --target=aarch64-unknown-linux-gnu -p $APP_NAME && \
        cp /app/target/aarch64-unknown-linux-gnu/debug/$APP_NAME /app/binary; \
    fi

#----------------------------------

FROM scratch AS exporter

# Copy only the final binary from the builder stage
COPY --from=builder /app/binary /app/binary
