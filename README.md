
# LimelinkIOSSDK
<img src="https://limelink.org/assets/default_lime-C14nNSvc.svg" alt="이미지 설명" style="display: block; margin-left: auto; margin-right: auto; width: 30%;">


[![Version](https://img.shields.io/cocoapods/v/LimelinkIOSSDK.svg?style=flat)](https://cocoapods.org/pods/LimelinkIOSSDK)
[![License](https://img.shields.io/cocoapods/l/LimelinkIOSSDK.svg?style=flat)](https://cocoapods.org/pods/LimelinkIOSSDK)
[![Platform](https://img.shields.io/cocoapods/p/LimelinkIOSSDK.svg?style=flat)](https://cocoapods.org/pods/LimelinkIOSSDK)

### Installation and requirements
Add pod file
```
pod 'LimelinkIOSSDK'
```

If it's completed, let's refer to the SDK Usage Guide and create it.


# SDK Usage Guide
### Save statistical information
Open ***ViewController.swift*** and add the following code
```
import UIKit
import LimelinkIOSSDK

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        /* Example */
        let url = URL(string: "your_url")!
        saveLimeLinkStatus(url: url, privateKey: "your_private_key")
    }
}
```
- This way, you can save information about the first run or relaunch of the app. You can check the actual metrics on the https://limelink.org console.
- The privateKey value is required. If you don't have it, obtain it from the https://limelink.org console and use it.

### Use handle information superficially
Open ***ViewController*** and add the following code

```
import UIKit
import LimelinkIOSSDK

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        /* Example */
        handleIntent()

    }
    
    private func handleIntent() {
        if let url = URL(string: "your_url") {
            let pathParamResponse = parsePathParams(from:url)
            let suffix = pathParamResponse.mainPath

            let handle = pathParamResponse.subPath
            if handle == "example" {
              //Navigate to the desired screen
            }
        }
    }
}
```


- This way, you can handle the information superficially and navigate to the desired screen based on the handle value.

## Universal Link Support

### Setup Instructions

1. **Info.plist Configuration**
   - Add `applinks:limelink.org` to `com.apple.developer.associated-domains`
   - Register `limelink` scheme in `CFBundleURLTypes`

2. **AppDelegate Configuration**

   **Swift:**
   ```swift
   // Universal Link handling
   func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
       if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
           if let url = userActivity.webpageURL {
               UniversalLink.shared.handleUniversalLink(url) { uri in
                   if let uri = uri {
                       print("Universal Link URI: \(uri)")
                       // Handle the received URI here or pass it
                       // Note: You must use completion handler in both Swift and Objective-C
                   } else {
                       print("Failed to receive Universal Link URI")
                   }
               }
               return true
           }
       }
       return false
   }
   ```

   **Objective-C:**
   ```objc
   #import <LimelinkIOSSDK/UniversalLinkHandlerBridge.h>
   
   // Universal Link handling
   - (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
       if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
           NSURL *url = userActivity.webpageURL;
           if (url) {
               [[UniversalLink shared] handleUniversalLink:url completion:^(NSString * _Nullable uri) {
                   if (uri) {
                       NSLog(@"Universal Link URI: %@", uri);
                       // Handle the received URI here or pass it
                       // Note: You must use completion handler in both Swift and Objective-C
                   } else {
                       NSLog(@"Failed to receive Universal Link URI");
                   }
               }];
               return YES;
           }
       }
       return NO;
   }
   ```

### Usage

#### 1. Subdomain Method (Recommended)
When accessing `https://{suffix}.limelink.org/link/{link_suffix}`:

1. SDK retrieves header information from the subdomain
2. Makes a request to `https://www.limelink.org/api/v1/app/dynamic_link/{link_suffix}` API with header information
3. Returns the `uri` value via completion handler, which contains the link to be handled by the app

#### 2. Direct Access Method
When directly accessing `https://www.limelink.org/api/v1/app/dynamic_link/{suffix}`:

1. SDK makes a direct API request
2. Returns the `uri` value via completion handler, which contains the link to be handled by the app

### Examples

**Swift:**
```swift
// Method 1: Subdomain Access
// When accessing https://abc123.limelink.org/link/test
// 1. Collect header information from subdomain
// 2. Call https://www.limelink.org/api/v1/app/dynamic_link/test API
// 3. API response: {"uri": "abc123://test?test.com"}
// 4. Return the link via completion handler

// Method 2: Direct Access
// When accessing https://www.limelink.org/api/v1/app/dynamic_link/test
// 1. Make direct API call
// 2. API response: {"uri": "abc123://test?test.com"}
// 3. Return the link via completion handler
```

**Objective-C:**
```objc
// Method 1: Subdomain Access
// When accessing https://abc123.limelink.org/link/test
// 1. Collect header information from subdomain
// 2. Call https://www.limelink.org/api/v1/app/dynamic_link/test API
// 3. API response: {"uri": "abc123://test?test.com"}
// 4. Return the link via completion handler

// Method 2: Direct Access
// When accessing https://www.limelink.org/api/v1/app/dynamic_link/test
// 1. Make direct API call
// 2. API response: {"uri": "abc123://test?test.com"}
// 3. Return the link via completion handler
```

## Deferred Deep Link Support

Deferred Deep Link allows you to retrieve deep link information when the app is first launched after installation, even if the user clicked the link before the app was installed. This implementation uses device fingerprinting (screen size and OS version) to match users.

### How It Works

1. User clicks a link on the web
2. Server stores device information (width, height, user agent) with the link suffix
3. If app is not installed, redirect to App Store
4. After app installation, on first launch, SDK automatically matches device information
5. SDK retrieves the deep link URI and navigates to the appropriate screen

### Usage

**Swift:**
```swift
import UIKit
import LimelinkIOSSDK

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Check for deferred deep link on first launch
        if LinkStats.isFirstLaunch() {
            checkDeferredDeepLink()
        }
    }
    
    private func checkDeferredDeepLink() {
        DeferredDeepLinkService.getDeferredDeepLink { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let uri):
                    print("✅ Deferred Deep Link URI: \(uri)")
                    // Navigate to the appropriate screen using the URI
                    self.handleDeepLink(uri)
                    
                case .failure(let error):
                    print("❌ No deferred deep link found or error: \(error.localizedDescription)")
                    // No matching deferred deep link found - continue with normal flow
                }
            }
        }
    }
    
    private func handleDeepLink(_ uri: String) {
        if let url = URL(string: uri) {
            // Handle the deep link
            // Example: myapp://product/123
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
```

**Objective-C:**
```objc
#import <LimelinkIOSSDK/LimelinkIOSSDK-Swift.h>

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Check for deferred deep link on first launch
    if ([LinkStats isFirstLaunch]) {
        [self checkDeferredDeepLink];
    }
}

- (void)checkDeferredDeepLink {
    [DeferredDeepLinkService getDeferredDeepLinkWithCompletion:^(NSString * _Nullable uri, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"❌ No deferred deep link found or error: %@", error.localizedDescription);
                // No matching deferred deep link found - continue with normal flow
                return;
            }
            
            if (uri) {
                NSLog(@"✅ Deferred Deep Link URI: %@", uri);
                // Navigate to the appropriate screen using the URI
                [self handleDeepLink:uri];
            }
        });
    }];
}

- (void)handleDeepLink:(NSString *)uri {
    NSURL *url = [NSURL URLWithString:uri];
    if (url) {
        // Handle the deep link
        // Example: myapp://product/123
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}
```

### Device Information Collected

The SDK automatically collects the following information to match users:
- **Screen Width**: Device screen width in points
- **Screen Height**: Device screen height in points
- **User Agent**: iOS version in format "iOS 18_7" (e.g., iOS 18.7 → "iOS 18_7")

### Event Tracking

When the SDK successfully retrieves a deferred deep link, it automatically sends tracking information to the server:
- **full_request_url**: The original URL that was accessed before app installation
- **event_type**: Set to "setup" to indicate this is a deferred deep link conversion event

This allows you to track successful app installations and first launches that originated from your marketing links.

### API Flow

```
1. SDK collects device info (width, height, user_agent)
   ↓
2. GET /deferred-deep-link?width=414&height=896&user_agent=iOS 18_7
   ↓
3. Server returns: {"suffix": "testsub", "full_request_url": "https://example.com/link"}
   ↓
4. GET /dynamic_link/testsub?full_request_url=https://example.com/link&event_type=setup
   ↓
5. Server returns: {"uri": "myapp://product/123"}
   ↓
6. SDK returns the URI via completion handler
```

### Use Cases

1. **Link Click Before App Installation:**
   - User clicks a marketing link on mobile web
   - Server stores device fingerprint with the link information
   - User is redirected to App Store
   - After installation, on first launch, SDK automatically retrieves the deep link
   - User is navigated to the intended content

2. **Marketing Campaign Tracking:**
   - Track which campaign led to app installation
   - Direct users to specific onboarding flows or promotional content
   - Measure campaign effectiveness

3. **Product Sharing:**
   - User shares a product link
   - New user clicks the link but doesn't have the app
   - After installing and opening the app, they're taken directly to the shared product


