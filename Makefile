
VERSION=$(shell cat version)

all: deb

deb:
	@echo "Building Webmin ${VERSION} Debian Package"
	@echo "Checking for rs-webmin source..."
	@cp -r ../rs-webmin/rootsecure-registration-module .
	@echo "Building Docker Container..."
	@docker build --build-arg version=${VERSION} --tag webminpkg .
	@echo "Copying .deb from container"
	@./rs_copy_deb ${VERSION}
	@rm -r rootsecure-registration-module
	@echo "Done. Debian packages available:"
	@ls -1 *.deb

