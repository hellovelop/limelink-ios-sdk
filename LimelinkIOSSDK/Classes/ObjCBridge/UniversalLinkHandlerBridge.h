//
//  UniversalLinkHandlerBridge.h
//  LimelinkIOSSDK
//
//  Created by 김길현 on 8/10/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UniversalLinkHandlerBridge : NSObject

/// Handle universal link through LimeLinkSDK (recommended)
+ (void)handleUniversalLink:(NSURL *)url;

/// Handle universal link with completion handler
+ (void)handleUniversalLink:(NSURL *)url completion:(void (^)(NSString * _Nullable uri))completion;

@end

NS_ASSUME_NONNULL_END
