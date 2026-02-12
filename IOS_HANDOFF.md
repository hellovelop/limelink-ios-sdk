# LimeLink Android SDK - iOS 이식 핸드오프 문서

> **작성일**: 2026-02-12
> **대상**: iOS SDK 개발자
> **Android SDK 버전**: 0.0.1
> **목적**: Android에서 구현 완료된 아키텍처 및 기능을 iOS SDK에 동일하게 적용하기 위한 참조 문서

---

## 1. 전체 아키텍처 개요

```
┌─────────────────────────────────────────────────────┐
│                    LimeLinkSDK                       │
│              (Singleton / Entry Point)               │
│                                                      │
│  init(config) → lifecycle 자동 등록                   │
│  addLinkListener / removeLinkListener                │
│  handleUniversalLink (수동 호출 - 하위호환)             │
│  handleDeferredDeepLink                              │
│  getInstallReferrer                                  │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │ Lifecycle    │  │ Universal    │  │ Install    │ │
│  │ Handler      │  │ LinkHandler  │  │ Referrer   │ │
│  │              │  │              │  │ Handler    │ │
│  │ Activity     │  │ subdomain    │  │            │ │
│  │ onCreate →   │  │ pattern +    │  │ Deferred   │ │
│  │ onResume →   │  │ legacy       │  │ deeplink   │ │
│  │ auto-detect  │  │ deeplink     │  │ (첫 설치)   │ │
│  └──────┬───────┘  └──────┬───────┘  └─────┬──────┘ │
│         │                 │                │        │
│         └────────┬────────┘                │        │
│                  ▼                         │        │
│  ┌──────────────────────┐                  │        │
│  │   LimeLinkListener   │◄─────────────────┘        │
│  │   (Callback)         │                           │
│  │                      │                           │
│  │  onDeeplinkReceived  │  → LimeLinkResult         │
│  │  onDeeplinkError     │  → LimeLinkError          │
│  └──────────────────────┘                           │
│                                                      │
│  ┌──────────────────────┐  ┌──────────────────────┐ │
│  │   UrlHandler          │  │   LinkStats          │ │
│  │   URL 파싱             │  │   첫 실행 추적        │ │
│  │   query/path params   │  │   SharedPreferences  │ │
│  └──────────────────────┘  └──────────────────────┘ │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │           RetrofitClient (Network)            │   │
│  │           Base URL 설정 가능                    │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

---

## 2. SDK 초기화 (init)

### 2.1 Config 모델

```
LimeLinkConfig
├── apiKey: String          (필수, 빈 문자열 불가)
├── baseUrl: String         (기본값: "https://limelink.org/")
├── loggingEnabled: Boolean (기본값: false)
└── deferredDeeplinkEnabled: Boolean (기본값: true)
```

**Builder 패턴** 사용. iOS에서는 Swift struct + 기본값 또는 Builder 패턴으로 구현.

### 2.2 초기화 흐름

```
앱 시작 (Application.onCreate)
  │
  ▼
LimeLinkSDK.init(application, config)
  │
  ├─ 1. 중복 초기화 방지 (isInitialized 체크)
  ├─ 2. config 저장
  ├─ 3. RetrofitClient.initialize(config.baseUrl) → 네트워크 클라이언트 초기화
  ├─ 4. LifecycleHandler 등록 (ActivityLifecycleCallbacks)
  ├─ 5. isInitialized = true
  └─ 6. deferredDeeplinkEnabled == true → checkDeferredDeeplink() 자동 호출
```

**iOS 대응**:
- `Application.onCreate` → `AppDelegate.application(_:didFinishLaunchingWithOptions:)` 또는 SwiftUI `App.init`
- `ActivityLifecycleCallbacks` → iOS에는 없음. `SceneDelegate` 또는 `UIApplicationDelegate`의 lifecycle 메서드에서 수동 처리, 또는 `NotificationCenter`로 `UIScene.willConnectNotification` / `UIScene.openURLContextsNotification` 감지

---

## 3. Lifecycle 자동 감지

### 3.1 Android 구현

`LimeLinkLifecycleHandler`는 `Application.ActivityLifecycleCallbacks`를 구현하여:

| 시점 | 동작 |
|------|------|
| `onActivityCreated` | intent에 Universal Link가 있으면 `handleLinkIntent()` 호출 |
| `onActivityResumed` | intent URI가 이전과 다르면 (새로운 링크) `handleLinkIntent()` 호출 |

**중복 처리 방지**: `lastIntentUri`를 저장하여 같은 URI로 중복 호출 방지.

### 3.2 iOS 대응 방안

| Android | iOS |
|---------|-----|
| `onActivityCreated` + intent.data | `application(_:continue:restorationHandler:)` (Universal Link) |
| `onActivityResumed` + 새 intent | `scene(_:continue:)` (Scene-based) |
| `lastIntentUri` 중복 방지 | 동일하게 마지막 처리한 URL 저장하여 비교 |

iOS Universal Link 진입점:
```
// UIApplicationDelegate (legacy)
func application(_:continue userActivity:restorationHandler:) -> Bool

// UISceneDelegate (modern)
func scene(_:continue userActivity:)

// SwiftUI
.onOpenURL { url in ... }
```

---

## 4. Universal Link 처리 로직

### 4.1 URL 패턴 분기

```
입력 URL
  │
  ├─ {suffix}.limelink.org/link/{linkSuffix}?... → 서브도메인 패턴 (신규)
  │     예: abc123.limelink.org/link/my-campaign?utm_source=kakao
  │
  └─ deep.limelink.org/... → 레거시 딥링크 패턴
```

### 4.2 서브도메인 패턴 처리 (주요 로직)

```
URL: https://abc123.limelink.org/link/my-campaign?param1=value1

1. host에서 suffix 추출: "abc123" (host에서 ".limelink.org" 제거)
2. path에서 linkSuffix 추출: "my-campaign" (path에서 "/link/" prefix 제거)
3. query params 추출: {param1: "value1"}
4. full request URL 보존: 원본 URL 전체 문자열

5. API 호출:
   GET /api/v1/app/dynamic_link/{linkSuffix}
     ?full_request_url={원본URL인코딩}
     &param1=value1

6. 응답의 uri 필드 반환
```

### 4.3 레거시 딥링크 처리

```
URL: https://deep.limelink.org/some/path

1. host가 "deep.limelink.org"인지 확인
2. subdomain 추출 (host.split(".")[0] → "deep")
3. platform = "android" (iOS에서는 "ios"로 변경)

4. API 호출:
   GET /link?subdomain={subdomain}&path={path}&platform={platform}

5. 응답의 deeplinkUrl 반환
```

**iOS 주의사항**: `platform` 파라미터를 `"ios"`로 전송해야 함.

### 4.4 Universal Link 판별 기준

URL이 Universal Link인지 판별하는 조건:

```
(host가 "*.limelink.org" 패턴 AND scheme == "https")
OR
(host == "deep.limelink.org" AND scheme == "https")
```

---

## 5. API 엔드포인트 명세

**Base URL**: `https://limelink.org/`

### 5.1 Stats 이벤트 전송

```
POST /api/v1/stats/event

Body (JSON):
{
  "private_key": "{apiKey}",
  "suffix": "{path의 mainPath}",
  "handle": "{path의 subPath, nullable}",
  "event_type": "first_run" | "rerun"
}
```

- 링크 클릭 후 자동으로 호출됨
- `event_type`: 첫 실행이면 `"first_run"`, 이후 `"rerun"`

### 5.2 Universal Link 해석 (서브도메인 패턴)

```
GET /api/v1/app/dynamic_link/{linkSuffix}
    ?full_request_url={원본URL}
    &{원본 query params 그대로 전달}

Response (JSON):
{
  "uri": "https://target-app.com/some/path"
}
```

### 5.3 레거시 Deeplink 해석

```
GET /link
    ?subdomain={subdomain}
    &path={path}
    &platform=android|ios

Response (JSON):
{
  "deeplink_url": "https://target-app.com/some/path"
}
```

### 5.4 Deferred Deep Link (Install Referrer용)

```
GET /api/v1/app/dynamic_link/{suffix}
    ?full_request_url={fullRequestUrl}
    &event_type=setup

Response (JSON):
{
  "uri": "https://target-app.com/some/path"
}
```

### 5.5 레거시 엔드포인트 (Deprecated)

```
GET /universal-link/app/dynamic_link/{suffix}

→ 사용하지 않아도 됨, 하위호환 목적으로만 존재
```

---

## 6. Deferred Deep Link (지연 딥링크)

앱이 처음 설치된 후 첫 실행 시, 설치 전에 클릭했던 링크를 복원하는 기능.

### 6.1 Android 구현 흐름

```
앱 첫 실행
  │
  ▼
checkDeferredDeeplink()
  │
  ├─ isFirstLaunch 체크 (SharedPreferences 기반)
  │   └─ false → 종료
  │
  ├─ true →
  │   └─ InstallReferrerHandler.getInstallReferrer()
  │       │
  │       ├─ Google Play Install Referrer API 호출
  │       ├─ referrer 문자열에서 limelink.org URL 추출
  │       │   (정규식: https?://...limelink.org...)
  │       │
  │       ├─ URL 발견 → LimeLinkResult(isDeferred=true) 생성
  │       │   └─ notifyListeners()
  │       │
  │       └─ URL 미발견 → callback(null)
```

### 6.2 iOS 대응 방안

| Android | iOS |
|---------|-----|
| Install Referrer API | 해당 없음 (iOS에는 Install Referrer 없음) |
| SharedPreferences (첫 실행 체크) | UserDefaults |

**iOS Deferred Deep Link 대안**:
- **클립보드 기반**: 앱 설치 전 클립보드에 URL 복사 → 앱 첫 실행 시 클립보드 확인 (iOS 16+ UIPasteboard 제한 주의)
- **서버 사이드 fingerprint**: 디바이스 fingerprint(IP, UA 등)를 서버에서 매칭
- **Apple Search Ads Attribution API**: 광고를 통한 설치인 경우
- **App Clip → Full App 전환**: App Clip에서 Full App으로 데이터 전달

→ iOS 환경에 맞는 방식 선택 필요. 서버팀과 협의 권장.

---

## 7. 콜백 / 리스너 인터페이스

### 7.1 LimeLinkListener

```
interface LimeLinkListener {
    onDeeplinkReceived(result: LimeLinkResult)   // 필수
    onDeeplinkError(error: LimeLinkError)         // 선택 (기본 빈 구현)
}
```

### 7.2 LimeLinkResult

```
LimeLinkResult
├── originalUrl: String?           // 원본 URL
├── resolvedUri: URI?              // API로 해석된 최종 URI
├── queryParams: Map<String,String> // 쿼리 파라미터
├── pathParams: PathParamResponse  // 경로 파라미터
│   ├── mainPath: String           // pathSegments[1] (예: "toggle-reward")
│   └── subPath: String?           // pathSegments[2] (있을 경우)
├── isDeferred: Boolean            // Deferred Deep Link 여부 (기본 false)
└── referrerInfo: ReferrerInfo?    // Install Referrer 정보 (있을 경우)
```

### 7.3 LimeLinkError

```
LimeLinkError
├── code: Int           // 에러 코드 (-1: 일반 에러)
├── message: String     // 에러 메시지
└── exception: Error?   // 원본 에러 객체 (nullable)
```

### 7.4 ReferrerInfo

```
ReferrerInfo
├── referrerUrl: String?     // 전체 referrer 문자열
├── clickTimestamp: Long     // 클릭 시각 (epoch seconds)
├── installTimestamp: Long   // 설치 시각 (epoch seconds)
└── limeLinkUrl: String?     // referrer에서 추출한 LimeLink URL
```

---

## 8. URL 파싱 유틸리티

### 8.1 Scheme에서 original URL 추출

```
Intent URL에 "original-url" 쿼리 파라미터가 있으면 그 값 사용
없으면 intent의 data URL 자체 사용
```

iOS 대응: URL의 `queryItems`에서 `"original-url"` 키를 찾아 같은 로직 적용.

### 8.2 Query Params 파싱

```
URL의 모든 query parameter name → {name: value} 맵으로 변환
```

### 8.3 Path Params 파싱

```
URL path segments 기준:
  segments[0] = "link" (무시)
  segments[1] = mainPath
  segments[2] = subPath (optional)

예: /link/toggle-reward/detail
  → mainPath = "toggle-reward"
  → subPath = "detail"
```

---

## 9. 첫 실행 추적 (LinkStats)

```
isFirstLaunch():
  1. SharedPreferences에서 "is_first_launch" 읽기 (기본값: true)
  2. true이면 → false로 업데이트 후 true 반환
  3. false이면 → false 반환 (이미 실행된 적 있음)
```

**iOS**: `UserDefaults`로 동일하게 구현.

**주의**: 이 메서드는 호출 시점에 값을 소비(true→false로 변경)하므로, 한 번만 true를 반환함.

---

## 10. 네트워크 계층

### 10.1 구성

- HTTP 클라이언트: Android는 Retrofit2 + Gson
- iOS 대응: `URLSession` + `Codable` 또는 Alamofire
- Base URL은 Config에서 주입받아 변경 가능 (기본: `https://limelink.org/`)
- Lazy initialization: 최초 API 호출 시 클라이언트 생성

### 10.2 Response 모델

```
UniversalLinkResponse
└── uri: String    // 리다이렉트 대상 URI

DeeplinkResponse
└── deeplinkUrl: String   // 딥링크 URL (JSON key: "deeplink_url")
```

---

## 11. 공개 API 요약 (SDK 사용자 관점)

| 메서드 | 설명 | 비고 |
|--------|------|------|
| `init(app, config)` | SDK 초기화 + lifecycle 자동 등록 | 앱 시작 시 1회 호출 |
| `addLinkListener(listener)` | 딥링크 이벤트 리스너 등록 | 여러 개 등록 가능 |
| `removeLinkListener(listener)` | 리스너 제거 | |
| `handleUniversalLink(context, intent, callback?)` | 수동으로 Universal Link 처리 | 하위호환용 |
| `handleDeferredDeepLink(suffix, fullRequestUrl?, callback?)` | Deferred Deep Link 수동 처리 | |
| `getInstallReferrer(context, callback)` | Install Referrer 정보 조회 | Android 전용 |
| `isUniversalLink(intent)` | Universal Link 여부 확인 | |
| `getSchemeFromIntent(intent)` | scheme에서 original URL 추출 | |
| `parseQueryParams(intent)` | 쿼리 파라미터 파싱 | |
| `parsePathParams(intent)` | 경로 파라미터 파싱 | |
| `checkDeferredDeeplink(context, callback?)` | 첫 실행 시 deferred deeplink 확인 | init에서 자동 호출됨 |

---

## 12. iOS 구현 시 핵심 차이점 요약

| 항목 | Android | iOS 권장 |
|------|---------|----------|
| 진입점 | `Application.onCreate` | `AppDelegate` 또는 SwiftUI `App.init` |
| Lifecycle 감지 | `ActivityLifecycleCallbacks` | `SceneDelegate` / `.onOpenURL` / `NotificationCenter` |
| Universal Link 수신 | `Intent.data` (ACTION_VIEW) | `NSUserActivity.webpageURL` |
| 네트워크 | Retrofit2 + Gson | `URLSession` + `Codable` (또는 Alamofire) |
| 첫 실행 저장소 | `SharedPreferences` | `UserDefaults` |
| Install Referrer | Google Play Install Referrer API | 없음 - 대안 전략 필요 (Section 6.2 참조) |
| 비동기 처리 | Kotlin Coroutines | Swift async/await 또는 Combine |
| Singleton | `object` (Kotlin) | `static let shared` 또는 Actor |
| platform 파라미터 | `"android"` | `"ios"` |
| Config 패턴 | Builder 패턴 | Swift struct + 기본값 |

---

## 13. 패키지 구조 참조

```
org.limelink.limelink_aos_sdk/
├── LimeLinkSDK.kt              ← 메인 진입점 (Singleton)
├── LimeLinkListener.kt         ← 콜백 인터페이스
├── UniversalLinkHandler.kt     ← Universal Link 처리
├── UrlHandler.kt               ← URL 파싱 유틸리티
├── LinkStats.kt                ← 첫 실행 추적 + 통계 전송
├── InstallReferrerHandler.kt   ← Install Referrer 처리
├── config/
│   └── LimeLinkConfig.kt       ← SDK 설정
├── lifecycle/
│   └── LimeLinkLifecycleHandler.kt ← Activity lifecycle 자동 감지
├── response/
│   ├── LimeLinkResult.kt       ← 결과 모델
│   ├── LimeLinkError.kt        ← 에러 모델
│   ├── ReferrerInfo.kt         ← 리퍼러 정보 모델
│   ├── UniversalLinkResponse.kt
│   ├── DeeplinkResponse.kt
│   └── PathParamResponse.kt
├── request/
│   └── LimeLinkRequest.kt      ← 통계 요청 모델
├── enums/
│   └── EventType.kt            ← "first_run" | "rerun"
└── service/
    ├── RetrofitClient.kt       ← HTTP 클라이언트
    └── limelink/
        └── ApiService.kt       ← API 인터페이스 정의
```
