//
//  MCProgressSlider.h
//  Media Converter
//
//  Created by Maarten Foukhar on 30-08-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MCCommonMethods.h"


@interface MCProgressSlider : NSSlider
{
	IBOutlet id statusText;
}

- (void)setText:(CGFloat)value;

@end
