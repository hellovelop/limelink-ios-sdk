
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
2. Makes a request to `https://www.limelink.org/api/v1/dynamic_link/{link_suffix}` API with header information
3. Returns the `uri` value via completion handler, which contains the link to be handled by the app

#### 2. Direct Access Method
When directly accessing `https://www.limelink.org/api/v1/dynamic_link/{suffix}`:

1. SDK makes a direct API request
2. Returns the `uri` value via completion handler, which contains the link to be handled by the app

### Examples

**Swift:**
```swift
// Method 1: Subdomain Access
// When accessing https://abc123.limelink.org/link/test
// 1. Collect header information from subdomain
// 2. Call https://www.limelink.org/api/v1/dynamic_link/test API
// 3. API response: {"uri": "abc123://test?test.com"}
// 4. Return the link via completion handler

// Method 2: Direct Access
// When accessing https://www.limelink.org/api/v1/dynamic_link/test
// 1. Make direct API call
// 2. API response: {"uri": "abc123://test?test.com"}
// 3. Return the link via completion handler
```

**Objective-C:**
```objc
// Method 1: Subdomain Access
// When accessing https://abc123.limelink.org/link/test
// 1. Collect header information from subdomain
// 2. Call https://www.limelink.org/api/v1/dynamic_link/test API
// 3. API response: {"uri": "abc123://test?test.com"}
// 4. Return the link via completion handler

// Method 2: Direct Access
// When accessing https://www.limelink.org/api/v1/dynamic_link/test
// 1. Make direct API call
// 2. API response: {"uri": "abc123://test?test.com"}
// 3. Return the link via completion handler
```

## Deferred Deep Link Support

Deferred Deep Link allows you to receive link parameters when the app is first launched after installation, even if the user clicked the link before the app was installed.

### Usage

#### 1. Get Parameters by Token (Use on first launch after app installation)

Retrieve parameters using a stored token when the app is first launched after installation.

**Swift:**
```swift
import UIKit
import LimelinkIOSSDK

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Get parameters by token on first launch after app installation
        let token = "your_deferred_deep_link_token"
        
        DeferredDeepLinkService.getDeferredDeepLinkByToken(token: token) { result in
            switch result {
            case .success(let response):
                // Handle parameters
                if let parameters = response.parameters {
                    print("Parameters: \(parameters)")
                    // Example: {"product_id": "123", "campaign": "summer_sale"}
                }
                
                // iOS App Store URL
                if let iosAppStoreURL = response.ios_app_store_url {
                    print("iOS App Store URL: \(iosAppStoreURL)")
                }
                
                // Fallback URL (when app is not installed)
                if let fallbackURL = response.fallback_url {
                    print("Fallback URL: \(fallbackURL)")
                }
                
            case .failure(let error):
                print("Error: \(error)")
            }
        }
    }
}
```

**Objective-C:**
```objc
#import <LimelinkIOSSDK/LimelinkIOSSDK-Swift.h>

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *token = @"your_deferred_deep_link_token";
    
    [DeferredDeepLinkService getDeferredDeepLinkByTokenWithToken:token 
                                                       completion:^(id _Nullable result, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error: %@", error);
            return;
        }
        
        GetDeferredDeepLinkByTokenResponse *response = (GetDeferredDeepLinkByTokenResponse *)result;
        
        // Handle parameters
        NSDictionary *parameters = response.parameters;
        if (parameters) {
            NSLog(@"Parameters: %@", parameters);
        }
        
        // iOS App Store URL
        NSString *iosAppStoreURL = response.ios_app_store_url;
        if (iosAppStoreURL) {
            NSLog(@"iOS App Store URL: %@", iosAppStoreURL);
        }
        
        // Fallback URL
        NSString *fallbackURL = response.fallback_url;
        if (fallbackURL) {
            NSLog(@"Fallback URL: %@", fallbackURL);
        }
    }];
}
```

#### 2. Check Token Availability

Check if a token is already registered.

**Swift:**
```swift
import UIKit
import LimelinkIOSSDK

let token = "your_deferred_deep_link_token"

DeferredDeepLinkService.checkToken(token: token) { result in
    switch result {
    case .success(let response):
        if response.is_exist {
            print("Token already exists")
        } else {
            print("Token is available")
        }
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

**Objective-C:**
```objc
#import <LimelinkIOSSDK/LimelinkIOSSDK-Swift.h>

NSString *token = @"your_deferred_deep_link_token";

[DeferredDeepLinkService checkTokenWithToken:token 
                                   completion:^(id _Nullable result, NSError * _Nullable error) {
    if (error) {
        NSLog(@"Error: %@", error);
        return;
    }
    
    CheckTokenResponse *response = (CheckTokenResponse *)result;
    if (response.is_exist) {
        NSLog(@"Token already exists");
    } else {
        NSLog(@"Token is available");
    }
}];
```

### Use Cases

1. **Link Click Before App Installation Scenario:**
   - User clicks a link on the web
   - If the app is not installed, redirect to App Store
   - After app installation, retrieve parameters using the token on first launch
   - Navigate to the appropriate screen using the retrieved parameters

2. **Marketing Campaign Tracking:**
   - Create unique tokens for each campaign
   - Retrieve campaign information using the token on first launch after app installation
   - Route users to the appropriate screen based on parameters


