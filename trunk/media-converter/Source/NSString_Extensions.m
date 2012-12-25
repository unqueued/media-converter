//
//  NSString_Extensions.m
//  Media Converter
//
//  Created by Maarten Foukhar on 03-02-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "NSString_Extensions.h"


@implementation NSString (MyExtensions)

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
- (NSInteger)integerValue
{
	return [self intValue];
}

- (NSString *)stringByReplacingOccurrencesOfString:(NSString *)target withString:(NSString *)replacement
{
	NSMutableString *mutString = [self mutableCopy];
	
	[mutString replaceOccurrencesOfString:target withString:replacement options:NSLiteralSearch	range:NSMakeRange(0, [self length])];
	
	return [mutString autorelease];
}
#endif

- (CGFloat)cgfloatValue
{
	#if __LP64__ || NS_BUILD_32_LIKE_64
	return [self doubleValue];
	#else
	return [self floatValue];
	#endif
}

@end
