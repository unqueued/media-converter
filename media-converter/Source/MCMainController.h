//
//  MCMainController.h
//  Media Converter
//
//  Created by Maarten Foukhar on 22-01-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MCCommonMethods.h"
#import "MCProgress.h"
#import "MCConverter.h"
#import "MCPreferences.h"

@interface MCMainController : NSObject
{
	IBOutlet id mainWindow;
	IBOutlet id presetPopUp;
	IBOutlet id locationsPanel;
	IBOutlet id locationsTextField;
	
	IBOutlet id actionButton;
	
	MCProgress *progressPanel;
	MCConverter *converter;
	NSArray *inputFiles;
	BOOL cancelAddingFiles;
	
	MCPreferences *preferences;
}

//Main actions
- (void)versionUpdateCheck;
- (void)updatePresets;

//Interface actions
- (IBAction)setPresetPopup:(id)sender;

//Menu actions
- (IBAction)openPreferences:(id)sender;
- (IBAction)openFiles:(id)sender;
- (IBAction)openURLs:(id)sender;
- (IBAction)saveDocumentAs:(id)sender;
- (IBAction)goToSite:(id)sender;
- (IBAction)downloadSource:(id)sender;
- (IBAction)makeDonation:(id)sender;

//Locations actions
- (IBAction)endOpenLocations:(id)sender;

//Main actions
//Start a thread to check our files
- (void)checkFiles:(NSArray *)files;
//Check for protected file types
- (BOOL)isProtected:(NSString *)path;

//Check preferences for desired save method
- (void)saveFiles;

//Convert actions
//Convert files to path
- (void)convertFiles:(NSString *)path;

//Show an alert if needed (protected or no default files)
- (void)showAlert:(NSNumber *)protectedFiles;
- (NSString *)getRealPath:(NSString *)inPath;
- (void)closeWindow;

@end
