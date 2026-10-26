require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "SallaPushReactNative"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = "Salla"

  s.platforms    = { :ios => "15.0" }
  s.swift_version = "5.0"
  s.source       = { :git => "https://github.com/SallaApp/mobile-push-sdk.git", :tag => "react-native-#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift,cpp}"
  s.private_header_files = "ios/**/*.h"

  # The SallaPush pods come from git, so the app's Podfile declares their source (README).
  s.dependency "SallaPush", "1.0.4"

  install_modules_dependencies(s)
end
