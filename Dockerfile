FROM ubuntu:18.04

ENV version=1.931

# --no-install-recommends \
RUN apt-get -y update && apt-get install -y \
	base \
	less \
	ca-certificates \
	fakeroot \
	perl

WORKDIR /webmin

# Initial configuration
COPY ./ .

RUN rm -r /usr/local/bin/
RUN ln -s /usr/bin/ /usr/local/

RUN mkdir tarballs
RUN ./makedist.pl ${version}

RUN mkdir deb
RUN ./makedebian.pl ${version}

#COPY config/redis.conf /etc/redis/redis.conf
#COPY scripts/startScanner .
#COPY scripts/startManager .
#COPY scripts/startOvsInterface .
#COPY scripts/killSupervisor .
#COPY scripts/resetOpenVAS.sh .

# Pre-generate any databases we can
#COPY config/supervisord.prerun.conf /etc/supervisor/supervisord.prerun.conf
#RUN /usr/bin/supervisord -c /etc/supervisor/supervisord.prerun.conf

# Debug and convenience scripts
#COPY scripts/debug/* ./scripts/

# Main OvsInterface process
#COPY --from=builder /go/src/github.com/root-secure/ovsInterface/ovsInterface .

#RUN ./updateFeeds

# Run Redis, OpenVAS, and OvsInterface
#COPY config/supervisord.conf /etc/supervisor/supervisord.conf
#CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
