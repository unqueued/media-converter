//
//  NSArray_Extensions.m
//  Media Converter
//
//  Created by Maarten Foukhar on 22-02-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "NSArray_Extensions.h"


@implementation NSArray (MyExtensions)

- (id)objectForKey:(id)aKey
{
	NSInteger i;
	for (i = 0; i < [self count]; i ++)
	{
		NSDictionary *currentDict = [self objectAtIndex:i];
		NSString *currentKey = [[currentDict allKeys] objectAtIndex:0];
		
		if ([currentKey isEqualTo:aKey])
			return [currentDict objectForKey:currentKey];
	}
	
	return nil;
}

- (id)objectsForKey:(id)aKey
{
	NSInteger i;
	NSMutableArray *objects = [NSMutableArray array];
	for (i = 0; i < [self count]; i ++)
	{
		NSDictionary *currentDict = [self objectAtIndex:i];
		NSArray *allKeys = [currentDict allKeys];
		
		NSInteger x;
		for (x = 0; x < [allKeys count]; x ++)
		{
			NSString *currentKey = [[currentDict allKeys] objectAtIndex:x];

			if ([currentKey isEqualTo:aKey])
				[objects addObject:[currentDict objectForKey:currentKey]];
		}
	}
	
	return objects;
}

- (NSInteger)indexOfObject:(id)aObject forKey:(id)aKey
{
	NSInteger i;
	for (i = 0; i < [self count]; i ++)
	{
		NSDictionary *currentDict = [self objectAtIndex:i];
		id object = [currentDict objectForKey:aKey];
		
		if (object && [object isEqualTo:aObject])
			return i;
	}
	
	return NSNotFound;
}

@end

@implementation NSMutableArray (MyExtensions)

- (void)setObject:(id)anObject forKey:(id)aKey
{
	NSInteger i;
	for (i = 0; i < [self count]; i ++)
	{
		NSDictionary *currentDict = [self objectAtIndex:i];
		NSString *currentKey = [[currentDict allKeys] objectAtIndex:0];
		
		if ([currentKey isEqualTo:aKey])
		{
			if (!anObject)
			{
				[self removeObjectAtIndex:i];
			}
			else
			{
				NSDictionary *newDict = [NSDictionary dictionaryWithObject:anObject forKey:aKey];
				[self replaceObjectAtIndex:i withObject:newDict];
			}
			
			return;
		}
	}
	
	if (anObject)
	{
		NSDictionary *newDict = [NSDictionary dictionaryWithObject:anObject forKey:aKey];
		[self addObject:newDict];
	}
}

@end
