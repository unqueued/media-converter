//
//  MCTextView.m
//  Media Converter
//
//  Created by Maarten Foukhar on 02-08-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCTextView.h"


@implementation MCTextView

- (void)changeColor:(id)sender
{
	if (![ignoreColorWell isActive] && ![secondIgnoreColorWell isActive])
		[super changeColor:sender];
}

@end
