//
//  MCTableView.h
//  Media Converter
//
//  Created by Maarten Foukhar on 05-03-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MCTableView : NSTableView
{
	NSString *notificationName;
}

- (void)setReloadNotificationName:(NSString *)name;

@end
