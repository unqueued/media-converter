//
//  MCCheckBox.m
//  Media Converter
//
//  Created by Maarten Foukhar on 15-02-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCCheckBoxCell.h"


@implementation MCCheckBoxCell

- (void)setStateWithoutSelecting:(NSInteger)value
{
	[super setState:value];
}

- (void)setState:(NSInteger)value
{
	[super setState:value];
	
	BOOL enabled = ([self state] == NSOnState);
	
	if (dependChild)
	{
		if (!enabled)
		{
			[[dependChild cell] setObjectValue:nil];
			[dependChild performClick:self];
		}
	
		[dependChild setEnabled:enabled];
		
		if (enabled)
		{
			[dependChild performClick:self];
			[[dependChild window] makeFirstResponder:dependChild];
		}
	}
}

- (id)dependChild
{
	return dependChild;
}

@end
