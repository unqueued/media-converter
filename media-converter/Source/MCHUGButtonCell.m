//
//  MCHUGButtonCell.m
//  Media Converter
//
//  Created by Maarten Foukhar on 05-08-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCHUGButtonCell.h"


@implementation MCHUGButtonCell

-(void)drawWithFrame:(NSRect)frame inView:(NSView *)controlView
{
	
	
	
	/*NSShadow *shadow = [[[NSShadow alloc] init] autorelease];
	[shadow setShadowOffset: NSMakeSize(0.0, -1.0)];
	[shadow setShadowColor:[NSColor blackColor]];
	[shadow setShadowBlurRadius:2.0];
	[shadow set];*/
	
	NSImage *buttonImage = [self buttonImageInFrame:frame];
	[buttonImage drawInRect:frame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	[self drawInteriorWithFrame:frame inView:controlView];

    // Drawing code here.
	/*NSBezierPath *path = [[[NSBezierPath alloc] init] autorelease];
	NSRect buttonRect = NSMakeRect(frame.origin.x + 1, frame.origin.y + 1, frame.size.width - 2, frame.size.height - 2);
	
	[path appendBezierPathWithRoundedRect:buttonRect xRadius:12 yRadius:12];

	if (backgroundButton == YES)
		[[NSColor colorWithDeviceRed:0.505882352941176 green:0.505882352941176 blue:0.505882352941176 alpha:1.0] set];
	else
		[[NSColor colorWithDeviceRed:0.741176470588235 green:0.741176470588235 blue:0.741176470588235 alpha:1.0] set];
	
	[path setLineWidth:2];
	[path stroke];
	
	[[NSColor blackColor] setFill];
	
	[path fill];*/

	/*if (backgroundButton == NO)
	{
		// Create gloss gradient
		float startAlpha = 0.2;
		if ([self isHighlighted])
			startAlpha = 0.3;
			
		NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:1.0 alpha:startAlpha] endingColor:[NSColor colorWithCalibratedWhite:1.0 alpha:startAlpha + 0.1]] autorelease];
		
		// Make a half-height rectangle
		buttonRect = NSMakeRect(buttonRect.origin.x, buttonRect.origin.y, buttonRect.size.width, buttonRect.size.height / 3);
		path = [NSBezierPath bezierPathWithRect:buttonRect];
		[gradient drawInBezierPath:path angle:-90];
	}
	
	NSImage *image = [self image];
	[image setFlipped: YES];
	
	if (image)
	{
		float fraction = 0.7;
		
		if ([self isHighlighted])
			fraction = 1.0;
		if (backgroundButton == YES)
			fraction = 0.5;
	
		float width = ((frame.size.height - 4) / [image size].height) * [image size].width;
		[image drawInRect:NSMakeRect(frame.origin.x + (frame.size.width - width) / 2, frame.origin.y + 2, width, frame.size.height - 4) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:fraction];
	}*/
}

- (NSImage *)buttonImageInFrame:(NSRect)frame
{
	NSImage *newImage = [[NSImage alloc] initWithSize:NSMakeSize(frame.size.width, frame.size.height)];
	
	[newImage lockFocus];

    // Drawing code here.
	NSBezierPath *path = [[[NSBezierPath alloc] init] autorelease];
	NSRect buttonRect = NSMakeRect(frame.origin.x + 1, frame.origin.y + 1, frame.size.width - 2, frame.size.height - 2);
	
	[path appendBezierPathWithRoundedRect:buttonRect xRadius:10 yRadius:10];

	//[[NSColor colorWithDeviceRed:0.505882352941176 green:0.505882352941176 blue:0.505882352941176 alpha:1.0] set];
	
	//0.219607843137255
	
	//[[NSColor colorWithDeviceRed:0 green:0 blue:0 alpha:0.4] set];
	
	//[path fill];
	
	// Create gloss gradient
	float startAlpha = 0.4;
		//if ([self isHighlighted])
		//startAlpha = 0.3;

	//	0.12156862745098
	//NSColor *startColor = [NSColor colorWithDeviceRed:0.341176470588235 green:0.341176470588235 blue:0.341176470588235 alpha:0.5];
	//NSColor *endColor = [NSColor colorWithDeviceRed:0.219607843137255 green:0.219607843137255 blue:0.219607843137255 alpha:0.3];
	
	NSColor *startColor = [NSColor colorWithDeviceRed:0 green:0 blue:0 alpha:0.0];
	NSColor *endColor = [NSColor colorWithDeviceRed:0.12156862745098 green:0.12156862745098 blue:0.12156862745098 alpha:0.5];
			
	NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:startColor endingColor:endColor] autorelease];
	
	
	//[path fill];
		
	// Make a half-height rectangle
	//buttonRect = NSMakeRect(buttonRect.origin.x, buttonRect.origin.y, buttonRect.size.width, buttonRect.size.height / 3);
	//path = [NSBezierPath bezierPathWithRect:buttonRect];
	[gradient drawInBezierPath:path angle:-90];
	
	[[NSColor whiteColor] set];
	
	[path setLineWidth:1.2];
	[path stroke];
	[[NSColor colorWithDeviceRed:0.341176470588235 green:0.341176470588235 blue:0.341176470588235 alpha:0.5] set];
	[path fill];
	
	[gradient drawInBezierPath:path angle:-90];
	
	[newImage unlockFocus];
	
	return [newImage autorelease];
}


- (void)drawInteriorWithFrame:(NSRect)rect inView:(NSView *)controlView
{
	NSFont *smallFont = [NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize: NSSmallControlSize]];
	NSMutableDictionary *attributes = [[NSDictionary dictionaryWithObjectsAndKeys:smallFont, NSFontAttributeName,[NSColor whiteColor] , NSForegroundColorAttributeName,nil] mutableCopy];
	NSMutableParagraphStyle *pStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		
	[pStyle setAlignment: [self alignment]];
	[attributes setValue: pStyle forKey: NSParagraphStyleAttributeName];
	[pStyle release];
	[attributes autorelease];
		
	NSAttributedString *attrString = [[[NSAttributedString alloc] initWithString: [self title] attributes: attributes] autorelease];


	[attrString drawInRect: [self titleRectForBounds: rect]];
}

@end
