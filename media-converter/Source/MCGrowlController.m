//
//  MCGrowlController.m
//  Media Converter
//
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCGrowlController.h"
#import "MCCommonMethods.h"

@implementation MCGrowlController

/////////////////////
// Default actions //
/////////////////////

#pragma mark -
#pragma mark •• Default actions

- (id) init
{
	self = [super init];
	
	notifications = [[NSArray alloc] initWithObjects:		NSLocalizedString(@"Finished converting", nil),
															NSLocalizedString(@"Installed new preset", nil)
															, nil];
														
	notificationNames = [[NSArray alloc] initWithObjects:	@"growlFinishedConverting",
															@"growlInstalledPresets"
															, nil];
	
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	NSInteger i;
	for (i = 0; i < [notificationNames count]; i ++)
	{
		[defaultCenter addObserver:self selector:@selector(growlMessage:) name:[notificationNames objectAtIndex:i] object:nil];
	}
	
	[GrowlApplicationBridge setGrowlDelegate:self];
	[self registrationDictionaryForGrowl];

	return self;
}

- (void)dealloc
{
	[notifications release];
	[notificationNames release];

	[super dealloc];
}

- (NSDictionary *)registrationDictionaryForGrowl
{
	return [NSDictionary dictionaryWithObjectsAndKeys:notifications, GROWL_NOTIFICATIONS_ALL, notifications, GROWL_NOTIFICATIONS_DEFAULT, nil];
}

//////////////////////////
// Notification actions //
//////////////////////////

#pragma mark -
#pragma mark •• Notification actions

- (void)growlMessage:(NSNotification *)notif
{
	NSInteger index = [notificationNames indexOfObject:[notif name]];
	
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"MCUseSoundEffects"])
		{
			if (index > 3)
				[[NSSound soundNamed:@"Basso"] play];
			else
				[[NSSound soundNamed:@"complete"] play];
		}
	
	NSString *notificationName = [notifications objectAtIndex:index];
	
	[GrowlApplicationBridge notifyWithTitle:notificationName description:[notif object] notificationName:notificationName iconData:[NSData dataWithData:[[NSImage imageNamed:@"Media Converter"] TIFFRepresentation]] priority:0 isSticky:NO clickContext:nil];
}

@end