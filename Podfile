# Uncomment the next line to define a global platform for your project

platform :ios, '10.0'

target 'SwiftSummary' do
    # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
    use_frameworks!
#    use_modular_headers!
    inhibit_all_warnings!
    # Pods for SwiftSummary
    pod 'Alamofire', '5.2.1'
    pod 'Kingfisher', '4.7.0'
    pod 'SSZipArchive', '2.1.4'
    pod 'SVProgressHUD', '2.2.5'
    pod 'RealmSwift', '5.3.1'
    pod 'MJRefresh', '3.1.15.7'
    pod 'Hero'
    pod 'SnapKit', '~> 4.2.0'
    pod 'CryptoSwift', '~> 1.1.3'
    pod 'CocoaLumberjack/Swift'
    pod 'IQKeyboardManagerSwift'
    pod 'Charts'
    pod 'RxSwift', '~> 5'
    pod 'RxCocoa', '~> 5'
    pod 'ReactiveCocoa', '~> 10.1'
    pod 'ReactiveSwift', '~> 6.1'
    pod 'MagazineLayout'
    pod 'Bugly’, '2.5.5'
    pod 'HandyJSON', '5.0.1'
    post_install do |installer|
        installer.pods_project.targets.each do |target|
            target.build_configurations.each do |config|
                config.build_settings['ENABLE_BITCODE'] = 'NO'
                config.build_settings['ARCHS'] = 'arm64'
            end
        end
    end
end