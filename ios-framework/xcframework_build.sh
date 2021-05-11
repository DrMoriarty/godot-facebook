#!/bin/bash

rm -rf ./build/*.xcframework
rm -rf ./build/*.xcarchive

PROJECT=${1:-godot_plugin.xcodeproj}
SCHEME=${2:-godot_plugin}

xcodebuild archive \
    -project "./$PROJECT" \
    -scheme $SCHEME \
    -archivePath "./build/ios_release.xcarchive" \
    -sdk iphoneos \
    SKIP_INSTALL=NO

xcodebuild archive \
    -project "./$PROJECT" \
    -scheme $SCHEME \
    -archivePath "./build/sim_release.xcarchive" \
    -sdk iphonesimulator \
    SKIP_INSTALL=NO

xcodebuild archive \
    -project "./$PROJECT" \
    -scheme $SCHEME \
    -archivePath "./build/ios_debug.xcarchive" \
    -sdk iphoneos \
    SKIP_INSTALL=NO \
    GCC_PREPROCESSOR_DEFINITIONS="DEBUG_ENABLED=1"

xcodebuild archive \
    -project "./$PROJECT" \
    -scheme $SCHEME \
    -archivePath "./build/sim_debug.xcarchive" \
    -sdk iphonesimulator \
    SKIP_INSTALL=NO \
    GCC_PREPROCESSOR_DEFINITIONS="DEBUG_ENABLED=1"

FRAMEWORK=facebook

mv "./build/ios_release.xcarchive/Products/usr/local/lib/libgodot_plugin.a" "./build/ios_release.xcarchive/Products/usr/local/lib/${FRAMEWORK}.a"
mv "./build/sim_release.xcarchive/Products/usr/local/lib/libgodot_plugin.a" "./build/sim_release.xcarchive/Products/usr/local/lib/${FRAMEWORK}.a"
mv "./build/ios_debug.xcarchive/Products/usr/local/lib/libgodot_plugin.a" "./build/ios_debug.xcarchive/Products/usr/local/lib/${FRAMEWORK}.a"
mv "./build/sim_debug.xcarchive/Products/usr/local/lib/libgodot_plugin.a" "./build/sim_debug.xcarchive/Products/usr/local/lib/${FRAMEWORK}.a"

xcodebuild -create-xcframework \
    -library "./build/ios_release.xcarchive/Products/usr/local/lib/${FRAMEWORK}.a" \
    -library "./build/sim_release.xcarchive/Products/usr/local/lib/${FRAMEWORK}.a" \
    -output "./build/${FRAMEWORK}.release.xcframework"

xcodebuild -create-xcframework \
    -library "./build/ios_debug.xcarchive/Products/usr/local/lib/${FRAMEWORK}.a" \
    -library "./build/sim_debug.xcarchive/Products/usr/local/lib/${FRAMEWORK}.a" \
    -output "./build/${FRAMEWORK}.debug.xcframework"
