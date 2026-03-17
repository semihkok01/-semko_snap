workflows:
  ios-release:
    name: iOS Release
    instance_type: mac_mini_m2
    environment:
      flutter: stable
      xcode: latest
      cocoapods: default
    scripts:
      - name: Flutter dependencies
        script: flutter pub get
      - name: Build unsigned iOS app
        script: flutter build ios --release --no-codesign
      - name: Package IPA for Sideloadly
        script: |
          APP_DIR=$(find "$CM_BUILD_DIR/build/ios/iphoneos" -maxdepth 1 -type d -name "*.app" | head -n 1)
          if [ -z "$APP_DIR" ]; then
            echo ".app bundle not found in build/ios/iphoneos"
            exit 1
          fi

          rm -rf "$CM_BUILD_DIR/build/ios/iphoneos/Payload"
          rm -f "$CM_BUILD_DIR/build/ios/iphoneos/SemkoScan.ipa"
          mkdir -p "$CM_BUILD_DIR/build/ios/iphoneos/Payload"
          cp -R "$APP_DIR" "$CM_BUILD_DIR/build/ios/iphoneos/Payload/"

          cd "$CM_BUILD_DIR/build/ios/iphoneos"
          zip -qry SemkoScan.ipa Payload
    artifacts:
      - build/ios/iphoneos/*.ipa
