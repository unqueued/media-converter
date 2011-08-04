//
//  MCWatermarkFilter.m
//  Media Converter
//
//  Created by Maarten Foukhar on 04-07-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCWatermarkFilter.h"
#import "MCCommonMethods.h"
#import "NSControl_Extensions.h"


@implementation MCWatermarkFilter

- (id)init
{
	if (self = [super init])
	{
		filterMappings = [[NSArray alloc] initWithObjects:		//Watermark
																@"Horizontal Alignment",				//1
																@"Vertical Alignment",					//2
																@"Left Margin",							//3
																@"Right Margin",						//4
																@"Top Margin",							//5
																@"Bottom Margin",						//6
																@"Width",								//7
																@"Height",								//8
																@"Keep Aspect",							//9
		nil];
		
		filterDefaultValues = [[NSArray alloc] initWithObjects:	//Watermark
																	@"right",										// Horizontal Alignment
																	@"top",											// Vertical Alignment
																	[NSNumber numberWithInteger:10],				// Left Margin
																	[NSNumber numberWithInteger:10],				// Right Margin
																	[NSNumber numberWithInteger:10],				// Top Margin
																	[NSNumber numberWithInteger:10],				// Bottom Margin
																	[NSNumber numberWithInteger:0],					// Width
																	[NSNumber numberWithInteger:0],					// Height
																	[NSNumber numberWithBool:YES],					// Keep Aspect
		nil];
		
		filterOptions = [[NSMutableDictionary alloc] initWithObjects:filterDefaultValues forKeys:filterMappings];
			
		[NSBundle loadNibNamed:@"MCWatermarkFilter" owner:self];
	}

	return self;
}

- (void)awakeFromNib
{
	[watermarkHorizontalPopup setArray:[MCCommonMethods defaultHorizontalPopupArray]];
	[watermarkVerticalPopup setArray:[MCCommonMethods defaultVerticalPopupArray]];
}

+ (NSString *)localizedName
{
	return NSLocalizedString(@"Watermark", nil);
}

- (void)resetView
{
	[watermarkImage setImage:nil];
	[watermarkImageName setStringValue:NSLocalizedString(@"No image selected", nil)];
	
	[super resetView];
}

- (IBAction)chooseWatermarkImage:(id)sender
{
	NSOpenPanel *sheet = [NSOpenPanel openPanel];
	[sheet setCanChooseFiles:YES];
	[sheet setCanChooseDirectories:NO];
	[sheet setAllowsMultipleSelection:NO];
	
	NSInteger result = [sheet runModalForDirectory:nil file:nil types:[NSArray arrayWithObject:@"png"]];
	
	if (result == NSOKButton)
	{
		NSString *filePath = [sheet filename];
		//[watermarkImageIcon setHidden:NO];
		//[watermarkImageIcon setImage:[[NSWorkspace sharedWorkspace] iconForFile:filePath]];
		[watermarkImageName setStringValue:[[MCCommonMethods defaultManager] displayNameAtPath:filePath]];
		NSImage *image = [[[NSImage alloc] initWithContentsOfFile:filePath] autorelease];
		[watermarkImage setImage:image];
		NSSize imageSize = [image size];
		aspectRatio = imageSize.width / imageSize.height;

		[watermarkWidthField setObjectValue:[NSNumber numberWithCGFloat:imageSize.width]];
		[watermarkHeightField setObjectValue:[NSNumber numberWithCGFloat:imageSize.height]];
		
		[filterOptions setObject:[NSNumber numberWithCGFloat:imageSize.width] forKey:@"Width"];
		[filterOptions setObject:[NSNumber numberWithCGFloat:imageSize.height] forKey:@"Height"];
		
		[filterOptions setObject:[NSData dataWithContentsOfFile:filePath] forKey:@"Overlay Image"];
		[filterOptions setObject:[[MCCommonMethods defaultManager] displayNameAtPath:filePath] forKey:@"Identifyer"];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MCUpdatePreview" object:self];
	}
}

- (NSString *)identifyer
{
	if ([[filterOptions allKeys] containsObject:@"Identifyer"])
		return [[MCCommonMethods defaultManager] displayNameAtPath:[filterOptions objectForKey:@"Identifyer"]];
	else
		return NSLocalizedString(@"No Image", nil);
}

- (void)setupView
{
	NSData *imageData = [filterOptions objectForKey:@"Overlay Image"];
	
	if (imageData != nil)
	{
		NSImage *image = [[[NSImage alloc] initWithData:imageData] autorelease];
		[watermarkImage setImage:image];
		[watermarkImageName setStringValue:[filterOptions objectForKey:@"Identifyer"]];
		NSSize imageSize = [image size];
		aspectRatio = imageSize.width / imageSize.height;
	}
	
	[super setupView];
}

- (IBAction)setFilterOption:(id)sender
{
	if (([sender isEqualTo:watermarkWidthField] | [sender isEqualTo:watermarkHeightField]) && [watermarkAspectCheckBox state] == NSOnState)
	{
		CGFloat width = [watermarkWidthField cgfloatValue];
		CGFloat height = [watermarkHeightField cgfloatValue];

		if ([sender isEqualTo:watermarkWidthField])
		{
			[watermarkHeightField setObjectValue:[NSNumber numberWithCGFloat:(width / aspectRatio)]];
		}
		else
		{
			[watermarkWidthField setObjectValue:[NSNumber numberWithCGFloat:(height * aspectRatio)]];
		}
		
		[super setFilterOption:watermarkWidthField];
		[super setFilterOption:watermarkHeightField];
	}
	else if ([sender isEqualTo:watermarkAspectCheckBox])
	{
		if ([watermarkAspectCheckBox state] == NSOnState)
			[self setFilterOption:watermarkWidthField];
			
		[super setFilterOption:sender];
	}
	else
	{
		[super setFilterOption:sender];
	}
}

- (NSImage *)imageWithSize:(NSSize)size
{
	//NSAttributedString *attrString = [[[NSAttributedString alloc] initWithAttributedString:[textView textStorage]] autorelease];
	NSImage *emptyImage = [[[NSImage alloc] initWithSize:size] autorelease];
	NSData *imageData = [filterOptions objectForKey:@"Overlay Image"];
	NSImage *image = [[[NSImage alloc] initWithData:imageData] autorelease];

	return [MCCommonMethods overlayImageWithObject:image withSettings:filterOptions inputImage:emptyImage];
}

@end
