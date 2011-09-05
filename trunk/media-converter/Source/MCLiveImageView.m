//
//  MCLiveImageView.m
//  Media Converter
//
//  Created by Maarten Foukhar on 04-09-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCLiveImageView.h"
#import "MCCommonMethods.h"


@implementation MCLiveImageView

- (void)drawRect:(NSRect)dirtyRect
{
	if (![self inLiveResize])
	{
		[super drawRect:dirtyRect];
	}
	else
	{
		NSMutableParagraphStyle *centeredStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
		[centeredStyle setAlignment:NSCenterTextAlignment];
		NSDictionary *attsDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:0], NSFontAttributeName, centeredStyle, NSParagraphStyleAttributeName, [NSColor whiteColor], NSForegroundColorAttributeName, [NSNumber numberWithInteger:NSNoUnderlineStyle], NSUnderlineStyleAttributeName, nil];
		NSRect myFrame = [self frame];
		NSAttributedString *attrStr = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"Resizing... (%ix%i)", nil), (NSInteger)myFrame.size.width, (NSInteger)myFrame.size.height] attributes:attsDict] autorelease];
		NSRect frame = [MCCommonMethods frameForStringDrawing:attrStr forWidth:dirtyRect.size.width];
		[attrStr drawInRect:NSMakeRect(0, (dirtyRect.size.height - frame.size.height) / 2, dirtyRect.size.width, frame.size.height)];
	}
}

- (void)viewDidEndLiveResize
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MCUpdatePreview" object:nil];
}

@end
