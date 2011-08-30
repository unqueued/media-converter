//
//  MCWatermarkFilter.h
//  Media Converter
//
//  Created by Maarten Foukhar on 04-07-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MCFilter.h"


@interface MCWatermarkFilter : MCFilter
{
	IBOutlet id watermarkImage;
	IBOutlet id watermarkImageName;
	IBOutlet id watermarkWidthField;
	IBOutlet id watermarkHeightField;
	IBOutlet id watermarkAspectCheckBox;
	IBOutlet id watermarkHorizontalPopup;
	IBOutlet id watermarkVerticalPopup;
	
	CGFloat aspectRatio;
}

- (IBAction)chooseWatermarkImage:(id)sender;
- (void)setImage:(NSImage *)image withIdentifyer:(NSString *)identifyer;

@end
