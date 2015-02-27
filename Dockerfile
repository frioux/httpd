FROM httpd:2.4
MAINTAINER Arthur Axel fREW Schmdit <frioux@gmail.com>
EXPOSE 443

COPY ./httpd.conf /usr/local/apache2/conf/httpd.conf.template
COPY ./httpd-gen.pl /usr/local/apache2/conf/httpd-gen.pl

RUN env DEBIAN_FRONTEND=noninteractive apt-get update && \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libtemplate-perl openssl && \
    rm -rf /var/lib/apt/lists/*

# VOLUME [ "/usr/local/apache2/ssl/wild.cert", "/usr/local/apache2/ssl/wild.key", "/var/www/blog" ]
CMD ["perl", "conf/httpd-gen.pl"]
