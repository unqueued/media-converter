//
//  MCPantherCompatibleButton.m
//  Media Converter
//
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCPantherCompatibleButton.h"
#import "MCCommonMethods.h"

@implementation MCPantherCompatibleButton

- (void)awakeFromNib
{
	if ([MCCommonMethods OSVersion] > 0x1039)
		[self setBezelStyle:10];
}

@end
