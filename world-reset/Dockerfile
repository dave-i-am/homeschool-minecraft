FROM alpine:3.23
RUN apk add --no-cache bash=5.3.3-r1 go=1.25.8-r0 jq=1.8.1-r0 && \
    go install github.com/itzg/rcon-cli@v1.7.4
ENV PATH="/root/go/bin:${PATH}"
COPY --chmod=755 world-reset.sh /world-reset.sh
CMD ["/world-reset.sh"]