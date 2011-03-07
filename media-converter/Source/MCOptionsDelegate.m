//
//  MCOptionsDelegate.m
//
//  Created by Maarten Foukhar on 27-01-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCOptionsDelegate.h"
#import "MCPreferences.h"

@implementation MCOptionsDelegate

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

- (IBAction)addOption:(id)sender
{
	[tableData addObject:[NSDictionary dictionaryWithObject:@"" forKey:@""]];
	[tableView reloadData];
	
	NSInteger lastRow = [tableData count] - 1;
	[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:lastRow] byExtendingSelection:NO];
	[tableView editColumn:0 row:lastRow withEvent:nil select:YES];
}

- (IBAction)removeOption:(id)sender
{
	[tableData removeObjectsInArray:[self allSelectedItemsInTableView:tableView fromArray:tableData]];
	[tableView reloadData];
}

- (void)setOptions:(NSArray *)options
{
	[tableData removeAllObjects];
	[tableData addObjectsFromArray:options];
}

- (NSMutableArray *)options
{
	return tableData;
}

//////////////////////
// Tableview actions //
///////////////////////

#pragma mark -
#pragma mark •• Tableview actions

//Count the number of rows, not really needed anywhere
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [tableData count];
}

//return selected row
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSDictionary *currentDictionary = [tableData objectAtIndex:row];
	NSString *currentKey = [[currentDictionary allKeys] objectAtIndex:0];
	
	NSString *identifier = [tableColumn identifier];
	
	if ([identifier isEqualTo:@"option"])
		return currentKey;
	else
		return [currentDictionary objectForKey:currentKey];
}

//We don't want to make people change our row values
- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return YES;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSDictionary *currentDictionary = [tableData objectAtIndex:row];
	NSString *currentKey = [[currentDictionary allKeys] objectAtIndex:0];
	NSInteger currentIndex = [tableData indexOfObject:currentDictionary];
	
	NSString *identifier = [tableColumn identifier];
	NSDictionary *newDictionary;
	
	if ([identifier isEqualTo:@"option"])
	{
		id currentObject = [currentDictionary objectForKey:currentKey];
		newDictionary = [NSDictionary dictionaryWithObject:currentObject forKey:anObject];
		
		[(MCPreferences *)windowController updateForKey:currentKey withProperty:nil];
		[(MCPreferences *)windowController updateForKey:anObject withProperty:currentObject];
	}
	else
	{
		newDictionary = [NSDictionary dictionaryWithObject:anObject forKey:currentKey];
		[(MCPreferences *)windowController updateForKey:currentKey withProperty:anObject];
	}
	
	[tableData replaceObjectAtIndex:currentIndex withObject:newDictionary];
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
