################################################################################
#
# host-esp-linux-bsp
#
################################################################################

ESP_LINUX_BSP_VERSION = 22455bf67ccc1aace91a547557af43fd85192281
ESP_LINUX_BSP_SITE = file:///userdata/esp32s31/archives
ESP_LINUX_BSP_SOURCE = esp-linux-bsp-22455bf67ccc1aace91a547557af43fd85192281.tar.gz
ESP_LINUX_BSP_SITE_METHOD = file
ESP_LINUX_BSP_INSTALL_TARGET = NO
HOST_ESP_LINUX_BSP_DEPENDENCIES = host-zstd

define HOST_ESP_LINUX_BSP_INSTALL_CMDS
	rm -rf $(HOST_DIR)/share/esp-linux-bsp
	$(INSTALL) -D -m 0644 $(@D)/configs/esp32s31-layout.cfg \
		$(HOST_DIR)/share/esp-linux-bsp/configs/esp32s31-layout.cfg
	$(INSTALL) -D -m 0755 $(@D)/tools/buildroot_post_image.sh \
		$(HOST_DIR)/share/esp-linux-bsp/tools/buildroot_post_image.sh
	$(INSTALL) -D -m 0755 $(@D)/tools/gen_esp_flash_image.sh \
		$(HOST_DIR)/share/esp-linux-bsp/tools/gen_esp_flash_image.sh
	$(INSTALL) -D -m 0755 $(@D)/tools/gen_fit_boot0_esp32s31.sh \
		$(HOST_DIR)/share/esp-linux-bsp/tools/gen_fit_boot0_esp32s31.sh
	$(INSTALL) -D -m 0755 $(@D)/tools/gen_spl_img_esp32s31.sh \
		$(HOST_DIR)/share/esp-linux-bsp/tools/gen_spl_img_esp32s31.sh
endef

$(eval $(host-generic-package))
