Pod::Spec.new do |s|
  s.name             = 'mobile_push'
  s.version          = '1.1.0'
  s.summary          = 'SallaPush Flutter SDK: push notifications for the Flutter apps of Salla stores.'
  s.description      = 'The Flutter plugin of SallaPush for the mobile apps of Salla stores, built on the SallaPush iOS SDK.'
  s.homepage         = 'https://github.com/SallaApp/mobile-push-sdk/tree/master/flutter'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = 'Salla'
  s.source           = { :path => '.' }
  s.source_files     = 'mobile_push/Sources/mobile_push/**/*.swift'
  s.resource_bundles = { 'mobile_push_privacy' => ['mobile_push/Sources/mobile_push/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'
  # A git-only pod: the app's Podfile declares SallaPushCore and SallaPush with :git and :tag.
  s.dependency 'SallaPush', '1.0.4'
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'

  # Flutter.framework has no i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
