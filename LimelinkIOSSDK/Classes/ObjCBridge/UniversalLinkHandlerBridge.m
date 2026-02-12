//
//  UniversalLinkHandlerBridge.m
//  LimelinkIOSSDK
//
//  Created by 김길현 on 8/10/25.
//

#import <Foundation/Foundation.h>
#import "UniversalLinkHandlerBridge.h"

@implementation UniversalLinkHandlerBridge

+ (void)handleUniversalLink:(NSURL *)url {
    // Use LimeLinkSDK singleton for handling universal links
    Class sdkClass = NSClassFromString(@"LimeLinkSDK");
    if (sdkClass) {
        id sharedInstance = [sdkClass performSelector:@selector(shared)];
        if (sharedInstance) {
            [sharedInstance performSelector:@selector(handleUniversalLink:) withObject:url];
            return;
        }
    }

    // Fallback: Use UniversalLink directly if SDK is not initialized
    Class universalLinkClass = NSClassFromString(@"UniversalLink");
    if (universalLinkClass) {
        id sharedInstance = [universalLinkClass performSelector:@selector(shared)];
        if (sharedInstance) {
            [sharedInstance performSelector:@selector(handleUniversalLink:) withObject:url];
        }
    }
}

+ (void)handleUniversalLink:(NSURL *)url completion:(void (^)(NSString * _Nullable))completion {
    Class universalLinkClass = NSClassFromString(@"UniversalLink");
    if (universalLinkClass) {
        id sharedInstance = [universalLinkClass performSelector:@selector(shared)];
        if (sharedInstance && [sharedInstance respondsToSelector:@selector(handleUniversalLink:completion:)]) {
            // Use NSInvocation for block-based selectors
            SEL selector = @selector(handleUniversalLink:completion:);
            NSMethodSignature *sig = [sharedInstance methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
            [invocation setTarget:sharedInstance];
            [invocation setSelector:selector];
            [invocation setArgument:&url atIndex:2];
            [invocation setArgument:&completion atIndex:3];
            [invocation invoke];
            return;
        }
    }
    if (completion) {
        completion(nil);
    }
}

@end
