//
//  MCOptionsDelegate.h
//
//  Created by Maarten Foukhar on 27-01-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MCCommonMethods.h"

@interface MCOptionsDelegate : NSObject
{
	NSMutableArray *tableData;
	IBOutlet id tableView;
	IBOutlet id windowController;
}

- (IBAction)addOption:(id)sender;
- (IBAction)removeOption:(id)sender;

- (void)setOptions:(NSArray *)options;
- (NSMutableArray *)options;

- (NSArray *)allSelectedItemsInTableView:(NSTableView *)table fromArray:(NSArray *)array;

@end
