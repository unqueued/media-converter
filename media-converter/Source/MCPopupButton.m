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
	{
		startIndex = 0;
		delayed = NO;
		delayedObject = nil;
	}
		
	return self;
}

- (void)dealloc
{
	if (array)
		[array release];
	
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

- (id)objectValue
{		
	return [array objectAtIndex:[self indexOfSelectedItem]];
}

- (void)setObjectValue:(id)obj
{
	if (delayed == YES)
	{
		delayedObject = obj;
	}
	else
	{
		if (obj == nil | [array indexOfObject:obj] == NSNotFound)
			[self selectItemAtIndex:0];
		else
			[self selectItemAtIndex:[array indexOfObject:obj]];
	}
}

- (NSInteger)indexOfObjectValue:(id)obj
{
	return [array indexOfObject:obj];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	[super controlTextDidChange:aNotification];
}

- (void)setDelayed:(BOOL)del
{
	delayed = del;
	
	if (del == NO && delayedObject != nil)
		[self setObjectValue:delayedObject];
}

@end
