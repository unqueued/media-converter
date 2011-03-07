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
}

- (void)setArray:(NSArray *)ar;
- (NSArray *)getArray;

@end
