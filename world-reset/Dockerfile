FROM alpine:latest
RUN apk add --no-cache bash go jq
RUN go install github.com/itzg/rcon-cli@latest
ENV PATH="/root/go/bin:${PATH}"
COPY world-reset.sh /world-reset.sh
RUN chmod +x /world-reset.sh
CMD ["/world-reset.sh"]