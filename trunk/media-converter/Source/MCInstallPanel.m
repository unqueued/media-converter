//
//  MCInstallPanel.m
//  Media Converter
//
//  Created by Maarten Foukhar on 08-05-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCInstallPanel.h"
#import "MCCommonMethods.h"
#import "NSNumber_Extensions.h"


@implementation MCInstallPanel

- (id)init
{
	self = [super init];
	
	[NSBundle loadNibNamed:@"MCInstallPanel" owner:self];

	return self;
}

- (NSString *)installLocation
{
	NSInteger installMode = [[[NSUserDefaults standardUserDefaults] objectForKey:@"MCInstallMode"] integerValue];
		
	if (installMode == 0)
	{
		[NSApp runModalForWindow:installModePanel];
		[installModePanel orderOut:self];
				
		installMode = [installModePopup indexOfSelectedItem] + 1;
	}
			
	if (installMode == 1)
		return @"/Library/Application Support";
	else
		return [@"~/Library/Application Support" stringByExpandingTildeInPath];
}

- (void)setTaskText:(NSString *)text
{
	[taskField setStringValue:text];
}

//////////////////////////
// Install Mode actions //
//////////////////////////

#pragma mark -
#pragma mark •• Install Mode actions

- (IBAction)endSettingMode:(id)sender
{
	if ([suppressButton state] == NSOnState)
	{
		NSInteger mode = [installModePopup indexOfSelectedItem] + 1;
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:mode] forKey:@"MCInstallMode"];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MCInstallModeChanged" object:[NSNumber numberWithInteger:mode]];
		[suppressButton setState:NSOffState];
	}

	[NSApp abortModal];
}

@end
