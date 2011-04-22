//
//  MCPopupButton.m
//  Media Converter
//
//  Created by Maarten Foukhar on 15-02-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCPopupButton.h"


@implementation MCPopupButton

- (id)init
{
	if ([super init])
		startIndex = 0;
		
	return self;
}

- (void)dealloc
{
	if (array)
	{
		[array release];
		array = nil;
	}
	
	[super dealloc];
}

- (void)setArray:(NSArray *)ar
{
	if (!array)
		array = [[NSMutableArray alloc] init];
	else
		[array removeAllObjects];
	
	[self removeAllItems];
	
	//Get the containers from ffmpeg
	NSInteger i;
	for (i = 0; i < [ar count]; i ++)
	{
		NSDictionary *itemDictionary = [ar objectAtIndex:i];
	
		id name = [itemDictionary objectForKey:@"Name"];
		
		if ([name isEqualTo:@""])
		{
			[[self menu] addItem:[NSMenuItem separatorItem]];
		}
		else
		{
			if ([name isKindOfClass:[NSAttributedString class]])
			{
				[self addItemWithTitle:[(NSAttributedString *)name string]];
				[[self lastItem] setAttributedTitle:(NSAttributedString *)name];
			}
			else
			{
				if ([self indexOfItemWithTitle:(NSString *)name] > -1)
					name = [NSString stringWithFormat:@"%@ (2)", (NSString *)name];
		
				[self addItemWithTitle:(NSString *)name];
			}
		}
		
		NSString *rawName = [itemDictionary objectForKey:@"Format"];

		[array addObject:rawName];
	}
}

- (NSArray *)getArray
{
	return array;
}

@end
