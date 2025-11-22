# Dockerfile for ColorSCAD
# ColorSCAD is a script that helps export OpenSCAD models to AMF or 3MF format with color information preserved

FROM ubuntu:22.04 AS builder

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set locale to fix UTF-8 encoding issues during build
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Install dependencies
RUN apt-get update && apt-get install -y \
    bash \
    cmake \
    g++ \
    git \
    openscad \
    pkg-config \
    unzip \
    zip \
    && rm -rf /var/lib/apt/lists/*

# Copy local colorscad files
WORKDIR /opt/colorscad
COPY . .

# Build colorscad (this layer is cached unless source changes)
RUN mkdir build && \
    cd build && \
    cmake .. -DLIB3MF_TESTS=OFF && \
    cmake --build .

# Final stage - smaller image with only runtime dependencies
FROM ubuntu:22.04

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

# Install only runtime dependencies (OpenSCAD)
RUN apt-get update && apt-get install -y \
    bash \
    openscad \
    && rm -rf /var/lib/apt/lists/*

# Copy built binaries from builder stage
COPY --from=builder /opt/colorscad/3mfmerge/bin/3mfmerge /usr/local/bin/
COPY --from=builder /opt/colorscad/colorscad.sh /usr/local/bin/colorscad

# Set the PATH to include installed binaries
ENV PATH="/usr/local/bin:${PATH}"

# Create a working directory for user files
WORKDIR /workspace

# Default command shows help
CMD ["colorscad", "-h"]
