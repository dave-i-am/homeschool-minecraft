FROM alpine:latest

RUN apk add --no-cache bash curl

COPY alerts.sh /alerts.sh

RUN chmod +x /alerts.sh

CMD ["/alerts.sh"]
