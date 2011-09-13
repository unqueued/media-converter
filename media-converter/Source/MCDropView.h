//
//  MCDropView.h
//  Media Converter
//
//  NSView subclass handling dropping files in the main window
//
//  Created by Maarten Foukhar on 22-01-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MCCommonMethods.h"

@interface MCDropView : NSView
{
	//MCMainController
	IBOutlet id mainController;
}

@end
