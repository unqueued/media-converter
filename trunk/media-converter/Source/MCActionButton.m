//
//  MCActionButton.m
//  Media Converter
//
//  Created by Maarten Foukhar on 27-07-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCActionButton.h"


@implementation MCActionButton

- (id)initWithCoder:(NSCoder *)decoder
{
	[super initWithCoder:decoder];

	NSRect buttonFrame = [self frame];
	NSRect newFrame = NSMakeRect(buttonFrame.origin.x - 3, buttonFrame.origin.y - (buttonFrame.size.height - 23) , buttonFrame.size.width, buttonFrame.size.height);
	menuPopup = [[NSPopUpButton alloc] initWithFrame:newFrame pullsDown:YES];
	[menuPopup addItemWithTitle:@""];
	[menuPopup setHidden:YES];
	
	return self;
}

- (void)awakeFromNib
{
	[[self superview] addSubview:menuPopup];
}

- (void)setDelegate:(id)del
{
	delegate = del;
}

- (void)addMenuWithTitle:(NSString *)title withSelector:(SEL)sel
{
	[menuPopup addItemWithTitle:title];
	NSMenuItem *editMenuItem = [menuPopup lastItem];
	[editMenuItem setAction:sel];
	[editMenuItem setTarget:delegate];
}

- (void)setTitle:(NSString *)title atIndex:(NSInteger)index
{
	NSArray *menuItems = [menuPopup itemArray];
	NSMenuItem *menuItem = [menuItems objectAtIndex:index + 1];
	[menuItem setTitle:title];
}

- (BOOL)sendAction:(SEL)theAction to:(id)theTarget
{
	[menuPopup performClick:theTarget];

	return YES;
}

@end
