
VERSION=$(shell cat version)

all: package dev_package


.PHONY : clean package dev_package

package:
	@echo "Building Webmin ${VERSION} Debian Package"
	@echo "Building Docker Container... (version=${VERSION}, prod=true)"
	@docker build --build-arg version=${VERSION} --build-arg prod=true --tag webminpkg .
	@echo "Copying .deb from container"
	@./rs_copy_deb ${VERSION} true
	@echo "Done. Debian packages available:"
	@ls -1 *.deb

dev_package:
	@echo "Building Webmin ${VERSION} Debian Package"
	@echo "Building Docker Container... (version=${VERSION}, prod=false)"
	@docker build --build-arg version=${VERSION} --build-arg prod=false --tag webminpkg .
	@echo "Copying .deb from container"
	@./rs_copy_deb ${VERSION} false
	@echo "Done. Debian packages available:"
	@ls -1 *.deb

clean:
	@./rs_cleanup
	@rm -fv *rootsecure_webmin*.deb
