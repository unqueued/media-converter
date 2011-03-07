//
//  MCAddDelegate.m
//  Media Converter
//
//  Created by Maarten Foukhar on 26-02-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCAddDelegate.h"
#import "ImageAndTextCell.h"


@implementation MCAddDelegate

- (id)init
{
	if (self = [super init])
		tableData = [[NSMutableArray alloc] init];

	return self;
}

- (void)dealloc
{
	//Release our stuff
	[tableData release];
	tableData = nil;

	[super dealloc];
}

- (void)awakeFromNib
{
	//Tableview
	NSTableColumn *tableColumn = nil;
	ImageAndTextCell *imageAndTextCell = nil;

	// Insert custom cell types into the table view, the standard one does text only.
	// We want one column to have text and images
	tableColumn = [tableView tableColumnWithIdentifier:@"Main"];
	imageAndTextCell = [[[ImageAndTextCell alloc] init] autorelease];
	[imageAndTextCell setEditable:YES];
	[tableColumn setDataCell:imageAndTextCell];
}

//////////////////////
// Tableview actions //
///////////////////////

#pragma mark -
#pragma mark •• Tableview actions

//Count the number of rows, not really needed anywhere
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return 2;
}

//return selected row
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	/*if (row == 0)
		return NSLocalizedString(@"Open an existing preset file\nChoose a downloaded or copied preset file", nil);
	else
		return NSLocalizedString(@"Create a new preset\nChoose a downloaded or copied preset file", nil);*/
		
	NSString *optionText;
	NSString *explainText;
	
	if (row == 0)
	{
		optionText = NSLocalizedString(@"Open an existing preset file", nil);
		explainText = NSLocalizedString(@"Choose a downloaded or copied preset file", nil);
	}
	else
	{
		optionText = NSLocalizedString(@"Create a new preset", nil);
		explainText = NSLocalizedString(@"This option is only for advanced users", nil);
	}
	
	NSMutableAttributedString *testStr = [[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n%@", optionText, explainText]] autorelease];

	NSColor *txtColor;
	
	if (row == [tableView selectedRow] && [[tableView window] isKeyWindow])
		txtColor = [NSColor	whiteColor];
	else
		txtColor = [NSColor blackColor];
		
	NSFont *txtFont = [NSFont boldSystemFontOfSize:13];
	NSDictionary *txtDict = [NSDictionary dictionaryWithObjectsAndKeys:txtFont, NSFontAttributeName, txtColor, NSForegroundColorAttributeName, nil];
	
	NSDictionary *txtDict2 = [NSDictionary dictionaryWithObjectsAndKeys:txtColor, NSForegroundColorAttributeName, nil];
	
	[testStr setAttributes:txtDict range:NSMakeRange(0, [optionText length])];
	[testStr setAttributes:txtDict2 range:NSMakeRange([optionText length], [explainText length] + 1)];

	//[cell setAttributedStringValue:attrStr]
	
	return testStr;
	//[cell setAttributedStringValue:string];
}

//We don't want to make people change our row values
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return YES;
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	if (row == 0)
		[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"Add Preset"]];
	else
		[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"Create Preset"]];
}

@end
