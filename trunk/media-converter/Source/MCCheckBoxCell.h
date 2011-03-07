//
//  MCCheckBox.h
//  Media Converter
//
//  Created by Maarten Foukhar on 15-02-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MCCommonMethods.h"


@interface MCCheckBoxCell : NSButtonCell
{
	IBOutlet id dependChild;
}

- (id)dependChild;

@end
