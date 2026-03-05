#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutterxel.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutterxel'
  s.version          = '0.0.9'
  s.summary          = 'Flutter runtime plugin for a Pyxel-compatible engine.'
  s.description      = <<-DESC
Flutter runtime plugin for a Pyxel-compatible engine backed by Rust FFI.
                       DESC
  s.homepage         = 'https://github.com/harimkang/flutterxel'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'flutterxel contributors' => 'opensource@flutterxel.dev' }

  # Keep the C source list non-empty for plugin compilation, but iOS symbols
  # must come from the vendored Rust core xcframework, not C fallback exports.
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  core_xcframework = File.join(__dir__, 'Frameworks/FlutterxelCore.xcframework')
  pod_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }

  if File.exist?(core_xcframework)
    s.vendored_frameworks = 'Frameworks/FlutterxelCore.xcframework'
    pod_xcconfig['OTHER_LDFLAGS[sdk=iphoneos*]'] =
      '$(inherited) -force_load "${PODS_TARGET_SRCROOT}/Frameworks/FlutterxelCore.xcframework/ios-arm64/libflutterxel_core.a"'
    pod_xcconfig['OTHER_LDFLAGS[sdk=iphonesimulator*]'] =
      '$(inherited) -force_load "${PODS_TARGET_SRCROOT}/Frameworks/FlutterxelCore.xcframework/ios-arm64_x86_64-simulator/libflutterxel_core.a"'
  end

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = pod_xcconfig
  s.swift_version = '5.0'
end
