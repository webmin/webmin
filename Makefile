
VERSION=$(shell cat version)

all: deb

deb:
	@echo "Building Webmin ${VERSION} Debian Package"
	@echo "Building Docker Container..."
	@docker build --tag webminpkg .
	@echo "Copying .deb from container"
	@docker cp $(shell docker ps -l -f ancestor=webminpkg --format "{{.ID}}"):/webmin/deb/webmin_${VERSION}_all.deb ./webmin_${VERSION}.deb
	@echo Done

