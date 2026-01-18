LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := voice_mfcc
LOCAL_SRC_FILES := ../voice_mfcc.cpp
LOCAL_LDLIBS := -llog -lm
LOCAL_CPPFLAGS := -std=c++11 -Wall

include $(BUILD_SHARED_LIBRARY)
