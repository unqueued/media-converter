//
//  MCMainController.h
//  Media Converter
//
//  Controller for main window / menus
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
	//IB Outlets
	IBOutlet id mainWindow;
	IBOutlet id presetPopUp;
	IBOutlet id locationsPanel;
	IBOutlet id locationsTextField;
	IBOutlet id actionButton;
	
	//Custom objects
	MCProgress *progressPanel;
	MCConverter *converter;
	MCPreferences *preferences;
	
	//Other variables
	NSArray *inputFiles;
	BOOL cancelAddingFiles;
}

/* Update actions */
//Some things changed in version 1.2, check if we need to update things
- (void)versionUpdateCheck;
//Update the popup presetslist in the main window
- (void)updatePresets;

/* Interface actions */
//Save the current preset to the preferences
- (IBAction)setPresetPopup:(id)sender;
//Edit the preset
- (IBAction)edit:(id)sender;
//Save the preset
- (IBAction)saveDocumentAs:(id)sender;

/* Menu actions */
//Open the preferences
- (IBAction)openPreferences:(id)sender;
//Open media files
- (IBAction)openFiles:(id)sender;
//Open internet URL files
- (IBAction)openURLs:(id)sender;
//Stop locations panel with return code
- (IBAction)endOpenLocations:(id)sender;
//Visit the site
- (IBAction)goToSite:(id)sender;
//Get the application or external applications source (links to a folder)
- (IBAction)downloadSource:(id)sender;
//Opens internal donation html page
- (IBAction)makeDonation:(id)sender;

/* Main actions */
//Start a thread to check our files
- (void)checkFiles:(NSArray *)files;
//Show an alert if needed (protected or no default files)
- (void)showAlert:(NSNumber *)protectedFiles;
//Check preferences for desired save method
- (void)saveFiles;

/* Convert actions */
//Convert files to path
- (void)convertFiles:(NSString *)path;
//Show an alert if some files failed to be converted
- (void)showConvertFailAlert:(NSString *)errorString;

/* Other actions */
//Use some c to get the real path
- (NSString *)getRealPath:(NSString *)inPath;
//Check for protected file types
- (BOOL)isProtected:(NSString *)path;
//Quit when closing main window (seems to be allowed now for system utilities)
- (void)closeWindow;

@end
