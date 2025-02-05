FROM python

COPY websockify-*.tar.gz /

RUN python3 -m pip install websockify-*.tar.gz
RUN rm -rf /websockify-* /root/.cache

VOLUME /data

EXPOSE 80
EXPOSE 443

WORKDIR /opt/websockify

ENTRYPOINT ["/usr/local/bin/websockify"]
CMD ["--help"]
