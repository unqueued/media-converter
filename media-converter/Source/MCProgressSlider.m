//
//  MCProgressSlider.m
//  Media Converter
//
//  Created by Maarten Foukhar on 30-08-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCProgressSlider.h"
#import "MCCommonMethods.h"
#import "NSControl_Extensions.h"


@implementation MCProgressSlider

- (void)setObjectValue:(id <NSCopying>)obj
{
	[super setObjectValue:obj];
	[self setText:[self cgfloatValue]];
}

- (BOOL)sendAction:(SEL)theAction to:(id)theTarget
{
	[self setText:[self cgfloatValue]];
	
	return [super sendAction:theAction to:theTarget];
}

- (void)setText:(CGFloat)value
{
	NSString *percentString = [NSString stringWithFormat:@"%0.f %@", value * 100.0, @"%"];
	[statusText setStringValue:percentString];
}

@end
