# LimeLink iOS SDK - Technical Specification

**Version**: 0.2.0
**Last Updated**: 2026-02-12

## 목차

- [1. 개요](#1-개요)
- [2. 시스템 요구사항](#2-시스템-요구사항)
- [3. 아키텍처](#3-아키텍처)
- [4. 공개 API 명세](#4-공개-api-명세)
- [5. URL 패턴 및 라우팅](#5-url-패턴-및-라우팅)
- [6. 네트워크 API 명세](#6-네트워크-api-명세)
- [7. 데이터 모델](#7-데이터-모델)
- [8. 동작 흐름](#8-동작-흐름)
- [9. 에러 처리](#9-에러-처리)
- [10. 저장소 및 상태 관리](#10-저장소-및-상태-관리)
- [11. 스레딩 모델](#11-스레딩-모델)
- [12. Objective-C 호환성](#12-objective-c-호환성)
- [13. 테스트 명세](#13-테스트-명세)
- [14. 보안 고려사항](#14-보안-고려사항)
- [15. 제한사항 및 알려진 이슈](#15-제한사항-및-알려진-이슈)
- [16. 변경 이력](#16-변경-이력)

---

## 1. 개요

LimeLink iOS SDK는 iOS 앱에 딥링크, Universal Link, Deferred Deep Link, 이벤트 추적 기능을 제공하는 경량 라이브러리입니다.

### 핵심 기능

| 기능 | 설명 |
|------|------|
| **Universal Link** | 서브도메인, 직접접근, 레거시 3가지 URL 패턴 지원 |
| **Deferred Deep Link** | 디바이스 핑거프린팅 기반 설치 후 딥링크 매칭 |
| **Stats Tracking** | 첫 실행/재실행 이벤트를 서버에 기록 |
| **Listener Pattern** | 비동기 딥링크 결과를 콜백으로 전달 |
| **Objective-C Bridge** | Swift/Objective-C 양쪽에서 사용 가능 |

### 의존성

- 외부 라이브러리 의존성 **없음**
- iOS 시스템 프레임워크만 사용: `Foundation`, `UIKit`

---

## 2. 시스템 요구사항

| 항목 | 값 |
|------|-----|
| iOS Deployment Target | 12.0+ |
| Swift | 5.0 |
| Xcode | 14.0+ |
| 패키지 매니저 | CocoaPods |
| 라이선스 | MIT |

---

## 3. 아키텍처

### 모듈 구조

```
LimelinkIOSSDK/
├── Classes/
│   ├── LimeLinkSDK.swift              # 진입점 싱글톤
│   ├── LimeLinkListener.swift         # 리스너 프로토콜
│   ├── Config/
│   │   └── LimeLinkConfig.swift       # 설정 모델
│   ├── Handlers/
│   │   ├── UniversalLink.swift        # URL 라우팅 및 해석
│   │   └── UrlHandler.swift           # URL 파싱 유틸리티
│   ├── Models/
│   │   ├── Request/
│   │   │   └── LimeLinkRequest.swift  # API 요청 모델
│   │   ├── Response/
│   │   │   ├── LimeLinkResult.swift   # 딥링크 결과
│   │   │   ├── LimeLinkError.swift    # 에러 모델
│   │   │   └── PathParamResponse.swift# 경로 파라미터
│   │   └── Enums/
│   │       └── EventType.swift        # 이벤트 타입
│   ├── Services/
│   │   ├── LimelinkService.swift      # Stats 전송 / LinkStats
│   │   └── DeferredDeepLinkService.swift # Deferred Deep Link
│   └── ObjCBridge/
│       ├── UniversalLinkHandlerBridge.h
│       └── UniversalLinkHandlerBridge.m
```

### 클래스 관계도

```
                    ┌──────────────────┐
                    │   LimeLinkSDK    │ (Singleton)
                    │   (진입점)        │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
    ┌─────────▼────┐  ┌─────▼──────┐  ┌───▼────────────────┐
    │ UniversalLink │  │ LinkStats  │  │ DeferredDeepLink   │
    │ (URL 라우팅)   │  │ (첫실행)   │  │ Service            │
    └──────┬───────┘  └────────────┘  │ (핑거프린트 매칭)    │
           │                          └────────────────────┘
    ┌──────▼───────┐
    │  UrlHandler  │
    │ (URL 파싱)    │
    └──────────────┘

    ┌──────────────┐     ┌──────────────┐
    │ LimeLinkConfig│     │LimeLinkListener│ (Protocol)
    │ (설정)        │     │ (콜백)         │
    └──────────────┘     └──────────────┘

    ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
    │LimeLinkResult│     │LimeLinkError │     │LimeLinkRequest│
    │ (결과 모델)   │     │ (에러 모델)   │     │ (API 요청)    │
    └──────────────┘     └──────────────┘     └──────────────┘
```

### 설계 패턴

| 패턴 | 적용 클래스 | 목적 |
|------|-----------|------|
| Singleton | `LimeLinkSDK`, `UniversalLink` | 전역 상태 관리, 단일 진입점 |
| Observer (Listener) | `LimeLinkListener` | 비동기 결과 전달, 다중 수신자 |
| Bridge | `UniversalLinkHandlerBridge` | Swift ↔ Objective-C 상호운용 |
| Factory Method | `createLimeLinkRequest()` | 요청 객체 생성 |

---

## 4. 공개 API 명세

### 4.1 LimeLinkSDK

SDK의 메인 진입점입니다. 싱글톤 패턴으로 `LimeLinkSDK.shared`로 접근합니다.

#### 프로퍼티

```swift
@objc public static let shared: LimeLinkSDK
@objc public var isInitialized: Bool { get }
```

#### 메서드

| 메서드 | 설명 |
|--------|------|
| `static initialize(config: LimeLinkConfig)` | SDK 초기화. 앱 실행 시 1회 호출. 중복 호출 시 무시. |
| `addLinkListener(_ listener: LimeLinkListener)` | 딥링크 결과 리스너 등록. Weak reference로 관리. |
| `removeLinkListener(_ listener: LimeLinkListener)` | 리스너 해제. |
| `handleUniversalLink(_ url: URL)` | Universal Link URL 처리. 리스너를 통해 결과 전달. |
| `handleDeferredDeepLink(completion:)` | 수동 Deferred Deep Link 확인. completion과 리스너 모두에 결과 전달. |
| `trackLinkStatus(url: URL?)` | 수동 Stats 이벤트 전송. |

**`initialize(config:)` 상세:**

```swift
@objc public static func initialize(config: LimeLinkConfig)
```

- SDK를 설정으로 초기화합니다.
- `_isInitialized`가 `true`이면 중복 초기화를 방지합니다.
- `deferredDeeplinkEnabled == true`이고 `LinkStats.isFirstLaunch() == true`이면 자동으로 Deferred Deep Link를 확인합니다.
- 호출 시점: `application(_:didFinishLaunchingWithOptions:)`

**`handleUniversalLink(_:)` 상세:**

```swift
@objc public func handleUniversalLink(_ url: URL)
```

- 초기화 미완료 시 `LimeLinkError(code: -1)`을 리스너에 전달합니다.
- `UniversalLink.shared.handleUniversalLink(_:completion:)`을 내부적으로 호출합니다.
- 성공 시: `LimeLinkResult`를 리스너에 전달하고, `saveLimeLinkStatusInternal()`로 stats를 전송합니다.
- 실패 시: `LimeLinkError(code: 404)`를 리스너에 전달합니다.

**`handleDeferredDeepLink(completion:)` 상세:**

```swift
@objc public func handleDeferredDeepLink(
    completion: ((LimeLinkResult?, LimeLinkError?) -> Void)? = nil
)
```

- `DeferredDeepLinkService.getDeferredDeepLink()`를 내부적으로 호출합니다.
- 결과는 completion handler와 등록된 리스너 모두에 전달됩니다.
- `result.isDeferred`는 항상 `true`입니다.

### 4.2 LimeLinkConfig

SDK 설정을 담는 불변 모델입니다.

```swift
@objc public class LimeLinkConfig: NSObject {
    @objc public init(
        apiKey: String,
        baseUrl: String = "https://limelink.org/",
        loggingEnabled: Bool = false,
        deferredDeeplinkEnabled: Bool = true
    )
}
```

| 파라미터 | 타입 | 기본값 | 설명 |
|---------|------|-------|------|
| `apiKey` | `String` | (필수) | limelink.org 콘솔에서 발급한 API 키 |
| `baseUrl` | `String` | `"https://limelink.org/"` | API 서버 기본 URL |
| `loggingEnabled` | `Bool` | `false` | `[LimeLinkSDK]` 접두어 콘솔 로그 출력 |
| `deferredDeeplinkEnabled` | `Bool` | `true` | 첫 실행 시 Deferred Deep Link 자동 확인 |

> `baseUrl`은 trailing slash가 없으면 자동 추가됩니다.

### 4.3 LimeLinkListener

딥링크 결과를 수신하는 프로토콜입니다.

```swift
@objc public protocol LimeLinkListener: AnyObject {
    @objc func onDeeplinkReceived(result: LimeLinkResult)
    @objc optional func onDeeplinkError(error: LimeLinkError)
}
```

| 메서드 | 필수 | 설명 |
|--------|------|------|
| `onDeeplinkReceived(result:)` | O | 딥링크 해석 성공 시 호출. 메인 스레드에서 호출됨. |
| `onDeeplinkError(error:)` | X | 에러 발생 시 호출. 메인 스레드에서 호출됨. |

### 4.4 UniversalLink

URL 해석을 담당하는 싱글톤입니다. 일반적으로 `LimeLinkSDK`를 통해 간접 사용합니다.

```swift
@objc public class UniversalLink: NSObject {
    @objc public static let shared: UniversalLink

    @objc public func handleUniversalLink(_ url: URL, completion: @escaping (String?) -> Void)
    @objc public class func handleUniversalLink(_ url: URL, completion: @escaping (String?) -> Void)
}
```

- `completion`은 메인 스레드에서 호출됩니다.
- 성공 시 `uri: String`을 전달하고, 실패 시 `nil`을 전달합니다.

### 4.5 DeferredDeepLinkService

디바이스 핑거프린팅 기반 Deferred Deep Link 서비스입니다.

```swift
public class DeferredDeepLinkService {
    public static func getDeferredDeepLink(
        baseUrl: String? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    )
}
```

- `baseUrl`이 `nil`이면 `"https://limelink.org/"`을 사용합니다.
- 성공 시 `.success(uri)`, 실패 시 `.failure(error)`를 전달합니다.

### 4.6 LinkStats

첫 실행 여부를 판별하는 유틸리티입니다.

```swift
public class LinkStats {
    public static func isFirstLaunch() -> Bool
}
```

- 첫 호출 시 `true`를 반환하고 내부적으로 플래그를 설정합니다.
- 이후 호출부터는 항상 `false`를 반환합니다.
- `UserDefaults.standard`의 `"is_first_launch"` 키를 사용합니다.

### 4.7 URL 파싱 유틸리티

```swift
public func parseQueryParams(from url: URL?) -> [String: String]
public func parsePathParams(from url: URL?) -> PathParamResponse
```

- `parseQueryParams`: URL의 쿼리 스트링을 `[String: String]` 딕셔너리로 파싱합니다.
- `parsePathParams`: URL 경로의 첫 번째 세그먼트를 `mainPath`, 세 번째 세그먼트를 `subPath`로 추출합니다.

---

## 5. URL 패턴 및 라우팅

### 5.1 라우팅 우선순위

`UniversalLink.handleUniversalLink(_:completion:)`은 URL의 host를 기준으로 라우팅합니다:

```
1. host가 *.limelink.org → 서브도메인 패턴 처리
2. host가 limelink.org 또는 www.limelink.org → 직접 접근 패턴 처리
3. 기타 host → 레거시 딥링크 처리
```

### 5.2 서브도메인 패턴

**URL 형식**: `https://{suffix}.limelink.org/link/{linkSuffix}[?queryParams]`

**처리 흐름**:

```
1. host에서 suffix 추출 (예: "abc" from "abc.limelink.org")
2. path에서 /link/{linkSuffix} 패턴 매칭 (정규식: ^/link/(.+)$)
   2a. 매칭 실패 시 → suffix만으로 직접 API 호출
3. HEAD {suffix}.limelink.org → 응답 헤더 수집
4. GET {baseUrl}api/v1/app/dynamic_link/{linkSuffix}?full_request_url={encoded_url}
   - 헤더 전달: X-Request-ID, X-User-Agent, X-Referer, X-Forwarded-For, Authorization
5. 응답의 uri 필드를 completion으로 반환
```

**전달되는 헤더 목록**:

| 헤더 | 설명 |
|------|------|
| `X-Request-ID` | 요청 추적 ID |
| `X-User-Agent` | 사용자 에이전트 |
| `X-Referer` | 참조 URL |
| `X-Forwarded-For` | 클라이언트 IP |
| `Authorization` | 인증 토큰 |

### 5.3 직접 접근 패턴

**URL 형식**:
- `https://limelink.org/universal-link/app/dynamic_link/{suffix}`
- `https://limelink.org/api/v1/app/dynamic_link/{suffix}`
- `https://www.limelink.org/...` (www 접두어 포함)

**처리 흐름**:

```
1. path에서 suffix 추출 (정규식: ^/universal-link/app/dynamic_link/(.+)$ 또는
                                 ^/api/v1/app/dynamic_link/(.+)$)
   1a. 두 패턴 모두 불일치 시 → completion(nil)
2. GET {baseUrl}api/v1/app/dynamic_link/{suffix}?full_request_url={encoded_url}
3. 응답의 uri 필드를 completion으로 반환
```

### 5.4 레거시 패턴

**URL 형식**: `https://{any_host}/{path}` (limelink.org 이외의 호스트)

**처리 흐름**:

```
1. host에서 subdomain 추출 (첫 번째 점 이전 부분)
2. GET https://deep.limelink.org/link?subdomain={subdomain}&path={path}&platform=ios
3. 응답의 deeplinkUrl 필드를 completion으로 반환
```

---

## 6. 네트워크 API 명세

모든 API 호출은 `URLSession.shared`를 사용합니다. `baseUrl`은 `LimeLinkConfig`에서 설정 가능합니다.

### 6.1 Dynamic Link 조회

```
GET {baseUrl}api/v1/app/dynamic_link/{suffix}
```

**Query Parameters**:

| 파라미터 | 필수 | 설명 |
|---------|------|------|
| `full_request_url` | O | 원본 URL (URL 인코딩됨) |
| `event_type` | X | Deferred Deep Link인 경우 `"setup"` |

**Request Headers**:
- `Content-Type: application/json`
- (서브도메인 패턴의 경우) HEAD 응답에서 수집한 헤더 포함

**Response** (200 OK):
```json
{
  "uri": "myapp://product/123"
}
```

### 6.2 Deferred Deep Link 조회

```
GET {baseUrl}api/v1/deferred-deep-link
```

**Query Parameters**:

| 파라미터 | 필수 | 설명 |
|---------|------|------|
| `width` | O | 디바이스 화면 너비 (points) |
| `height` | O | 디바이스 화면 높이 (points) |
| `user_agent` | O | OS 정보 (예: `"iOS 18_7"`) |

**Request Headers**:
- `Content-Type: application/json`

**Response** (200 OK):
```json
{
  "suffix": "testsub",
  "full_request_url": "https://example.com/link"
}
```

**에러 응답**: `suffix`가 `null`이면 매칭 실패

### 6.3 Stats 이벤트 전송

```
POST {baseUrl}api/v1/stats/event
```

**Request Headers**:
- `Content-Type: application/json`

**Request Body**:
```json
{
  "private_key": "api_key_value",
  "suffix": "main_path",
  "handle": "sub_path",
  "event_type": "first_run",
  "operating_system": "ios"
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `private_key` | `String` | API 키 |
| `suffix` | `String` | URL의 주 경로 세그먼트 |
| `handle` | `String?` | URL의 부 경로 세그먼트 |
| `event_type` | `String` | `"first_run"`, `"rerun"`, `"setup"` 중 하나 |
| `operating_system` | `String` | 항상 `"ios"` |

### 6.4 레거시 딥링크 조회

```
GET https://deep.limelink.org/link
```

**Query Parameters**:

| 파라미터 | 필수 | 설명 |
|---------|------|------|
| `subdomain` | O | 호스트의 첫 번째 도메인 부분 |
| `path` | O | URL 경로 (URL 인코딩됨) |
| `platform` | O | 항상 `"ios"` |

**Response** (200 OK):
```json
{
  "deeplinkUrl": "myapp://deeplink/abc"
}
```

### 6.5 서브도메인 헤더 수집

```
HEAD https://{suffix}.limelink.org
```

- 순수 헤더 수집 용도
- 응답 헤더에서 `X-Request-ID`, `X-User-Agent`, `X-Referer`, `X-Forwarded-For`, `Authorization`을 추출하여 Dynamic Link API에 전달합니다.
- 실패 시 빈 헤더로 진행합니다.

---

## 7. 데이터 모델

### 7.1 LimeLinkResult

```swift
@objc public class LimeLinkResult: NSObject {
    @objc public let originalUrl: String?
    @objc public let resolvedUri: String?
    @objc public let queryParams: [String: String]
    @objc public let pathParams: PathParamResponse
    @objc public let isDeferred: Bool
}
```

### 7.2 LimeLinkError

```swift
@objc public class LimeLinkError: NSObject, LocalizedError {
    @objc public let code: Int
    @objc public let message: String
    @objc public let underlyingError: Error?

    public var errorDescription: String?   // LocalizedError
    override public var description: String // CustomStringConvertible
}
```

### 7.3 PathParamResponse

```swift
@objc public class PathParamResponse: NSObject {
    @objc public var mainPath: String
    @objc public var subPath: String?
}
```

### 7.4 LimeLinkRequest (Internal)

```swift
public class LimeLinkRequest: Codable {
    var private_key: String
    var suffix: String
    var handle: String?
    var event_type: String
    var operating_system: String  // 기본값: "ios"
}
```

### 7.5 EventType (Internal)

```swift
enum EventType: String {
    case FIRST_RUN = "first_run"
    case RERUN = "rerun"
    case SETUP = "setup"
}
```

### 7.6 내부 응답 모델

```swift
struct UniversalLinkResponse: Codable {
    let uri: String
}

struct DeeplinkResponse: Codable {
    let deeplinkUrl: String
}

private struct SuffixResponse: Codable {
    let suffix: String?
    let fullRequestUrl: String?  // CodingKey: "full_request_url"
}

private struct DynamicLinkResponse: Codable {
    let uri: String
}
```

---

## 8. 동작 흐름

### 8.1 SDK 초기화 흐름

```
LimeLinkSDK.initialize(config:)
  │
  ├─ 이미 초기화됨 → 로그 출력, 리턴
  │
  └─ 초기화 수행
       ├─ config 저장
       ├─ _isInitialized = true
       └─ deferredDeeplinkEnabled && isFirstLaunch()
            ├─ true → handleDeferredDeepLink() 자동 호출
            └─ false → 리턴
```

### 8.2 Universal Link 처리 흐름 (서브도메인)

```
handleUniversalLink(url)
  │
  ├─ 미초기화 → notifyError(code: -1), 리턴
  │
  └─ UniversalLink.shared.handleUniversalLink(url) { uri in
       │
       ├─ host: *.limelink.org
       │    ├─ /link/{linkSuffix} 패턴 매칭
       │    │    ├─ HEAD {suffix}.limelink.org → 헤더 수집
       │    │    └─ GET /api/v1/app/dynamic_link/{linkSuffix}
       │    │         ?full_request_url=... (헤더 포함)
       │    │
       │    └─ 패턴 불일치 → GET /api/v1/app/dynamic_link/{suffix}
       │
       ├─ uri != nil
       │    ├─ parseQueryParams(url) → queryParams
       │    ├─ parsePathParams(url) → pathParams
       │    ├─ LimeLinkResult 생성 (isDeferred: false)
       │    ├─ notifyResult(result) → 리스너 콜백
       │    └─ saveLimeLinkStatusInternal() → Stats POST
       │
       └─ uri == nil
            └─ notifyError(code: 404)
  }
```

### 8.3 Deferred Deep Link 흐름

```
handleDeferredDeepLink(completion:)
  │
  ├─ 미초기화 → completion?(nil, error), notifyError, 리턴
  │
  └─ DeferredDeepLinkService.getDeferredDeepLink(baseUrl:) { result in
       │
       ├─ 1단계: 디바이스 정보 수집
       │    ├─ UIScreen.main.bounds → width, height
       │    └─ UIDevice.current.systemVersion → user_agent ("iOS 18_7")
       │
       ├─ 2단계: Suffix 조회
       │    └─ GET /api/v1/deferred-deep-link?width=&height=&user_agent=
       │         ├─ 200 + suffix 존재 → 3단계로
       │         └─ 에러 또는 suffix null → .failure
       │
       ├─ 3단계: Dynamic Link 조회
       │    └─ GET /api/v1/app/dynamic_link/{suffix}
       │         ?full_request_url=...&event_type=setup
       │         ├─ 200 → .success(uri)
       │         └─ 에러 → .failure
       │
       ├─ .success(uri)
       │    ├─ LimeLinkResult 생성 (isDeferred: true)
       │    ├─ notifyResult(result) → 리스너 콜백
       │    └─ completion?(result, nil)
       │
       └─ .failure(error)
            ├─ LimeLinkError 생성
            ├─ notifyError(error) → 리스너 콜백
            └─ completion?(nil, error)
  }
```

### 8.4 Stats 전송 흐름

```
trackLinkStatus(url:)
  │
  ├─ 미초기화 → 로그, 리턴
  │
  └─ saveLimeLinkStatusInternal(url:, privateKey:)
       │
       ├─ url == nil → 리턴
       ├─ parsePathParams(url) → mainPath 비어있으면 리턴
       │
       ├─ createLimeLinkRequest(
       │      privateKey, pathParam, eventType: RERUN)
       │
       └─ sendLimeLink(data: request) { result in
            POST /api/v1/stats/event
            Content-Type: application/json
            Body: LimeLinkRequest JSON
       }
```

---

## 9. 에러 처리

### 에러 코드

| 코드 | 상수 | 발생 조건 |
|------|------|----------|
| `-1` | SDK_NOT_INITIALIZED | `initialize(config:)` 호출 전 API 사용 |
| `404` | LINK_RESOLUTION_FAILED | Universal Link URI 해석 실패 |
| `0` | INVALID_URL | URL 생성 실패 |
| `0` | NO_MATCH | Deferred Deep Link 매칭 실패 |
| `4xx/5xx` | HTTP_ERROR | API 서버 응답 에러 |
| `NSURLErrorTimedOut` | NETWORK_TIMEOUT | 네트워크 타임아웃 |

### 에러 전파 방식

- **Listener**: `onDeeplinkError(error:)` optional 메서드로 전달 (메인 스레드)
- **Completion Handler**: `handleDeferredDeepLink`의 completion에 에러 전달
- **Silent Failure**: `trackLinkStatus()`는 에러를 외부에 전파하지 않음

---

## 10. 저장소 및 상태 관리

### UserDefaults 사용

| 키 | 타입 | 용도 |
|----|------|------|
| `"is_first_launch"` | `Bool` | 첫 실행 여부 판별 |

- `LinkStats.isFirstLaunch()`는 `UserDefaults.standard.object(forKey: "is_first_launch") == nil`로 첫 실행을 감지합니다.
- 첫 호출 시 `true` 반환 후 `false`로 설정하여 이후 호출에서는 `false`를 반환합니다.

### 싱글톤 상태

| 클래스 | 상태 | 설명 |
|--------|------|------|
| `LimeLinkSDK.shared` | `_isInitialized`, `config`, `listeners` | SDK 전역 상태 |
| `UniversalLink.shared` | (stateless) | 상태 없음, config는 LimeLinkSDK에서 참조 |

### Listener 관리

- `NSHashTable<AnyObject>.weakObjects()`를 사용하여 weak reference로 관리합니다.
- Listener 객체가 해제되면 자동으로 제거됩니다.
- 명시적 해제는 `removeLinkListener(_:)`로 가능합니다.

---

## 11. 스레딩 모델

### 메인 스레드 보장

| 메서드 | 스레드 |
|--------|--------|
| `onDeeplinkReceived(result:)` | Main Thread (`DispatchQueue.main.async`) |
| `onDeeplinkError(error:)` | Main Thread (`DispatchQueue.main.async`) |
| `UniversalLink` completion handler | Main Thread (`DispatchQueue.main.async`) |

### 백그라운드 처리

| 작업 | 스레드 |
|------|--------|
| `URLSession.shared.dataTask` | URLSession delegate queue (Background) |
| 응답 파싱 (JSONDecoder) | URLSession delegate queue (Background) |
| `handleDeferredDeepLink` 내부 | URLSession delegate queue (Background) |

### 주의사항

- 모든 공개 API는 메인 스레드에서 호출해야 합니다.
- Listener 콜백은 메인 스레드에서 전달되므로 UI 업데이트가 안전합니다.
- 네트워크 응답 처리 후 `DispatchQueue.main.async`로 스레드 전환합니다.

---

## 12. Objective-C 호환성

### 지원 범위

- 모든 공개 API에 `@objc` 어노테이션 적용
- 모든 공개 클래스는 `NSObject`를 상속
- `LimeLinkListener` 프로토콜은 `@objc protocol`로 선언

### ObjC Bridge 구조

```
[ObjC 코드]
    │
    └─ UniversalLinkHandlerBridge (ObjC 클래스)
         │
         ├─ +handleUniversalLink:(NSURL *)url
         │    ├─ LimeLinkSDK.shared 사용 가능 → handleUniversalLink(url:)
         │    └─ 불가 → UniversalLink.shared 직접 호출
         │
         └─ +handleUniversalLink:(NSURL *)url completion:(block)
              └─ UniversalLink.shared.handleUniversalLink(_:completion:)
```

### 빌드 설정

| 설정 | 값 | 설명 |
|------|-----|------|
| `SWIFT_OBJC_INTERFACE_HEADER_NAME` | `LimelinkIOSSDK-Swift.h` | Swift→ObjC 자동 생성 헤더 |
| `DEFINES_MODULE` | `YES` | 모듈 정의 활성화 |
| `SWIFT_INSTALL_OBJC_HEADER` | `YES` | ObjC 헤더 설치 |
| `CLANG_ENABLE_MODULES` | `YES` | Clang 모듈 지원 |

---

## 13. 테스트 명세

### 테스트 환경

- 프레임워크: XCTest (외부 의존성 없음)
- 네트워크 모킹: `URLProtocol` 서브클래스 (`MockURLProtocol`)
- 총 테스트: **108개** (107 계획 + 1 스모크)

### 테스트 분류

| 카테고리 | 파일 수 | 테스트 수 | 대상 |
|---------|--------|---------|------|
| 모델 Unit | 7 | 35 | Config, UrlHandler, PathParam, Request, EventType, Error, Result |
| 서비스 Unit | 5 | 58 | LinkStats, UniversalLink, DeferredDeepLink, LimelinkService, SDK |
| Integration | 3 | 14 | E2E 흐름, ObjC Bridge, 다중 Listener |
| 스모크 | 1 | 1 | 기본 동작 확인 |

### 테스트 인프라

| 파일 | 역할 |
|------|------|
| `MockURLProtocol` | `URLProtocol` 서브클래스. URL 패턴별 응답 매핑, longest-match 로직 |
| `MockLimeLinkListener` | `LimeLinkListener` 구현. 수신 결과/에러 저장, XCTestExpectation 연동 |
| `TestConstants` | 테스트 URL, JSON 응답, Config 팩토리 |
| `LimeLinkTestCase` | 공통 setUp/tearDown. URLProtocol 등록, SDK 리셋, UserDefaults 정리 |

### 검증 항목

- SDK 초기화/중복 방지/미초기화 에러
- 3가지 URL 패턴 라우팅 (서브도메인, 직접, 레거시)
- 서브도메인 HEAD 헤더 수집 및 전달
- Dynamic Link API 성공/실패
- Deferred Deep Link 2단계 API 흐름
- Stats POST 전송 및 JSON 바디 검증
- Listener 약한참조 관리 및 다중 Listener 통지
- ObjC Bridge 클래스 존재 및 동작
- 메인 스레드 콜백 보장

---

## 14. 보안 고려사항

### 데이터 전송

- 모든 API 통신은 HTTPS를 사용합니다.
- `apiKey`는 Stats 이벤트의 `private_key` 필드로 전송됩니다.
- HTTP body는 JSON으로 직렬화됩니다.

### 로컬 저장소

- `UserDefaults.standard`에 `"is_first_launch"` 플래그만 저장합니다.
- 민감한 데이터(apiKey 등)는 로컬에 영구 저장하지 않습니다.
- `apiKey`는 메모리에서만 `LimeLinkConfig` 인스턴스로 유지됩니다.

### 디바이스 정보

- Deferred Deep Link에서 수집하는 정보: 화면 너비, 높이, OS 버전
- 개인 식별 정보(PII)는 수집하지 않습니다.
- IDFA, IDFV 등 광고 식별자를 사용하지 않습니다.

---

## 15. 제한사항 및 알려진 이슈

### 기능 제한

| 항목 | 설명 |
|------|------|
| 패키지 매니저 | CocoaPods만 지원. SPM 미지원. |
| 동시성 | `URLSession.shared` 전역 인스턴스 사용. 커스텀 URLSession 주입 불가. |
| 오프라인 | 오프라인 캐싱 미지원. 네트워크 연결 필수. |
| 재시도 | API 요청 실패 시 자동 재시도 없음. |
| 디바이스 매칭 | 화면 크기 + OS 버전으로 핑거프린팅. 동일 사양 기기 간 오매칭 가능성 있음. |

### 알려진 이슈

| 이슈 | 상태 | 설명 |
|------|------|------|
| `navigateToDeeplink(_:)` 미사용 | 유지 | `UIApplication.shared.open()` 호출 메서드. 현재 사용되지 않음. |
| 스레드 안전성 | 제한적 | `NSHashTable` 접근이 동기화되지 않음. 메인 스레드 전용 사용 권장. |
| 레거시 API deprecated | 계획 | `saveLimeLinkStatus()`, `UniversalLink.handleUniversalLink(_:)` (completion 없는 버전) |

---

## 16. 변경 이력

### v0.2.0 (Current)

- `LimeLinkSDK` 싱글톤 진입점 추가
- `LimeLinkConfig` 설정 모델 도입
- `LimeLinkListener` 프로토콜 기반 콜백 패턴
- `LimeLinkResult`, `LimeLinkError` 결과/에러 모델
- Configurable `baseUrl` 지원
- Deferred Deep Link 자동 모드
- ObjC Bridge SDK 경유 라우팅
- `LinkStats.isFirstLaunch()` 버그 수정 (`object(forKey:) == nil` 사용)
- 레거시 URL 쿼리 수정 (`/` → `?`)
- 테스트 스위트 108개 추가

### v0.1.x

- 초기 릴리즈
- Universal Link 기본 지원
- Stats 이벤트 전송
- ObjC Bridge
