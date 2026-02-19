# LimeLink iOS SDK - Example App Guide

Example 프로젝트를 통해 LimeLink iOS SDK의 주요 기능을 빠르게 체험할 수 있습니다.

## 목차

- [환경 요구사항](#환경-요구사항)
- [Example 프로젝트 실행](#example-프로젝트-실행)
- [프로젝트 구조](#프로젝트-구조)
- [주요 기능 체험](#주요-기능-체험)
  - [1. SDK 초기화](#1-sdk-초기화)
  - [2. Universal Link 처리](#2-universal-link-처리)
  - [3. Deferred Deep Link](#3-deferred-deep-link)
  - [4. Stats 추적](#4-stats-추적)
  - [5. Listener 패턴](#5-listener-패턴)
- [테스트 실행](#테스트-실행)
- [디버깅 팁](#디버깅-팁)

---

## 환경 요구사항

| 항목 | 최소 버전 |
|------|----------|
| Xcode | 14.0+ |
| iOS | 12.0+ |
| Swift | 5.0 |
| CocoaPods | 1.11.0+ |
| macOS | 12.0+ (Monterey) |

## Example 프로젝트 실행

```bash
# 1. 저장소 클론
git clone https://github.com/hellovelope/limelink-ios-sdk.git
cd limelink-ios-sdk

# 2. 의존성 설치
cd Example
pod install

# 3. Xcode에서 워크스페이스 열기
open LimelinkIOSSDK.xcworkspace
```

> **주의**: `.xcodeproj`가 아닌 `.xcworkspace`를 열어야 합니다. CocoaPods로 의존성이 관리되므로 워크스페이스를 사용해야 SDK 모듈이 정상적으로 연결됩니다.

## 프로젝트 구조

```
Example/
├── LimelinkIOSSDK.xcworkspace     # Xcode 워크스페이스 (이것을 열기)
├── LimelinkIOSSDK.xcodeproj       # Example 앱 프로젝트
├── LimelinkIOSSDK/
│   ├── AppDelegate.swift          # Universal Link 수신 진입점
│   ├── ViewController.swift       # SDK 기능 사용 예시
│   └── Info.plist
├── Tests/
│   ├── Tests.swift                # 스모크 테스트
│   ├── Helpers/                   # 테스트 인프라
│   │   ├── MockURLProtocol.swift
│   │   ├── MockLimeLinkListener.swift
│   │   ├── TestConstants.swift
│   │   └── XCTestCase+LimeLink.swift
│   ├── Unit/                      # 단위 테스트 (99개)
│   └── Integration/               # 통합 테스트 (15개)
└── Podfile
```

## 주요 기능 체험

### 1. SDK 초기화

SDK를 사용하기 전 반드시 `initialize(config:)`를 호출해야 합니다. `AppDelegate`의 `application(_:didFinishLaunchingWithOptions:)`에서 초기화하는 것을 권장합니다.

```swift
import LimelinkIOSSDK

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    let config = LimeLinkConfig(
        apiKey: "YOUR_API_KEY",              // limelink.org 콘솔에서 발급
        baseUrl: "https://limelink.org/",    // 기본값, 변경 불필요
        loggingEnabled: true,                // 디버그 로그 활성화
        deferredDeeplinkEnabled: true        // 첫 실행 시 Deferred Deep Link 자동 확인
    )
    LimeLinkSDK.initialize(config: config)

    return true
}
```

**`LimeLinkConfig` 파라미터 설명:**

| 파라미터 | 타입 | 기본값 | 설명 |
|---------|------|-------|------|
| `apiKey` | `String` | (필수) | limelink.org 콘솔에서 발급받은 API 키 |
| `baseUrl` | `String` | `"https://limelink.org/"` | API 서버 URL (자체 서버 운영 시 변경) |
| `loggingEnabled` | `Bool` | `false` | 콘솔 디버그 로그 출력 여부 |
| `deferredDeeplinkEnabled` | `Bool` | `true` | 첫 실행 시 Deferred Deep Link 자동 확인 |

### 2. Universal Link 처리

Universal Link가 앱으로 전달되면 `AppDelegate`에서 수신하여 SDK에 전달합니다.

```swift
// AppDelegate.swift

// iOS Universal Link 처리
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

// 커스텀 URL 스킴 처리 (iOS 9+)
func application(_ app: UIApplication,
                 open url: URL,
                 options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    LimeLinkSDK.shared.handleUniversalLink(url)
    return true
}
```

**SDK가 처리하는 URL 패턴:**

| 패턴 | URL 예시 | 설명 |
|------|---------|------|
| 서브도메인 | `https://abc.limelink.org/link/campaign123` | 권장. 헤더 정보 수집 후 API 호출 |
| 직접 접근 | `https://limelink.org/api/v1/app/dynamic_link/suffix` | 직접 API 엔드포인트 접근 |
| Universal Link | `https://limelink.org/universal-link/app/dynamic_link/suffix` | Universal Link 경로 |
| 레거시 | `https://custom.example.com/path` | 기존 딥링크 호환 |

### 3. Deferred Deep Link

앱 설치 전 클릭한 링크를 설치 후 첫 실행 시 자동으로 가져옵니다.

**자동 모드** (기본값): `deferredDeeplinkEnabled: true`로 설정하면 SDK 초기화 시 자동 확인합니다.

**수동 모드**: 직접 호출하려면 아래와 같이 사용합니다.

```swift
// 수동 Deferred Deep Link 확인
LimeLinkSDK.shared.handleDeferredDeepLink { result, error in
    if let result = result {
        print("Deferred URI: \(result.resolvedUri ?? "nil")")
        print("Deferred 여부: \(result.isDeferred)")  // true
        // 해당 URI로 화면 이동
    }
    if let error = error {
        print("에러: \(error.message)")
    }
}
```

**디바이스 핑거프린팅 수집 정보:**
- 화면 너비/높이 (points)
- User Agent (예: `"iOS 18_7"`)

### 4. Stats 추적

링크를 통한 앱 실행 이벤트를 서버에 기록합니다.

```swift
// 통계 전송 (URL의 path에서 suffix를 추출하여 전송)
let url = URL(string: "https://example.com/campaign/product/detail")
LimeLinkSDK.shared.trackLinkStatus(url: url)
```

SDK는 내부적으로 첫 실행(`first_run`) / 재실행(`rerun`)을 자동 판별합니다.

### 5. Listener 패턴

Listener를 등록하면 딥링크 결과와 에러를 콜백으로 받을 수 있습니다.

```swift
import LimelinkIOSSDK

class ViewController: UIViewController, LimeLinkListener {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Listener 등록 (weak reference로 관리됨)
        LimeLinkSDK.shared.addLinkListener(self)
    }

    // 딥링크 수신 콜백 (필수)
    func onDeeplinkReceived(result: LimeLinkResult) {
        print("Original URL: \(result.originalUrl ?? "nil")")
        print("Resolved URI: \(result.resolvedUri ?? "nil")")
        print("Query Params: \(result.queryParams)")
        print("Main Path: \(result.pathParams.mainPath)")
        print("Sub Path: \(result.pathParams.subPath ?? "nil")")
        print("Is Deferred: \(result.isDeferred)")

        // URI를 파싱하여 화면 이동
        if let uri = result.resolvedUri, let url = URL(string: uri) {
            navigateToScreen(url: url)
        }
    }

    // 에러 콜백 (선택)
    func onDeeplinkError(error: LimeLinkError) {
        print("Error Code: \(error.code)")
        print("Error Message: \(error.message)")
    }

    deinit {
        // weak reference이므로 명시적 해제는 선택사항
        LimeLinkSDK.shared.removeLinkListener(self)
    }
}
```

**`LimeLinkResult` 프로퍼티:**

| 프로퍼티 | 타입 | 설명 |
|---------|------|------|
| `originalUrl` | `String?` | 원본 Universal Link URL |
| `resolvedUri` | `String?` | 서버에서 반환한 앱 딥링크 URI |
| `queryParams` | `[String: String]` | URL 쿼리 파라미터 |
| `pathParams` | `PathParamResponse` | URL 경로 파라미터 (`mainPath`, `subPath`) |
| `isDeferred` | `Bool` | Deferred Deep Link 여부 |

**`LimeLinkError` 프로퍼티:**

| 프로퍼티 | 타입 | 설명 |
|---------|------|------|
| `code` | `Int` | 에러 코드 (`-1`: 미초기화, `404`: 링크 해석 실패 등) |
| `message` | `String` | 에러 메시지 |
| `underlyingError` | `Error?` | 원본 에러 (네트워크 에러 등) |

## 테스트 실행

### Xcode에서 실행

1. `LimelinkIOSSDK.xcworkspace` 열기
2. Scheme을 `LimelinkIOSSDK-Example`로 선택
3. `Cmd + U` 또는 Product > Test

### 커맨드라인에서 실행

```bash
xcodebuild test \
  -workspace Example/LimelinkIOSSDK.xcworkspace \
  -scheme LimelinkIOSSDK-Example \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' \
  -only-testing:LimelinkIOSSDK_Tests \
  | xcpretty
```

### 테스트 구성 (115개)

| 카테고리 | 테스트 수 | 대상 |
|---------|---------|------|
| 모델 Unit | 35 | Config, Error, Result, EventType, PathParam, Request, UrlHandler |
| 서비스 Unit | 64 | LinkStats, UniversalLink, DeferredDeepLink, LimelinkService, SDK |
| Integration | 15 | E2E 흐름, ObjC Bridge, 다중 Listener |
| 스모크 | 1 | 기본 동작 확인 |

## 디버깅 팁

### 로그 활성화

`LimeLinkConfig`에서 `loggingEnabled: true`를 설정하면 `[LimeLinkSDK]` 접두어로 콘솔 로그가 출력됩니다.

```
[LimeLinkSDK] LimeLinkSDK initialized with baseUrl: https://limelink.org/
[LimeLinkSDK] First launch detected. Checking deferred deep link...
[LimeLinkSDK] Handling universal link: https://abc.limelink.org/link/campaign123
```

### 시뮬레이터에서 Universal Link 테스트

시뮬레이터에서 직접 Universal Link를 테스트하려면:

```bash
# 터미널에서 URL 열기
xcrun simctl openurl booted "https://abc.limelink.org/link/campaign123"
```

### 초기화 여부 확인

```swift
if LimeLinkSDK.shared.isInitialized {
    // SDK 사용 가능
} else {
    // LimeLinkSDK.initialize(config:) 호출 필요
}
```
