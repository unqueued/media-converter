//
//  MCPopupButton.h
//  Media Converter
//
//  Created by Maarten Foukhar on 15-02-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MCCommonMethods.h"

@interface MCPopupButton : NSPopUpButton
{
	NSMutableArray *array;
	NSInteger startIndex;
	BOOL delayed;
	id delayedObject;
}

- (void)setArray:(NSArray *)ar;
- (id)objectValue;
- (void)setObjectValue:(id)obj;
- (NSInteger)indexOfObjectValue:(id)obj;
- (void)setDelayed:(BOOL)del;

@end
