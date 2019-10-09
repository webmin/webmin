
VERSION=$(shell cat version)
PROD=true

all: deb

deb:
	@echo "Building Webmin ${VERSION} Debian Package"
	@echo "Checking for rs-webmin source..."
	@cp -r ../rs-webmin/rootsecure-registration-module ./rootsecure-registration
	@echo "Building Docker Container... (version=${VERSION}, prod=${PROD})"
	@docker build --build-arg version=${VERSION} --build-arg prod=${PROD} --tag webminpkg .
	@echo "Copying .deb from container"
	@./rs_copy_deb ${VERSION} ${PROD}
	@rm -r rootsecure-registration
	@echo "Done. Debian packages available:"
	@ls -1 *.deb

