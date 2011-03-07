//
//  MCGrowlController.h
//  Media Converter
//
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Growl/Growl.h>

@interface MCGrowlController : NSObject<GrowlApplicationBridgeDelegate>
{
	NSArray *notifications;
	NSArray *notificationNames;
}

@end