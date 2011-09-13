//
//  MCInstallPanel.h
//  Media Converter
//
//  Install panel where the user can choose between '/Library/Application Support' or '~/Library/Application Support'
//
//  Created by Maarten Foukhar on 08-05-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MCInstallPanel : NSObject
{
	IBOutlet id installModePanel;
	IBOutlet id installModePopup;
	IBOutlet id suppressButton;
	IBOutlet id taskField;
}

- (NSString *)installLocation;
- (void)setTaskText:(NSString *)text;

/* Install Mode actions */
- (IBAction)endSettingMode:(id)sender;

@end
