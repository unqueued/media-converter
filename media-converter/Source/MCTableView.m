//
//  MCTableView.m
//  Media Converter
//
//  Created by Maarten Foukhar on 05-03-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCTableView.h"


@implementation MCTableView

- (BOOL)becomeFirstResponder 
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MCListSelected" object:self];

	return [super becomeFirstResponder];
}

@end
