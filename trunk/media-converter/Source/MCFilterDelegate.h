//
//  MCFilterDelegate.h
//  Media Converter
//
//  Created by Maarten Foukhar on 25-06-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MCFilter.h"


@interface MCFilterDelegate : NSObject
{
	IBOutlet id modalWindow;
	NSMutableArray *tableData;
	IBOutlet id tableView;
	IBOutlet id filterWindow;
	IBOutlet id filterPopup;
	IBOutlet id previewPanel;
	IBOutlet id previewImageView;
	IBOutlet id actionButton;
	IBOutlet id filterCloseButton;
	
	//Filters
	NSMutableArray *filters;
	id openFilterOptions;
	MCFilter *openFilter;
}

- (IBAction)addFilter:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)add:(id)sender;
- (IBAction)cancel:(id)sender;

- (IBAction)selectFilter:(id)sender;

- (IBAction)showPreview:(id)sender;

- (NSImage *)previewImageWithSize:(NSSize)size;

- (NSArray *)allSelectedItemsInTableView:(NSTableView *)table fromArray:(NSArray *)array;

- (void)setFilterOptions:(id)options;

@end
