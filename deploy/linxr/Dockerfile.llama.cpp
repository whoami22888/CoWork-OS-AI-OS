# syntax=docker/dockerfile:1
# Fallback image: build llama-server from source for linux/arm64.
# Prefer pulling ghcr.io/ggml-org/llama.cpp:server --platform linux/arm64.
# Building this on a Linxr QEMU TCG VM will take a long time (possibly hours).
# Prefer building on a faster arm64 machine and loading the image into Linxr,
# or use the official prebuilt Ubuntu arm64 tarball (see setup-in-vm.sh).
#
#   docker build --platform linux/arm64 -t jarvis-llama-server:local -f deploy/linxr/Dockerfile.llama.cpp .
#
# ON-DEVICE VERIFICATION REQUIRED. Not built on the development box.

ARG LLAMA_CPP_REF=b12600
FROM --platform=$TARGETPLATFORM ubuntu:24.04 AS build
ARG LLAMA_CPP_REF
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake git ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone --depth 1 --branch "${LLAMA_CPP_REF}" https://github.com/ggml-org/llama.cpp.git .
# CPU-only. Do not enable CUDA/Vulkan on the S23 (no usable GPU in the VM).
RUN cmake -B build -DGGML_NATIVE=OFF -DGGML_CPU=ON -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build --target llama-server -j"$(nproc)"

FROM --platform=$TARGETPLATFORM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      libgomp1 ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /src/build/bin/llama-server /usr/local/bin/llama-server
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/llama-server"]
