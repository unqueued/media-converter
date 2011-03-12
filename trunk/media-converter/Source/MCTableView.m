//
//  MCTableView.m
//  Media Converter
//
//  Created by Maarten Foukhar on 05-03-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCTableView.h"
#import "MCPreferences.h"


@implementation MCTableView

- (BOOL)becomeFirstResponder 
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MCListSelected" object:self];

	return [super becomeFirstResponder];
}

- (void)duplicate:(id)sender
{
	[(MCPreferences *)[self delegate] duplicate:sender];
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
	if (aSelector == @selector(duplicate:))
	{
		NSInteger selRow = [self selectedRow];

		if (selRow == -1)
			return NO;
	}
	
	return [super respondsToSelector:aSelector];
}

@end
