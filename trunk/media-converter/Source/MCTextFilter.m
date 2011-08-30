//
//  MCTextFilter.m
//  Media Converter
//
//  Created by Maarten Foukhar on 04-07-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCTextFilter.h"
#import "MCCommonMethods.h"
#import "NSControl_Extensions.h"
#import "MCPopupButton.h"


@implementation MCTextFilter

- (id)init
{
	if (self = [super init])
	{
		filterMappings = [[NSArray alloc] initWithObjects:		//Text
																@"Horizontal Alignment",				//1
																@"Vertical Alignment",					//2
																@"Left Margin",							//3
																@"Right Margin",						//4
																@"Top Margin",							//5
																@"Bottom Margin",						//6
																@"Method",								//7
																@"Border Color",						//8
																@"Border Size",							//9
																@"Box Color",							//10
																@"Box Marge",							//11
																@"Box Alpha Value",						//12
																@"Alpha Value",							//13
		nil];
		
		filterDefaultValues = [[NSArray alloc] initWithObjects:		//Text
																	@"left",															// Horizontal Alignment
																	@"top",																// Vertical Alignment
																	[NSNumber numberWithInteger:30],									// Left Margin
																	[NSNumber numberWithInteger:30],									// Right Margin
																	[NSNumber numberWithInteger:30],									// Top Margin
																	[NSNumber numberWithInteger:0],										// Bottom Margin
																	@"border",															// Subtitle Method
																	[NSArchiver archivedDataWithRootObject:[NSColor blackColor]],		// Subtitle Border Color
																	[NSNumber numberWithInteger:4],										// Subtitle Border Size
																	[NSArchiver archivedDataWithRootObject:[NSColor darkGrayColor]],	// Subtitle Box Color
																	[NSNumber numberWithInteger:10],									// Subtitle Box Marge
																	[NSNumber numberWithDouble:0.50],									// Subtitle Box Alpha Value
																	[NSNumber numberWithDouble:1.00],									// Alpha Value
		nil];
		
		filterOptions = [[NSMutableDictionary alloc] initWithObjects:filterDefaultValues forKeys:filterMappings];
			
		[NSBundle loadNibNamed:@"MCTextFilter" owner:self];
	}

	return self;
}

- (void)awakeFromNib
{
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	[defaultCenter addObserver:self selector:@selector(textChanged) name:@"NSTextDidChangeNotification" object:textView];

	[textHorizontalPopup setArray:[MCCommonMethods defaultHorizontalPopupArray]];
	[textVerticalPopup setArray:[MCCommonMethods defaultVerticalPopupArray]];
	
	NSMutableArray *textVisibilities = [NSMutableArray array];
	[textVisibilities insertObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Text Border", nil), @"Name", @"border", @"Format", nil] atIndex:0];
	[textVisibilities insertObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Surounding Box", nil), @"Name", @"box", @"Format", nil] atIndex:1];
	[textVisibilities insertObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"None", nil), @"Name", @"none", @"Format", nil] atIndex:2];
	[textVisiblePopup setArray:textVisibilities];
}

+ (NSString *)localizedName
{
	return NSLocalizedString(@"Text", nil);
}

- (void)resetView
{
	[textView setString:@""];
	
	[super resetView];
}

- (void)setupView
{
	NSData *textData = [filterOptions objectForKey:@"Text"];
	
	if (textData != nil)
	{
		NSAttributedString *attrString = [NSUnarchiver unarchiveObjectWithData:textData];
		[textView insertText:attrString];
	}
	
	[super setupView];
}

- (void)textChanged
{
	NSAttributedString *attrString = [[[NSAttributedString alloc] initWithAttributedString:[textView textStorage]] autorelease];
	[filterOptions setObject:[NSArchiver archivedDataWithRootObject:attrString] forKey:@"Text"];
	
	NSString *identString = [attrString string];
	
	if ([identString length] > 60)
		identString = [[identString substringWithRange:NSMakeRange(0, 60)] stringByAppendingString:@"…"];
		
	[filterOptions setObject:identString forKey:@"Identifyer"];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MCUpdatePreview" object:nil];
}

- (NSString *)identifyer
{
	if ([[filterOptions allKeys] containsObject:@"Identifyer"])
		return [filterOptions objectForKey:@"Identifyer"];
	else
		return NSLocalizedString(@"No Text", nil);
}

- (IBAction)setTextVisibility:(id)sender
{
	NSInteger selectedIndex = [(MCPopupButton *)textVisiblePopup indexOfSelectedItem];
	
	//Seems when editing a preset from the main window, we have to try until we're woken from the NIB
	while (selectedIndex == -1)
		selectedIndex = [(MCPopupButton *)textVisiblePopup indexOfSelectedItem];
	
	if (selectedIndex < 2)
		[textMethodTabView selectTabViewItemAtIndex:selectedIndex];
		
	[textMethodTabView setHidden:(selectedIndex == 2)];

	if (sender != nil)
		[self setFilterOption:sender];
}

- (NSImage *)imageWithSize:(NSSize)size
{
	NSImage *emptyImage = [[[NSImage alloc] initWithSize:size] autorelease];
	
	NSData *textData = [filterOptions objectForKey:@"Text"];
	NSAttributedString *attrString = [NSUnarchiver unarchiveObjectWithData:textData];

	return [MCCommonMethods overlayImageWithObject:attrString withSettings:filterOptions inputImage:emptyImage];
}

@end