# Define the path to the workspace root (adjust if your folder depth is different)
WORKSPACE_ROOT := ../
COMMON_DIR := $(WORKSPACE_ROOT)/common
COMMON_LV_CONF := $(COMMON_DIR)/lvgl_configs/linux/lv_conf.h

RELEASE_IMAGE := $(APP_NAME)-arm64-release
DEV_IMAGE := $(APP_NAME)-arm64-dev
RELEASE_STAMP := .build.release.stamp
DEV_STAMP := .build.dev.stamp
RELEASE_DIR := build/release
DEV_DIR := build/dev
DOCKER ?= podman

.PHONY: build build-dev package package-dev send send-dev clean

$(RELEASE_STAMP): $(SOURCES)
	rm -rf $(RELEASE_DIR) $(RELEASE_STAMP)
	mkdir -p $(RELEASE_DIR)/
	$(DOCKER) buildx build --ssh default --build-arg BUILD_PROFILE=release --platform=linux/arm64 -t $(RELEASE_IMAGE) -f Dockerfile $(WORKSPACE_ROOT) --load
	touch $(RELEASE_STAMP)

$(DEV_STAMP): $(SOURCES)
	rm -rf $(DEV_DIR) $(DEV_STAMP)
	mkdir -p $(DEV_DIR)/
	$(DOCKER) buildx build --ssh default --build-arg BUILD_PROFILE=dev --platform=linux/arm64 -t $(DEV_IMAGE) -f Dockerfile $(WORKSPACE_ROOT) --load
	touch $(DEV_STAMP)

build: $(RELEASE_STAMP)

build-dev: $(DEV_STAMP)

package: $(RELEASE_STAMP)
	$(DOCKER) rm extract-release || true
	$(DOCKER) create --name extract-release $(RELEASE_IMAGE)
	$(DOCKER) cp extract-release:/app/binary $(RELEASE_DIR)/$(APP_NAME)
	$(DOCKER) rm extract-release
	rm -rf $(RELEASE_DIR)/$(PACKAGE_NAME) || true
	mkdir -p $(RELEASE_DIR)/$(PACKAGE_NAME)
	cp $(RELEASE_DIR)/$(APP_NAME) launch.sh pak.json $(RELEASE_DIR)/$(PACKAGE_NAME)

package-dev: $(DEV_STAMP)
	$(DOCKER) rm extract-dev || true
	$(DOCKER) create --name extract-dev $(DEV_IMAGE)
	$(DOCKER) cp extract-dev:/app/binary $(DEV_DIR)/$(APP_NAME)
	$(DOCKER) rm extract-dev
	rm -rf $(DEV_DIR)/$(PACKAGE_NAME) || true
	mkdir -p $(DEV_DIR)/$(PACKAGE_NAME)
	cp $(DEV_DIR)/$(APP_NAME) launch.sh pak.json $(DEV_DIR)/$(PACKAGE_NAME)

send: package
	sshpass -f .env rsync -vzri --rsync-path=/mnt/SDCARD/Tools/rsync --ignore-times $(RELEASE_DIR)/$(PACKAGE_NAME)/ $(REMOTE_PATH) -P

send-dev: package-dev
	sshpass -f .env rsync -vzri --rsync-path=/mnt/SDCARD/Tools/rsync --ignore-times $(DEV_DIR)/$(PACKAGE_NAME)/ $(REMOTE_PATH) -P

clean:
	rm -rf build/ $(RELEASE_STAMP) $(DEV_STAMP)
	$(DOCKER) rmi $(RELEASE_IMAGE) $(DEV_IMAGE) 2>/dev/null || true
