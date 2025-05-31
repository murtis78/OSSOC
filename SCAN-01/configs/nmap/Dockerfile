FROM alpine:3.18

# Install Nmap and dependencies
RUN apk update && \
    apk add --no-cache \
    nmap \
    nmap-scripts \
    python3 \
    py3-pip \
    curl \
    bash \
    jq \
    xmlstarlet \
    coreutils && \
    rm -rf /var/cache/apk/*

# Install Python dependencies for report processing
RUN pip3 install --no-cache-dir \
    python-nmap \
    xmltodict \
    requests \
    schedule

# Create directories
RUN mkdir -p /reports /scripts /etc/nmap

# Copy Nmap scripts and configuration
COPY scripts/ /scripts/
COPY nmap.conf /etc/nmap/
COPY nse_scripts/ /usr/share/nmap/scripts/

# Set permissions
RUN chmod +x /scripts/*.sh && \
    chmod +x /scripts/*.py

# Create non-root user
RUN addgroup -g 1001 nmap && \
    adduser -D -u 1001 -G nmap nmap

# Set working directory
WORKDIR /scripts

# Switch to non-root user
USER nmap

# Default command
CMD ["/scripts/nmap-daemon.sh"]