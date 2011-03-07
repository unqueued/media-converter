//
//  MCAddDelegate.h
//  Media Converter
//
//  Created by Maarten Foukhar on 26-02-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MCCommonMethods.h"


@interface MCAddDelegate : NSObject
{
	NSMutableArray *tableData;
	IBOutlet id tableView;
	IBOutlet id windowController;
}

@end
