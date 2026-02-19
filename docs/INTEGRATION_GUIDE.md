# LimeLink iOS SDK - Integration Guide

iOS 앱 프로젝트에 LimeLink SDK를 연동하는 전체 과정을 안내합니다.

## 목차

- [요구사항](#요구사항)
- [Step 1: SDK 설치](#step-1-sdk-설치)
- [Step 2: SDK 초기화](#step-2-sdk-초기화)
- [Step 3: Universal Link 설정](#step-3-universal-link-설정)
- [Step 4: Listener 구현](#step-4-listener-구현)
- [Step 5: Deferred Deep Link 설정](#step-5-deferred-deep-link-설정)
- [Step 6: Stats 추적 연동](#step-6-stats-추적-연동)
- [Objective-C 프로젝트 연동](#objective-c-프로젝트-연동)
- [고급 설정](#고급-설정)
- [트러블슈팅](#트러블슈팅)

---

## 요구사항

| 항목 | 최소 버전 |
|------|----------|
| iOS Deployment Target | 12.0 |
| Swift | 5.0 |
| Xcode | 14.0+ |
| CocoaPods | 1.11.0+ (CocoaPods 사용 시) |
| Swift Package Manager | Xcode 14.0+ (SPM 사용 시) |

**사전 준비:**
- [limelink.org](https://limelink.org) 콘솔에서 앱을 등록하고 API Key를 발급받으세요.
- Apple Developer 계정에서 Associated Domains 권한을 활성화하세요.

---

## Step 1: SDK 설치

### Swift Package Manager (권장)

1. Xcode에서 **File > Add Package Dependencies...** 선택
2. 패키지 URL 입력:
   ```
   https://github.com/hellovelope/limelink-ios-sdk.git
   ```
3. **Version Rules**에서 `Up to Next Major Version`을 선택하고 `0.2.0` 입력
4. **Add Package** 클릭

또는 `Package.swift`에서 직접 추가:

```swift
dependencies: [
    .package(url: "https://github.com/hellovelope/limelink-ios-sdk.git", from: "0.2.0")
]
```

타겟에 의존성을 추가합니다:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "LimelinkIOSSDK", package: "limelink-ios-sdk")
    ]
)
```

> **참고**: SPM 패키지는 Swift 타겟(`LimelinkIOSSDK`)과 ObjC Bridge 타겟(`LimelinkIOSSDKObjC`) 2개로 구성됩니다. `LimelinkIOSSDK` 라이브러리를 추가하면 두 타겟 모두 포함됩니다.

### CocoaPods

`Podfile`에 아래 내용을 추가합니다:

```ruby
platform :ios, '12.0'
use_frameworks!

target 'YourApp' do
  pod 'LimelinkIOSSDK'
end
```

설치를 실행합니다:

```bash
pod install
```

이후 `.xcworkspace` 파일을 열어 작업합니다.

### 수동 설치

1. 저장소에서 `LimelinkIOSSDK/Classes/` 디렉토리를 프로젝트에 복사합니다.
2. Xcode에서 해당 파일들을 타겟에 추가합니다.
3. Build Settings에서 `DEFINES_MODULE = YES`를 설정합니다.

---

## Step 2: SDK 초기화

`AppDelegate.swift`에서 앱 실행 시 SDK를 초기화합니다.

```swift
import UIKit
import LimelinkIOSSDK

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // LimeLink SDK 초기화
        let config = LimeLinkConfig(
            apiKey: "YOUR_API_KEY",
            loggingEnabled: false,            // 릴리즈 빌드에서는 false 권장
            deferredDeeplinkEnabled: true
        )
        LimeLinkSDK.initialize(config: config)

        return true
    }
}
```

> **중요**: `initialize(config:)`는 앱 실행 시 **한 번만** 호출해야 합니다. 중복 호출 시 무시됩니다.

### SceneDelegate 사용 시 (iOS 13+)

UISceneDelegate를 사용하는 프로젝트에서는 `SceneDelegate.swift`에서 Universal Link를 처리합니다:

```swift
import LimelinkIOSSDK

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        // Cold launch 시 Universal Link 처리
        if let userActivity = connectionOptions.userActivities.first,
           userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            LimeLinkSDK.shared.handleUniversalLink(url)
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        // Warm launch 시 Universal Link 처리
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            LimeLinkSDK.shared.handleUniversalLink(url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // 커스텀 URL 스킴 처리
        if let url = URLContexts.first?.url {
            LimeLinkSDK.shared.handleUniversalLink(url)
        }
    }
}
```

---

## Step 3: Universal Link 설정

### 3-1. Xcode 프로젝트 설정

1. Xcode에서 프로젝트 타겟 > **Signing & Capabilities** 탭
2. **+ Capability** > **Associated Domains** 추가
3. 아래 도메인을 등록합니다:

```
applinks:limelink.org
applinks:*.limelink.org
```

자체 도메인을 사용하는 경우:

```
applinks:yourdomain.com
```

### 3-2. Info.plist URL Scheme 등록

커스텀 URL 스킴을 등록합니다:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.yourapp.deeplink</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>yourapp</string>
        </array>
    </dict>
</array>
```

### 3-3. AppDelegate에서 URL 수신 처리

```swift
// MARK: - Universal Link 처리

func application(_ application: UIApplication,
                 continue userActivity: NSUserActivity,
                 restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
        LimeLinkSDK.shared.handleUniversalLink(url)
        return true
    }
    return false
}

// MARK: - 커스텀 URL 스킴 처리

func application(_ app: UIApplication,
                 open url: URL,
                 options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    LimeLinkSDK.shared.handleUniversalLink(url)
    return true
}
```

### 3-4. Apple App Site Association (서버 측)

limelink.org 서비스를 사용하면 AASA 파일이 자동 관리됩니다.
자체 도메인을 사용하는 경우, 웹서버에 아래 파일을 배치합니다:

```
https://yourdomain.com/.well-known/apple-app-site-association
```

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["TEAM_ID.com.yourapp.bundleid"],
        "components": [
          { "/": "/link/*" },
          { "/": "/universal-link/*" },
          { "/": "/api/v1/app/dynamic_link/*" }
        ]
      }
    ]
  }
}
```

---

## Step 4: Listener 구현

딥링크 결과를 수신할 Listener를 구현합니다.

### 방법 A: ViewController에서 직접 구현

```swift
import UIKit
import LimelinkIOSSDK

class MainViewController: UIViewController, LimeLinkListener {

    override func viewDidLoad() {
        super.viewDidLoad()
        LimeLinkSDK.shared.addLinkListener(self)
    }

    // MARK: - LimeLinkListener (필수)

    func onDeeplinkReceived(result: LimeLinkResult) {
        guard let uri = result.resolvedUri else { return }

        if result.isDeferred {
            // Deferred Deep Link: 설치 후 첫 실행 시 수신
            print("Deferred deep link: \(uri)")
        } else {
            // Universal Link: 앱 실행 중 수신
            print("Universal link resolved: \(uri)")
        }

        // URI 기반 화면 라우팅
        navigateToContent(uri: uri)
    }

    // MARK: - LimeLinkListener (선택)

    func onDeeplinkError(error: LimeLinkError) {
        switch error.code {
        case -1:
            print("SDK가 초기화되지 않았습니다.")
        case 404:
            print("링크를 해석할 수 없습니다: \(error.message)")
        default:
            print("딥링크 에러 [\(error.code)]: \(error.message)")
        }
    }

    // MARK: - 화면 라우팅

    private func navigateToContent(uri: String) {
        guard let url = URL(string: uri) else { return }
        let pathComponents = url.pathComponents

        // 예: myapp://product/123 → ProductViewController로 이동
        if pathComponents.contains("product"), let id = pathComponents.last {
            let vc = ProductViewController(productId: id)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
```

### 방법 B: 전용 딥링크 매니저

앱 전역에서 딥링크를 관리하려면 전용 클래스를 만듭니다:

```swift
import LimelinkIOSSDK

class DeepLinkManager: NSObject, LimeLinkListener {
    static let shared = DeepLinkManager()

    private override init() {
        super.init()
        LimeLinkSDK.shared.addLinkListener(self)
    }

    func onDeeplinkReceived(result: LimeLinkResult) {
        guard let uri = result.resolvedUri else { return }

        // NotificationCenter로 전파하거나 직접 라우팅
        NotificationCenter.default.post(
            name: .didReceiveDeepLink,
            object: nil,
            userInfo: ["uri": uri, "isDeferred": result.isDeferred]
        )
    }

    func onDeeplinkError(error: LimeLinkError) {
        print("[DeepLinkManager] Error: \(error.message)")
    }
}

extension Notification.Name {
    static let didReceiveDeepLink = Notification.Name("didReceiveDeepLink")
}
```

`AppDelegate`에서 매니저를 초기화합니다:

```swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // SDK 초기화
    LimeLinkSDK.initialize(config: config)

    // 딥링크 매니저 활성화
    _ = DeepLinkManager.shared

    return true
}
```

> **참고**: Listener는 `NSHashTable.weakObjects()`로 관리되므로 Listener 객체가 해제되면 자동으로 제거됩니다. 전역 매니저 패턴에서는 `static let shared`로 유지해야 합니다.

---

## Step 5: Deferred Deep Link 설정

### 자동 모드 (권장)

`deferredDeeplinkEnabled: true`(기본값)이면 SDK 초기화 시 **첫 실행 여부를 자동 판별**하고, 첫 실행일 때만 Deferred Deep Link를 확인합니다.

결과는 등록된 Listener의 `onDeeplinkReceived(result:)`로 전달됩니다. `result.isDeferred`가 `true`입니다.

### 수동 모드

자동 모드를 끄고 직접 제어하려면:

```swift
let config = LimeLinkConfig(
    apiKey: "YOUR_API_KEY",
    deferredDeeplinkEnabled: false  // 자동 확인 비활성화
)
LimeLinkSDK.initialize(config: config)
```

원하는 시점에 수동 호출:

```swift
LimeLinkSDK.shared.handleDeferredDeepLink { result, error in
    if let result = result {
        // result.isDeferred == true
        // result.resolvedUri 에 딥링크 URI
        // result.originalUrl 에 원본 링크 URL (full_request_url)
        // result.queryParams 에 원본 URL의 쿼리 파라미터
        print("URI: \(result.resolvedUri ?? "")")
        print("Original URL: \(result.originalUrl ?? "")")
        print("Query Params: \(result.queryParams)")  // 예: ["utm_source": "google", "product_id": "789"]
    }
    if let error = error {
        // 매칭 실패 또는 네트워크 에러
    }
}
```

---

## Step 6: Stats 추적 연동

### 자동 추적

`handleUniversalLink(_:)`를 통해 딥링크가 해석되면, SDK가 자동으로 stats 이벤트를 전송합니다.

### 수동 추적

별도 화면에서 추가 추적이 필요한 경우:

```swift
// 딥링크 URI로 Stats 전송
if let url = URL(string: resolvedUri) {
    LimeLinkSDK.shared.trackLinkStatus(url: url)
}
```

---

## Objective-C 프로젝트 연동

### 브릿지 헤더 import

```objc
// Swift 모듈 import
#import <LimelinkIOSSDK/LimelinkIOSSDK-Swift.h>
// 또는 ObjC 브릿지 클래스 사용
#import <LimelinkIOSSDK/UniversalLinkHandlerBridge.h>
```

### SDK 초기화

```objc
LimeLinkConfig *config = [[LimeLinkConfig alloc] initWithApiKey:@"YOUR_API_KEY"
                                                        baseUrl:@"https://limelink.org/"
                                                 loggingEnabled:YES
                                        deferredDeeplinkEnabled:YES];
[LimeLinkSDK initialize:config];
```

### Universal Link 처리

```objc
// 방법 1: SDK를 통한 처리 (권장)
- (BOOL)application:(UIApplication *)application
    continueUserActivity:(NSUserActivity *)userActivity
      restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *))restorationHandler {

    if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        NSURL *url = userActivity.webpageURL;
        if (url) {
            [[LimeLinkSDK shared] handleUniversalLink:url];
            return YES;
        }
    }
    return NO;
}

// 방법 2: ObjC 브릿지 사용
- (BOOL)application:(UIApplication *)application
    continueUserActivity:(NSUserActivity *)userActivity
      restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *))restorationHandler {

    if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        NSURL *url = userActivity.webpageURL;
        if (url) {
            [UniversalLinkHandlerBridge handleUniversalLink:url
                completion:^(NSString * _Nullable uri) {
                    if (uri) {
                        NSLog(@"Resolved URI: %@", uri);
                    }
                }];
            return YES;
        }
    }
    return NO;
}
```

### Listener 구현

```objc
// YourViewController.h
@import LimelinkIOSSDK;

@interface YourViewController : UIViewController <LimeLinkListener>
@end

// YourViewController.m
@implementation YourViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[LimeLinkSDK shared] addLinkListener:self];
}

- (void)onDeeplinkReceivedWithResult:(LimeLinkResult *)result {
    NSLog(@"URI: %@", result.resolvedUri);
    NSLog(@"Is Deferred: %d", result.isDeferred);
}

- (void)onDeeplinkErrorWithError:(LimeLinkError *)error {
    NSLog(@"Error [%ld]: %@", (long)error.code, error.message);
}

@end
```

---

## 고급 설정

### 자체 서버 연동

자체 LimeLink 서버를 운영하는 경우 `baseUrl`을 변경합니다:

```swift
let config = LimeLinkConfig(
    apiKey: "YOUR_API_KEY",
    baseUrl: "https://api.yourcompany.com/"  // 자체 서버 URL
)
```

> `baseUrl`은 자동으로 trailing slash가 추가됩니다. `"https://api.yourcompany.com"`과 `"https://api.yourcompany.com/"`은 동일하게 처리됩니다.

### 다중 Listener 등록

여러 화면에서 동시에 딥링크를 수신할 수 있습니다:

```swift
// 각 ViewController에서 개별 등록
LimeLinkSDK.shared.addLinkListener(homeVC)
LimeLinkSDK.shared.addLinkListener(profileVC)
LimeLinkSDK.shared.addLinkListener(deepLinkManager)

// 딥링크 수신 시 모든 Listener에 동시 통지됨
```

### URL 파라미터 파싱

SDK는 URL에서 쿼리 파라미터와 경로 파라미터를 자동으로 파싱합니다:

```swift
func onDeeplinkReceived(result: LimeLinkResult) {
    // 쿼리 파라미터: ?campaign=summer&source=email
    let campaign = result.queryParams["campaign"]  // "summer"
    let source = result.queryParams["source"]      // "email"

    // 경로 파라미터: /product/detail
    let mainPath = result.pathParams.mainPath  // "product"
    let subPath = result.pathParams.subPath    // "detail"
}
```

---

## 트러블슈팅

### "SDK not initialized" 에러

```
LimeLinkError(code: -1, message: SDK not initialized)
```

**원인**: `handleUniversalLink(_:)` 호출 전에 `LimeLinkSDK.initialize(config:)`가 호출되지 않았습니다.

**해결**: `AppDelegate`의 `didFinishLaunchingWithOptions`에서 초기화가 Universal Link 처리보다 먼저 실행되는지 확인하세요.

### Universal Link가 앱으로 전달되지 않음

1. **Associated Domains 확인**: Xcode > Signing & Capabilities에서 `applinks:` 도메인이 정확히 등록되었는지 확인
2. **AASA 파일 확인**: `https://yourdomain.com/.well-known/apple-app-site-association`이 올바르게 제공되는지 확인
3. **설치 방식**: 시뮬레이터에서는 앱을 **재설치**해야 Associated Domains가 갱신됩니다
4. **직접 입력 불가**: Safari 주소창에 URL을 직접 입력하면 Universal Link가 동작하지 않습니다. 다른 앱(메모, 메시지 등)에서 링크를 탭해야 합니다.

### Deferred Deep Link가 동작하지 않음

1. **첫 실행 판별**: `LinkStats.isFirstLaunch()`는 `UserDefaults`를 사용합니다. 앱을 삭제 후 재설치하면 리셋됩니다.
2. **서버 매칭**: 디바이스 화면 크기와 OS 버전으로 매칭하므로, 같은 기기에서 웹 클릭 → 앱 설치 → 실행 순서를 지켜야 합니다.
3. **타이밍**: 웹에서 링크 클릭 후 서버에 핑거프린트가 저장되기까지 약간의 지연이 있을 수 있습니다.

### CocoaPods 빌드 에러

```
Module 'LimelinkIOSSDK' not found
```

**해결**:
```bash
cd Example  # 또는 프로젝트 루트
pod deintegrate
pod install
```

그래도 해결되지 않으면 Derived Data를 삭제합니다:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```

### Objective-C 프로젝트에서 Swift 헤더를 찾지 못함

```
'LimelinkIOSSDK-Swift.h' file not found
```

**해결**: Build Settings에서 아래 설정을 확인합니다:
- `DEFINES_MODULE` = `YES`
- `SWIFT_OBJC_INTERFACE_HEADER_NAME` = `LimelinkIOSSDK-Swift.h`
- `CLANG_ENABLE_MODULES` = `YES`
