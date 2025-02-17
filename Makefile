.PHONY: dev
OCI_ENGINE?= podman
dev-image:
	@echo "Building development image from $(CONTAINERFILE)..."
	$(OCI_ENGINE) build -f $(CONTAINERFILE) -t dev-image:latest .
	$(OCI_ENGINE) run --rm -p 8888:8888 --name dev_jupyterlab dev-image:latest start-notebook.sh --NotebookApp.token=""
