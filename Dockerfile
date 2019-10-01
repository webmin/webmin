FROM ubuntu:18.04

ARG version=1.931

# --no-install-recommends \
RUN apt-get -y update && apt-get install -y \
	base \
	ca-certificates \
	fakeroot \
	git \
	less \
	perl

WORKDIR /webmin

# Initial configuration
COPY ./ .
RUN git clone https://github.com/authentic-theme/authentic-theme.git

# Fix empty /usr/local/bin dir
RUN rm -r /usr/local/bin/
RUN ln -s /usr/bin/ /usr/local/

# Won't make anything if we don't manually create the destination folders for some reason
RUN mkdir tarballs deb

RUN ./apply_rs_patch

# Make the tarball
RUN ./makedist.pl ${version}

# Make the deb from the tarball
RUN ./makedebian.pl ${version}

CMD [ "sleep", "1" ]
