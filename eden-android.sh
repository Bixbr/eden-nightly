#!/bin/bash -ex

export NDK_CCACHE=$(which sccache)

cd ./eden

# workaround for prebuilt ffmpeg download failure
# use prebuilt ffmpeg from https://git.eden-emu.dev/eden-emu/ext-android-bin
# content unchanged
sed -i 's|set(package_base_url "https://git.eden-emu.dev/eden-emu/")|set(package_base_url "https://github.com/pflyly/eden-nightly/")|' CMakeModules/DownloadExternals.cmake
sed -i 's|set(package_repo "ext-android-bin/raw/master/")|set(package_repo "raw/refs/heads/main/")|' CMakeModules/DownloadExternals.cmake

# don't build tests and build real release type
sed -i '/"-DYUZU_ENABLE_LTO=ON"/a\
                    "-DCMAKE_BUILD_TYPE=Release",\
                    "-DCMAKE_C_COMPILER_LAUNCHER=sccache",\
                    "-DCMAKE_CXX_COMPILER_LAUNCHER=sccache",\
                    "-DYUZU_TESTS=OFF",
' src/android/app/build.gradle.kts

if [ "$TARGET" = "Coexist" ]; then
    # Change the App name and application ID to make it coexist with official build
    sed -i 's/applicationId = "dev\.eden\.eden_emulator"/applicationId = "dev.eden.eden_emulator.nightly"/' src/android/app/build.gradle.kts
    sed -i 's/resValue("string", "app_name_suffixed", "Eden")/resValue("string", "app_name_suffixed", "Eden Unofficial")/' src/android/app/build.gradle.kts
    sed -i 's|<string name="app_name"[^>]*>.*</string>|<string name="app_name" translatable="false">Eden Unofficial</string>|' src/android/app/src/main/res/values/strings.xml
fi        

if [ "$TARGET" = "Optimised" ]; then
    # Add optimised to the app name
    sed -i 's/resValue("string", "app_name_suffixed", "Eden")/resValue("string", "app_name_suffixed", "Eden Optimised")/' src/android/app/build.gradle.kts
fi 

COUNT="$(git rev-list --count HEAD)"
APK_NAME="Eden-${COUNT}-Android-Unofficial-${TARGET}"

cd src/android
chmod +x ./gradlew
if [ "$TARGET" = "Optimised" ]; then
	./gradlew assembleGenshinSpoofRelease --build-cache --parallel --console=plain --info
else
	./gradlew assembleMainlineRelease --build-cache --parallel --console=plain --info
fi

sccache -s

APK_PATH=$(find app/build/outputs/apk -type f -name "*.apk" | head -n 1)
if [ -z "$APK_PATH" ]; then
    echo "Error: APK not found in expected directory."
    exit 1
fi
mkdir -p artifacts
mv "$APK_PATH" "artifacts/$APK_NAME.apk"
