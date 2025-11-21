#
# Be sure to run `pod lib lint LimelinkIOSSDK.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'LimelinkIOSSDK'
  s.version          = '0.1.46'
  s.summary          = 'Limelink iOS SDK for analytics, deep linking, universal links, and deferred deep links.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Limelink iOS SDK provides comprehensive deep linking and analytics services for iOS applications. 
Features include:
- Statistical tracking for first run and relaunch events
- Deep linking with path parameter handling
- Universal Link support with subdomain and direct access methods
- Deferred Deep Link support with device fingerprinting for automatic user matching
- Seamless post-installation deep link retrieval
                       DESC

  s.homepage         = 'https://limelink.org'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'hellovelope' => 'hellovelope@gmail.com' }
  s.source           = { :git => 'https://github.com/hellovelope/limelink-ios-sdk.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '12.0'

  s.source_files = 'LimelinkIOSSDK/**/*'
  s.swift_version = '5.0'
  
  # Swift 헤더 생성을 위한 설정
  s.pod_target_xcconfig = {
    'SWIFT_OBJC_INTERFACE_HEADER_NAME' => 'LimelinkIOSSDK-Swift.h',
    'DEFINES_MODULE' => 'YES',
    'SWIFT_INSTALL_OBJC_HEADER' => 'YES',
    'CLANG_ENABLE_MODULES' => 'YES'
  }
  
  # Objective-C와 Swift 간의 호환성을 위한 설정
  s.user_target_xcconfig = {
    'SWIFT_OBJC_INTERFACE_HEADER_NAME' => 'LimelinkIOSSDK-Swift.h',
    'DEFINES_MODULE' => 'YES'
  }
  
  # s.resource_bundles = {
  #   'LimelinkIOSSDK' => ['LimelinkIOSSDK/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
