//
//  NSString_Extensions.h
//  Media Converter
//
//  Created by Maarten Foukhar on 03-02-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MCCommonMethods.h"


@interface NSString (MyExtensions)
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
- (NSInteger)integerValue;
#endif
- (CGFloat)cgfloatValue;
@end