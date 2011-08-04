//
//  MCColorWell.m
//  Media Converter
//
//  Created by Maarten Foukhar on 21-06-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCColorWell.h"


@implementation MCColorWell

- (id)objectValue
{
	return [NSArchiver archivedDataWithRootObject:[self color]];
}

- (void)setObjectValue:(id)obj
{
	[self setColor:[NSUnarchiver unarchiveObjectWithData:obj]];
}

@end
