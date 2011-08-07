//
//  MCImageView.h
//  Media Converter
//
//  Created by Maarten Foukhar on 07-08-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MCImageView : NSImageView
{
	IBOutlet id delegate;
}

@end
