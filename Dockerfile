FROM alpine:3.21

LABEL maintainer="Damir Kucic <dkucic@gmail.com>"
LABEL description="Environment for running OpenRouter API CLI"

# Install required packages with pinned versions
RUN apk add --no-cache \
    bash=5.2.37-r0 \
    curl=8.12.1-r0 \
    jq=1.7.1-r0

# Create a non-root user to run the application
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Create app directory
WORKDIR /app

# Copy the script
COPY openroutercli.sh /app/

# Set permissions
RUN chmod +x /app/openroutercli.sh && \
    chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Set up environment
ENV PATH="/app:$PATH"

# Use bash as the entrypoint shell
ENTRYPOINT ["/bin/bash"]

# Default command shows help
CMD ["/app/openroutercli.sh", "-h"]
