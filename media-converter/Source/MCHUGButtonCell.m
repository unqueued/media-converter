//
//  MCHUGButtonCell.m
//  Media Converter
//
//  Created by Maarten Foukhar on 05-08-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCHUGButtonCell.h"


@implementation MCHUGButtonCell

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if ([super initWithCoder:aDecoder])
		[self setButtonType:NSMomentaryPushInButton];
		
    return self;
}

-(void)drawWithFrame:(NSRect)frame inView:(NSView *)controlView
{
	NSImage *newImage = [[NSImage alloc] initWithSize:NSMakeSize(frame.size.width, frame.size.height)];
	
	[newImage lockFocus];
	
	NSBezierPath *path = [[[NSBezierPath alloc] init] autorelease];
	NSRect buttonRect = NSMakeRect(frame.origin.x + 1, (frame.size.height - 18) / 2, frame.size.width - 2, 18);
	
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	[path appendBezierPathWithRoundedRect:buttonRect xRadius:10 yRadius:10];
	#else
	[path appendBezierPathWithRect:buttonRect];
	#endif
	
	[[NSColor whiteColor] set];
	
	[path setLineWidth:1.2];
	[path stroke];
	[[NSColor colorWithDeviceRed:0.341176470588235 green:0.341176470588235 blue:0.341176470588235 alpha:0.5] set];
	[path fill];
	
	if ([self state] == NSOnState)
	{
		// NSGradients are supported from 10.5 and up
		#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
		NSColor *startColor = [NSColor colorWithDeviceRed:0 green:0 blue:0 alpha:0.0];
		NSColor *endColor = [NSColor colorWithDeviceRed:0.12156862745098 green:0.12156862745098 blue:0.12156862745098 alpha:0.5];
		
		NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:startColor endingColor:endColor] autorelease];
	
		[gradient drawInBezierPath:path angle:-90];
		#endif
	}
	else
	{
		[[NSColor colorWithDeviceRed:0.8 green:0.8 blue:0.8 alpha:0.5] set];
		[path fill];
	}
	
	[newImage unlockFocus];
	
	[newImage drawInRect:frame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	[self drawInteriorWithFrame:frame inView:controlView];
}

- (void)drawInteriorWithFrame:(NSRect)rect inView:(NSView *)controlView
{
	NSFont *smallFont = [NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize: NSSmallControlSize]];
	NSMutableDictionary *attributes = [[NSDictionary dictionaryWithObjectsAndKeys:smallFont, NSFontAttributeName,[NSColor whiteColor], NSForegroundColorAttributeName, nil] mutableCopy];
	NSMutableParagraphStyle *pStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		
	[pStyle setAlignment:[self alignment]];
	[attributes setValue:pStyle forKey:NSParagraphStyleAttributeName];
	[pStyle release];
	[attributes autorelease];
		
	NSAttributedString *attrString = [[[NSAttributedString alloc] initWithString:[self title] attributes:attributes] autorelease];

	[attrString drawInRect:[self titleRectForBounds:rect]];
}

@end
