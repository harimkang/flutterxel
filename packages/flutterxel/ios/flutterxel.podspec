#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutterxel.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutterxel'
  s.version          = '0.0.1'
  s.summary          = 'Flutter runtime plugin for a Pyxel-compatible engine.'
  s.description      = <<-DESC
Flutter runtime plugin for a Pyxel-compatible engine backed by Rust FFI.
                       DESC
  s.homepage         = 'https://github.com/harimkang/flutterxel'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'flutterxel contributors' => 'opensource@flutterxel.dev' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  core_xcframework = File.join(__dir__, '../native/ios/FlutterxelCore.xcframework')
  if File.exist?(core_xcframework)
    s.vendored_frameworks = '../native/ios/FlutterxelCore.xcframework'
  end

  core_static_lib = File.join(__dir__, '../native/ios/libflutterxel_core.a')
  if File.exist?(core_static_lib)
    s.vendored_libraries = '../native/ios/libflutterxel_core.a'
  end

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
