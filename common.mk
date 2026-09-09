# Define the path to the workspace root (adjust if your folder depth is different)
WORKSPACE_ROOT := ../
COMMON_DIR := $(WORKSPACE_ROOT)/common
COMMON_LV_CONF := $(COMMON_DIR)/lvgl_configs/linux/lv_conf.h

RELEASE_IMAGE := $(APP_NAME)-arm64-release
DEBUG_IMAGE := $(APP_NAME)-arm64-debug
RELEASE_STAMP := .build.release.stamp
DEBUG_STAMP := .build.debug.stamp
RELEASE_DIR := build/release
DEBUG_DIR := build/debug
DOCKER ?= podman

.PHONY: build build-debug package package-debug send send-debug clean

buildctl: $(SOURCES)

	SSH_PRIVATE_KEY=$(base64 -d <<< "$SSH_PRIVATE_KEY")

	buildctl \
	  --addr tcp://buildkitd.gocd.svc:1234 \
	  --tlscacert "/buildkit_secrets/ca.pem" \
	  --tlscert "/buildkit_secrets/cert.pem" \
	  --tlskey "/buildkit_secrets/key.pem" \
	  	build \
	  --frontend dockerfile.v0 \
	  --local context=$(WORKSPACE_ROOT) \
	  --local dockerfile=$(WORKSPACE_ROOT) \
	  --opt build-arg:SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY}" \
	  --opt build-arg:BUILD_PROFILE="$(PROFILE)" \
	  --opt build-arg:APP_NAME="$(APP_NAME)" \
	  --import-cache type=registry,ref=registry.polacoproject.net/nextui:buildcache \
	  --export-cache type=registry,ref=registry.polacoproject.net/nextui:buildcache \
	  --output type=local,dest=/tmp/$(ENV_DIR)/$(PACKAGE_NAME)

	mkdir -p $(ENV_DIR)/$(PACKAGE_NAME)/
	mv /tmp/$(ENV_DIR)/$(PACKAGE_NAME)/app/binary $(ENV_DIR)/$(PACKAGE_NAME)/$(APP_NAME)

	touch $(ENV_STAMP)

$(RELEASE_STAMP): ENV_DIR=$(RELEASE_DIR)
$(RELEASE_STAMP): ENV_STAMP=$(RELEASE_STAMP)
$(RELEASE_STAMP): PROFILE=release
$(RELEASE_STAMP): buildctl

$(DEBUG_STAMP): ENV_DIR=$(DEBUG_DIR)
$(DEBUG_STAMP): ENV_STAMP=$(DEBUG_STAMP)
$(DEBUG_STAMP): PROFILE=debug
$(DEBUG_STAMP): buildctl

package: $(RELEASE_STAMP)
	cp launch.sh pak.json $(RELEASE_DIR)/$(PACKAGE_NAME)
	tar -cvzf $(RELEASE_DIR)/$(PACKAGE_NAME).tar.gz $(RELEASE_DIR)/$(PACKAGE_NAME)

package-debug: $(DEBUG_STAMP)
	cp launch.sh pak.json $(DEBUG_DIR)/$(PACKAGE_NAME)
	tar -cvzf $(DEBUG_DIR)/$(PACKAGE_NAME).tar.gz $(DEBUG_DIR)/$(PACKAGE_NAME)

send: package
	sshpass -f .env rsync -vzri --rsync-path=/mnt/SDCARD/Tools/rsync --ignore-times $(RELEASE_DIR)/$(PACKAGE_NAME)/ $(REMOTE_PATH) -P

send-debug: package-debug
	sshpass -f .env rsync -vzri --rsync-path=/mnt/SDCARD/Tools/rsync --ignore-times $(DEBUG_DIR)/$(PACKAGE_NAME)/ $(REMOTE_PATH) -P

clean:
	rm -rf build/ $(RELEASE_STAMP) $(DEBUG_STAMP)
	$(DOCKER) rmi $(RELEASE_IMAGE) $(DEBUG_IMAGE) 2>/debug/null || true
