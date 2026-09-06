FROM alpine:3.24

RUN apk add --no-cache bash=5.3.3-r1 curl=8.17.0-r1

COPY --chmod=755 alerts.sh /alerts.sh

CMD ["/alerts.sh"]
