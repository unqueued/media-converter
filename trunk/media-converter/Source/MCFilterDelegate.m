//
//  MCFilterDelegate.m
//  Media Converter
//
//  Created by Maarten Foukhar on 25-06-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCFilterDelegate.h"
#import "MCCommonMethods.h"
#import "MCPopupButton.h"
#import "NSNumber_Extensions.h"
#import "NSArray_Extensions.h"
#import "MCActionButton.h"

#import "MCWatermarkFilter.h"
#import "MCTextFilter.h"
#import "MCTableView.h"


@implementation MCFilterDelegate

- (id)init
{
	if (self = [super init])
	{
		tableData = [[NSMutableArray alloc] init];
		filters = [[NSMutableArray alloc] init];
	}

	return self;
}

- (void)dealloc
{
	//Release our stuff
	[tableData release];
	tableData = nil;
	[filters release];
	filters = nil;

	[super dealloc];
}

- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tableViewSelectionDidChange:) name:@"MCListSelected" object:tableView];

	//Setup filters and popup
	NSMutableArray *filterItems = [NSMutableArray array];
	
	MCFilter *watermarkFilter = [[MCWatermarkFilter alloc] init];
	[filters addObject:watermarkFilter];
	[filterItems insertObject:[NSDictionary dictionaryWithObjectsAndKeys:[MCWatermarkFilter localizedName], @"Name", [watermarkFilter name], @"Format", nil] atIndex:0];
	
	MCFilter *textFilter = [[MCTextFilter alloc] init];
	[filters addObject:textFilter];
	[filterItems insertObject:[NSDictionary dictionaryWithObjectsAndKeys:[MCTextFilter localizedName], @"Name", [textFilter name], @"Format", nil] atIndex:1];
	
	[filterPopup setArray:filterItems];
	
	[actionButton setDelegate:tableView];
	[actionButton addMenuWithTitle:NSLocalizedString(@"Edit Filter…", nil) withSelector:@selector(edit:)];
	[actionButton addMenuWithTitle:NSLocalizedString(@"Duplicate Filter", nil) withSelector:@selector(duplicate:)];
	
	[tableView setTarget:self];
	[tableView setDoubleAction:@selector(edit:)];
	[tableView setReloadNotificationName:@"MCUpdatePreview"];
}

- (IBAction)addFilter:(id)sender
{	
	[self selectFilter:nil];
	
	[filterCloseButton setTitle:NSLocalizedString(@"Add", nil)];

	[NSApp beginSheet:filterWindow modalForWindow:modalWindow modalDelegate:self didEndSelector:@selector(filterSheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)filterSheetDidEnd:(NSWindow*)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[panel orderOut:nil];

	if (returnCode == NSOKButton)
	{
		MCFilter *currentFilter = [filters objectAtIndex:[filterPopup indexOfSelectedItem]];
		NSDictionary *filter = [NSDictionary dictionaryWithObjectsAndKeys:[currentFilter name], @"Type", [currentFilter filterOptions], @"Options", [currentFilter identifyer], @"Identifyer", nil];

		[tableData addObject:filter];
		[tableView reloadData];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MCUpdatePreview" object:nil];
}

- (IBAction)add:(id)sender
{
	[NSApp endSheet:filterWindow returnCode:NSOKButton];
}

- (IBAction)cancel:(id)sender
{
	[NSApp endSheet:filterWindow returnCode:NSCancelButton];
}

- (IBAction)delete:(id)sender
{
	
	NSArray *removeObjects = [self allSelectedItemsInTableView:tableView fromArray:tableData];

	[tableData removeObjectsInArray:removeObjects];
	[tableView reloadData];
}

- (IBAction)duplicate:(id)sender
{
	NSInteger selRow = [tableView selectedRow];
	
	if (selRow > -1)
	{
		NSArray *selectedObjects = [MCCommonMethods allSelectedItemsInTableView:tableView fromArray:tableData];
		[tableView deselectAll:nil];
		
		NSInteger i;
		for (i = 0; i < [selectedObjects count]; i ++)
		{
			NSDictionary *selectedObject = [selectedObjects objectAtIndex:i];

			NSMutableDictionary *filterDictionary = [NSMutableDictionary dictionaryWithDictionary:selectedObject];
			
			NSString *oldIdentifyer = [filterDictionary objectForKey:@"Identifyer"];
			NSString *newIdentifyer = [NSString stringWithFormat:NSLocalizedString(@"%@ copy", nil), oldIdentifyer];
			[filterDictionary setObject:newIdentifyer forKey:@"Identifyer"];
			
			NSInteger uniqueInt = 2;
			while ([tableData containsObject:filterDictionary])
			{
				[filterDictionary setObject:[NSString stringWithFormat:@"%@ %i", newIdentifyer, uniqueInt] forKey:@"Identifyer"];
				uniqueInt = uniqueInt + 1;
			}
			
			[tableData addObject:filterDictionary];
		}
		
		[tableView reloadData];
	}
}

- (IBAction)edit:(id)sender
{
	NSInteger selectedRow = [tableView selectedRow];
	
	if (selectedRow > - 1)
	{
		NSDictionary *filterOptions = [tableData objectAtIndex:selectedRow];
		NSString *type = [filterOptions objectForKey:@"Type"];
	
		openFilter = filterOptions;
	
		[filterPopup setObjectValue:type];
		[self selectFilter:nil];
	
		MCFilter *filter = [filters objectAtIndex:[filterPopup indexOfSelectedItem]];
		[filter setOptions:[filterOptions objectForKey:@"Options"]];
		[filter setupView];
	
		[filterCloseButton setTitle:NSLocalizedString(@"Save", nil)];
	
		[NSApp beginSheet:filterWindow modalForWindow:modalWindow modalDelegate:self didEndSelector:@selector(filterEditSheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
}

- (void)filterEditSheetDidEnd:(NSWindow*)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[panel makeFirstResponder:nil];
	[panel orderOut:nil];

	if (returnCode == NSOKButton)
	{
		MCFilter *currentFilter = [filters objectAtIndex:[filterPopup indexOfSelectedItem]];

		NSDictionary *filter = [NSDictionary dictionaryWithObjectsAndKeys:[currentFilter name], @"Type", [currentFilter filterOptions], @"Options", [currentFilter identifyer], @"Identifyer", nil];
		[tableData replaceObjectAtIndex:[tableView selectedRow] withObject:filter];
		[tableView reloadData];
	}
	
	openFilter = nil;
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MCUpdatePreview" object:nil];
}

- (IBAction)selectFilter:(id)sender
{
	NSInteger i;
	for (i = 0; i < [filters count]; i ++)
	{
		NSView *currentView = [[filters objectAtIndex:i] filterView];
		
		if ([[[filterWindow contentView] subviews] containsObject:currentView])
			[currentView removeFromSuperview];
	}
	
	MCFilter *filter = [filters objectAtIndex:[filterPopup indexOfSelectedItem]];
	[filter resetView];
	[filter setupView];
	NSView *newView = [filter filterView];

	NSRect filterViewFrame = [newView frame];
	NSRect windowFrame = [filterWindow frame];
	
	CGFloat newWidth = filterViewFrame.size.width;
	CGFloat newHeight = filterViewFrame.size.height + 112;
	
	//Took me a while to figure out a height problem (when this call is done before the sheet opens the window misses a title bar)
	if (![filterWindow isSheet])
		newHeight += 22;
	
	CGFloat newY = windowFrame.origin.y - (newHeight - windowFrame.size.height);
	
	[filterWindow setFrame:NSMakeRect(windowFrame.origin.x, newY, newWidth, newHeight) display:YES animate:(sender != nil)];
	[newView setFrame:NSMakeRect(0, 60, filterViewFrame.size.width, filterViewFrame.size.height)];
	
	[[filterWindow contentView] addSubview:newView];
	
}

- (void)setFilterOptions:(id)options
{
	if (tableData)
	{
		[tableData release];
		tableData = nil;
	}

	tableData = [options retain];
	[tableView reloadData];
}

- (id)filterOptions
{
	return tableData;
}

- (IBAction)showPreview:(id)sender
{
	if ([previewPanel isVisible])
		[previewPanel orderOut:nil];
	else
		[previewPanel orderFront:nil];
}

- (void)updatePreview
{
	NSImage *newPreviewImage = [[[NSImage imageNamed:@"Sintel-frame"] copy] autorelease];

	NSInteger i;
	for (i = 0; i < [tableData count]; i ++)
	{
		NSDictionary *filterOptions = [tableData objectAtIndex:i];
		NSString *type = [filterOptions objectForKey:@"Type"];
		
		MCFilter *filter;
		if (filterOptions != openFilter)
		{
			filter = [[NSClassFromString(type) alloc] init];
				
			[filter setOptions:[filterOptions objectForKey:@"Options"]];
		}
		else
		{
			filter = [filters objectAtIndex:[filterPopup indexOfObjectValue:type]];
		}
			
		
		NSImage *filterImage = [filter imageWithSize:NSMakeSize(1024, 436)];
		NSSize imageSize = [filterImage size];
		
		[newPreviewImage lockFocus];
		[filterImage drawInRect:NSMakeRect(0, 0, imageSize.width, imageSize.height) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
		[newPreviewImage unlockFocus];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MCUpdatePreview" object:newPreviewImage];
	
	//[previewImageView setImage:newPreviewImage];
	//[previewImageView display];
}

- (NSImage *)previewImageWithSize:(NSSize)size
{
	NSImage *newPreviewImage = [[NSImage alloc] initWithSize:size];

	NSInteger i;
	for (i = 0; i < [tableData count]; i ++)
	{
		NSDictionary *filterOptions = [tableData objectAtIndex:i];
		NSString *type = [filterOptions objectForKey:@"Type"];
		
		MCFilter *filter;
		if (filterOptions != openFilter)
		{
			filter = [[NSClassFromString(type) alloc] init];
				
			[filter setOptions:[filterOptions objectForKey:@"Options"]];
			
			NSImage *filterImage = [filter imageWithSize:size];
		
			[newPreviewImage lockFocus];
			[filterImage drawInRect:NSMakeRect(0, 0, size.width, size.height) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
			[newPreviewImage unlockFocus];
		}
	}
	
	return [newPreviewImage autorelease];
}

//////////////////////
// Tableview actions //
///////////////////////

#pragma mark -
#pragma mark •• Tableview actions

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	NSString *newTitle;
	if ([tableView numberOfSelectedRows] > 1)
		newTitle = NSLocalizedString(@"Duplicate Filters", nil);
	else
		newTitle = NSLocalizedString(@"Duplicate Filter", nil);
	
	[actionButton setTitle:newTitle atIndex:1];
}

//Count the number of rows, not really needed anywhere
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [tableData count];
}

//return selected row
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSDictionary *currentDictionary = [tableData objectAtIndex:row];
	NSString *type = [currentDictionary objectForKey:@"Type"];
	NSString *identifyer = [currentDictionary objectForKey:@"Identifyer"];

	NSString *rowName = [NSString stringWithFormat:@"%@ (%@)", [NSClassFromString(type) localizedName], identifyer];

	return rowName;
}

//We don't want to make people change our row values
- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return YES;
}

- (NSArray *)allSelectedItemsInTableView:(NSTableView *)table fromArray:(NSArray *)array
{
	NSMutableArray *items = [NSMutableArray array];
	NSIndexSet *indexSet = [table selectedRowIndexes];
	
	NSUInteger current_index = [indexSet firstIndex];
    while (current_index != NSNotFound)
    {
		if ([array objectAtIndex:current_index]) 
			[items addObject:[array objectAtIndex:current_index]];
			
        current_index = [indexSet indexGreaterThanIndex: current_index];
    }

	return items;
}

@end
