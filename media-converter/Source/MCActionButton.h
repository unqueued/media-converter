//
//  MCActionButton.h
//  Media Converter
//
//  Created by Maarten Foukhar on 27-07-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MCCommonMethods.h"


@interface MCActionButton : NSButton
{
	NSPopUpButton *menuPopup;
	id delegate;
}

- (void)setDelegate:(id)del;
- (void)addMenuWithTitle:(NSString *)title withSelector:(SEL)sel;
- (void)setTitle:(NSString *)title atIndex:(NSInteger)index;

@end
