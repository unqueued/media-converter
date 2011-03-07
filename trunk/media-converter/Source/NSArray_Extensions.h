//
//  NSArray_Extensions.h
//  Media Converter
//
//  Created by Maarten Foukhar on 22-02-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MCCommonMethods.h"


@interface NSArray (MyExtensions)
- (id)objectForKey:(id)aKey;
- (id)objectsForKey:(id)aKey;
- (NSInteger)indexOfObject:(id)aObject forKey:(id)aKey;
@end

@interface NSMutableArray (MyExtensions)
- (void)setObject:(id)anObject forKey:(id)aKey;
@end
