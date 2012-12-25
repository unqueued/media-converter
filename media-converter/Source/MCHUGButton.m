//
//  MCHUGButton.m
//  Media Converter
//
//  Created by Maarten Foukhar on 05-08-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCHUGButton.h"
#import "MCHUGButtonCell.h"


@implementation MCHUGButton

- (id)initWithFrame:(NSRect)frameRect
{
	if (self == [super initWithFrame:frameRect])
	{
        MCHUGButtonCell *myCell;
        myCell = [[MCHUGButtonCell alloc] initImageCell:nil];
        [self setCell:myCell];
        [myCell release];
	}
	
    return self;
}

- (void)setImage:(NSImage *)image
{
    [[self cell] setImage:image];
    [self setNeedsDisplay];
}

+ (Class)cellClass
{
    return [MCHUGButtonCell class];
}

- (void)mouseDown:(NSEvent *)ev
{
    [self setState:NSOffState];
    [self setNeedsDisplay];
    [super mouseDown:ev];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    [self setState:NSOnState];
    [self setNeedsDisplay];
    [super mouseUp:theEvent];
}

- (void)drawRect:(NSRect)frame
{
    NSView *myView = [self superview];
    
	if (myView)
	{
        [[self cell] drawWithFrame:[self bounds] inView:myView];
    }
}

@end
