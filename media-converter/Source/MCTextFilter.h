//
//  MCTextFilter.h
//  Media Converter
//
//  Created by Maarten Foukhar on 04-07-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MCFilter.h"


@interface MCTextFilter : MCFilter
{
	IBOutlet id textView;
	IBOutlet id textHorizontalPopup;
	IBOutlet id textVerticalPopup;
	IBOutlet id textVisiblePopup;
	IBOutlet id textMethodTabView;
	IBOutlet id textTransparencyText;
	
}

- (IBAction)setTextVisibility:(id)sender;

@end
