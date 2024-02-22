TARGET := iphone:clang:latest:14.0
PACKAGE_VERSION = 6.0.1
INSTALL_TARGET_PROCESSES = SequoiaTranslator

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LatestTranslate

$(TWEAK_NAME)_FILES = Tweak.x
$(TWEAK_NAME)_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
