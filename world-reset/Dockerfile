FROM alpine:3.23
RUN apk add --no-cache bash=5.3.3-r1 curl=8.17.0-r1 jq=1.8.1-r0 && \
    curl -fsSL "https://github.com/itzg/rcon-cli/releases/download/1.7.4/rcon-cli_1.7.4_linux_amd64.tar.gz" \
      | tar -xz -C /usr/local/bin rcon-cli
COPY --chmod=755 world-reset.sh /world-reset.sh
CMD ["/world-reset.sh"]