FROM debian:bookworm-20250811-slim
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y util-linux && \
    rm -rf /var/lib/apt/lists/*
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && mkdir -p /media
ENTRYPOINT ["/entrypoint.sh"]
