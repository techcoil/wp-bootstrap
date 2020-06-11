FROM wordpress:cli

USER root

COPY wp-bootstrap.sh /usr/local/bin/wp-bootstrap.sh

RUN apk add perl

USER www-data
WORKDIR /app

ENTRYPOINT ["/bin/bash", "/usr/local/bin/wp-bootstrap.sh"]
