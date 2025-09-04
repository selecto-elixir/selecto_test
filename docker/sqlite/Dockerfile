FROM alpine:latest

# Install SQLite and tools
RUN apk add --no-cache \
    sqlite \
    sqlite-dev \
    python3 \
    py3-pip \
    bash

# Install sqlite-web for web interface
RUN pip3 install sqlite-web --break-system-packages

# Create directories for database and scripts
RUN mkdir -p /data /scripts

# Set working directory
WORKDIR /data

# Expose port for sqlite-web
EXPOSE 8080

# Default command starts sqlite-web
CMD ["sqlite_web", "--host", "0.0.0.0", "--port", "8080", "/data/pagila.db"]