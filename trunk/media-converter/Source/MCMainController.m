//
//  MCMainController.m
//  Media Converter
//
//  Created by Maarten Foukhar on 22-01-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCMainController.h"
#import "MCGrowlController.h"
#import "NSNumber_Extensions.h"
#import "NSArray_Extensions.h"
#import "MCAlert.h"
#import "MCActionButton.h"

@implementation MCMainController

+ (void)initialize
{
	NSDictionary *infoDictionary = [[NSBundle mainBundle] localizedInfoDictionary];
	
	//Setup some defaults for the preferences (used when options aren't set)
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSArray *defaultKeys = [NSArray arrayWithObjects:	@"MCUseSoundEffects",
														@"MCInstallMode",
														@"MCSaveMethod",
														@"MCSaveLocation",
														@"MCDebug",
														@"MCUseCustomFFMPEG",
														@"MCCustomFFMPEG",
														@"MCSavedPrefView",
														@"MCSelectedPreset",
														@"MCDVDForceAspect",
														@"MCMuxSeperateStreams",
														@"MCRemuxMPEG2Streams",
														@"MCSubtitleLanguage",
	nil];

	NSArray *defaultValues = [NSArray arrayWithObjects:	[NSNumber numberWithBool:YES],							// MCUseSoundEffects
														[NSNumber numberWithInteger:0],							// MCInstallMode
														[NSNumber numberWithInteger:0],							// MCSaveMethod
														[@"~/Movies" stringByExpandingTildeInPath],				// MCSaveLocation
														[NSNumber numberWithBool:NO],							// MCDebug
														[NSNumber numberWithBool:NO],							// MCUseCustomFFMPEG
														@"",													// MCCustomFFMPEG
														@"General",												// MCSavedPrefView
														[NSNumber numberWithInteger:0],							// MCSelectedPreset
														[NSNumber numberWithInteger:0],							// MCDVDForceAspect
														[NSNumber numberWithBool:NO],							// MCMuxSeperateStreams
														[NSNumber numberWithBool:NO],							// MCRemuxMPEG2Streams
														[infoDictionary objectForKey:@"MCSubtitleLanguage"],	// MCSubtitleLanguage
	nil];

	NSDictionary *appDefaults = [NSDictionary dictionaryWithObjects:defaultValues forKeys:defaultKeys];
	[defaults registerDefaults:appDefaults];
}

- (void)awakeFromNib
{
	//Setup action button
	[actionButton setDelegate:self];
	[actionButton addMenuWithTitle:NSLocalizedString(@"Edit Preset…", nil) withSelector:@selector(edit:)];
	[actionButton addMenuWithTitle:NSLocalizedString(@"Save Preset…", nil) withSelector:@selector(saveDocumentAs:)];
	
	//Placeholder error string
	NSString *error = NSLocalizedString(@"An unkown error occured", nil);
	
	//NSTexturedRoundedBezelStyle doesn't look right in 10.4 and earlies
	if ([MCCommonMethods OSVersion] < 0x1050)
		[presetPopUp setBezelStyle:NSRoundedBezelStyle];
	
	//Make ourselves delegate so we'll receive actions as firstResponder
	[NSApp setDelegate:self];
	
	//Quit the application when the main window is closed (seems to be accepted in Mac OS X)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closeWindow) name:NSWindowWillCloseNotification object:mainWindow];

	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	
	//Setup Preset popup in the main window
	[presetPopUp removeAllItems];
	
	NSFileManager *defaultManager = [MCCommonMethods defaultManager];
	NSString *folder = @"/Library/Application Support/Media Converter/Presets";
	NSString *supportFolder = [folder stringByDeletingLastPathComponent];
	
	NSString *userSupportFolder = [@"~/Library/Application Support/Media Converter" stringByExpandingTildeInPath];
	NSString *userFolder = [userSupportFolder stringByAppendingPathComponent:@"Presets"];
	
	NSArray *presets = [standardDefaults objectForKey:@"MCPresets"];
	
	BOOL hasSupportFolder = ([defaultManager fileExistsAtPath:folder] | [defaultManager fileExistsAtPath:userFolder]);
	
	//Popupulate preset folder after creating it
	if (!hasSupportFolder | [presets count] == 0)
	{
		if (!hasSupportFolder)
		{
			NSString *presetsFolder = [[NSBundle mainBundle] pathForResource:@"Presets" ofType:@""];	
			BOOL supportWritable = YES;
		
			if (![defaultManager fileExistsAtPath:supportFolder])
				supportWritable = [MCCommonMethods createDirectoryAtPath:supportFolder errorString:&error];
		
			if (supportWritable)
			{
				supportWritable = [MCCommonMethods copyItemAtPath:presetsFolder toPath:folder errorString:&error];
			}
			else
			{
				if (![defaultManager fileExistsAtPath:userSupportFolder])
					supportWritable = [MCCommonMethods createDirectoryAtPath:userSupportFolder errorString:&error];
				
				if (supportWritable)
					supportWritable = [MCCommonMethods copyItemAtPath:presetsFolder toPath:userFolder errorString:&error];
			}
			
			if (!supportWritable)
			{
				[MCCommonMethods standardAlertWithMessageText:NSLocalizedString(@"Failed to copy 'Presets' folder", nil) withInformationText:error withParentWindow:nil withDetails:nil];
				
				[presetPopUp setEnabled:NO];
				[presetPopUp addItemWithTitle:NSLocalizedString(@"No Presets", nil)];
	
				[[MCGrowlController alloc] init];
				
				return;
			}
		}
		
		NSArray *folders;
		
		if ([defaultManager fileExistsAtPath:userFolder])
			folders = [NSArray arrayWithObjects:folder, userFolder, nil];
		else
			folders = [NSArray arrayWithObject:folder];
	
		NSArray *presetPaths = [MCCommonMethods getFullPathsForFolders:folders withType:@"mcpreset"];
		NSMutableArray *savedPresets = [NSMutableArray array];
		
		NSInteger i;
		for (i = 0; i < [presetPaths count]; i ++)
		{
			NSString *path = [presetPaths objectAtIndex:i];
			
			NSDictionary *preset = [NSDictionary dictionaryWithContentsOfFile:path];
			
			NSString *name = [preset objectForKey:@"Name"];
			NSDictionary *newPreset = [NSDictionary dictionaryWithObjectsAndKeys:name, @"Name", path, @"Path", nil];
			
			[savedPresets addObject:newPreset];
		}

		[standardDefaults setObject:savedPresets forKey:@"MCPresets"];
	}
	
	//Now really update preset popup
	[self updatePresets];
	
	//Create our Growl object
	[[MCGrowlController alloc] init];
	
	//Check version to update some presets and phyton if needed (after asking of cource)
	[self performSelectorOnMainThread:@selector(versionUpdateCheck) withObject:nil waitUntilDone:NO];
}

//Files dropped on the application icon, opened with... or other external open methods
//Check for preset files, the other files are checked if they can be convertered
- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
	NSMutableArray *presetFiles = [NSMutableArray array];
	NSMutableArray *otherFiles = [NSMutableArray array];
	
	NSInteger i;
	for (i = 0; i < [filenames count]; i ++)
	{
		NSString *file = [filenames objectAtIndex:i];
		NSString *extension = [file pathExtension];
		
		if ([[extension lowercaseString] isEqualTo:@"mcpreset"])
			[presetFiles addObject:file];
		else
			[otherFiles addObject:file];
	}
	
	if ([presetFiles count] > 0)
	{
		[self openPreferences:nil];
		[preferences openPresetFiles:filenames];
	}
	
	if ([otherFiles count] > 0)
	{
		[self checkFiles:otherFiles];
	}
}

////////////////////
// Update actions //
////////////////////

#pragma mark -
#pragma mark •• Update actions

//Some things changed in version 1.2, check if we need to update things
- (void)versionUpdateCheck
{
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	CGFloat lastCheck = [[standardDefaults objectForKey:@"MCLastCheck"] cgfloatValue];
	
	if (lastCheck < 1.2)
	{
		NSInteger returnCode;
		
		//Check for phyton and ask to upgrade it if needed
		if (![MCCommonMethods isPythonUpgradeInstalled])
		{
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert addButtonWithTitle:NSLocalizedString(@"Get it", nil)];
			[alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
			[[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\E"];
			[alert setMessageText:NSLocalizedString(@"To convert YouTube videos on Mac OS X 10.4 'Media Converter' requires a newer version of python", nil)];
			[alert setInformativeText:NSLocalizedString(@"Would you like to download it?", nil)];
		
			returnCode = [alert runModal];
		
			if (returnCode == NSAlertFirstButtonReturn) 
				[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.python.org/download"]];
		}
		
		//Ask if the user wants to update the presets for using subtitles
		NSAlert *upgradeAlert = [[[NSAlert alloc] init] autorelease];
		[upgradeAlert addButtonWithTitle:NSLocalizedString(@"Update", nil)];
		[upgradeAlert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
		[[[upgradeAlert buttons] objectAtIndex:1] setKeyEquivalent:@"\E"];
		[upgradeAlert setMessageText:NSLocalizedString(@"This release of 'Media Converter' adds subtitle support", nil)];
		[upgradeAlert setInformativeText:NSLocalizedString(@"Would you like to update the presets to support it?", nil)];
		
		returnCode = [upgradeAlert runModal];
		
		//Update presets when the user chose "Update"
		if (returnCode == NSAlertFirstButtonReturn)
		{
			NSArray *presets = [standardDefaults objectForKey:@"MCPresets"];
			
			NSInteger i;
			for (i = 0; i < [presets count]; i ++)
			{
				NSString *path = [[presets objectAtIndex:i] objectForKey:@"Path"];
				NSMutableDictionary *preset = [NSMutableDictionary dictionaryWithContentsOfFile:path];
				[preset setObject:@"1.2" forKey:@"Version"];

				NSArray *encoderOptions = [preset objectForKey:@"Encoder Options"];
				NSMutableDictionary *extraOptions = [preset objectForKey:@"Extra Options"];
			
				if ([encoderOptions indexOfObject:@"matroska" forKey:@"-f"] != NSNotFound)
					[extraOptions setObject:@"mkv" forKey:@"Subtitle Type"];
				
				if ([encoderOptions indexOfObject:@"ogg" forKey:@"-f"] != NSNotFound)
					[extraOptions setObject:@"kate" forKey:@"Subtitle Type"];
				
				if ([encoderOptions indexOfObject:@"ipod" forKey:@"-f"] != NSNotFound)
					[extraOptions setObject:@"mp4" forKey:@"Subtitle Type"];
				
				if ([encoderOptions indexOfObject:@"mov" forKey:@"-f"] != NSNotFound)
					[extraOptions setObject:@"mp4" forKey:@"Subtitle Type"];
					
				if ([encoderOptions indexOfObject:@"avi" forKey:@"-f"] != NSNotFound)
					[extraOptions setObject:@"srt" forKey:@"Subtitle Type"];
					
				if ([encoderOptions indexOfObject:@"dvd" forKey:@"-f"] != NSNotFound)
					[extraOptions setObject:@"dvd" forKey:@"Subtitle Type"];
					
				[extraOptions setObject:@"Helvetica" forKey:@"Subtitle Font"];
				[extraOptions setObject:@"24" forKey:@"Subtitle Font Size"];
				[extraOptions setObject:@"center" forKey:@"Subtitle Horizontal Alignment"];
				[extraOptions setObject:@"bottom" forKey:@"Subtitle Vertical Alignment"];
				[extraOptions setObject:@"60" forKey:@"Subtitle Left Margin"];
				[extraOptions setObject:@"60" forKey:@"Subtitle Right Margin"];
				[extraOptions setObject:@"20" forKey:@"Subtitle Top Margin"];
				[extraOptions setObject:@"30" forKey:@"Subtitle Bottom Margin"];
					
				[preset setObject:extraOptions forKey:@"Extra Options"];
				[preset writeToFile:path atomically:YES];
				[MCCommonMethods writeDictionary:preset toFile:path errorString:nil];
			}
		}
		
		preferences = [[MCPreferences alloc] init];
		[preferences setDelegate:self];
		
		//Update fonts (spumux needs ttf files, we save them in the Application Support folder and make a symbolic link before starting spumux (~/.spumux))
		[preferences updateFontListForWindow:nil];
		
		//Update "MCLastCheck" so we'll won't check again
		[standardDefaults setObject:[NSNumber numberWithCGFloat:1.2] forKey:@"MCLastCheck"];
		
		[preferences release];
		preferences = nil;
		
		//Make sure our main window is in front
		[mainWindow makeKeyAndOrderFront:nil];
	}
}

//When the application starts or when a change has been made related to the presets update the preset menu
//in the main window
- (void)updatePresets
{
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	NSString *currentTitle = [presetPopUp titleOfSelectedItem];

	[presetPopUp removeAllItems];
	
	NSArray *presets = [standardDefaults objectForKey:@"MCPresets"];

	BOOL hasPresets = ([presets count] > 0);
	[presetPopUp setEnabled:hasPresets];
	
	if (!hasPresets)
	{
		[presetPopUp addItemWithTitle:NSLocalizedString(@"No Presets", nil)];
	}
	else
	{
		NSInteger i;
		for (i = 0; i < [presets count]; i ++)
		{
			NSDictionary *preset = [presets objectAtIndex:i];
			NSString *name = [preset objectForKey:@"Name"];
			[presetPopUp addItemWithTitle:name];
		}
	
		if (currentTitle && [presetPopUp itemWithTitle:currentTitle])
		{
			[presetPopUp selectItemWithTitle:currentTitle];
			NSNumber *selectIndex = [NSNumber numberWithInteger:[presetPopUp indexOfItemWithTitle:currentTitle]];
			[[NSUserDefaults standardUserDefaults] setObject:selectIndex forKey:@"MCSelectedPreset"];
		}
		else
		{
			NSInteger saveIndex = [[standardDefaults objectForKey:@"MCSelectedPreset"] integerValue];
		
			while (saveIndex >= [presets count])
			{
				saveIndex = saveIndex - 1;
			}
		
			[presetPopUp selectItemAtIndex:saveIndex];
		}
	}
}

///////////////////////
// Interface actions //
///////////////////////

#pragma mark -
#pragma mark •• Interface actions

//Save the current preset to the preferences
- (IBAction)setPresetPopup:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setObject:[sender objectValue] forKey:@"MCSelectedPreset"];
}

//Edit the preset
- (IBAction)edit:(id)sender
{
	if (preferences == nil)
	{
		preferences = [[MCPreferences alloc] init];
		[preferences setDelegate:self];
	}
	
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	NSArray *presets = [standardDefaults objectForKey:@"MCPresets"];
	
	NSDictionary *presetDictionary = [presets objectAtIndex:[[standardDefaults objectForKey:@"MCSelectedPreset"] integerValue]];
	NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:[presetDictionary objectForKey:@"Name"], @"Name", [presetDictionary objectForKey:@"Path"], @"Path", nil];
	
	[preferences editPresetForWindow:mainWindow withDictionary:dictionary];
}

//Save the preset
- (IBAction)saveDocumentAs:(id)sender
{
	if (preferences == nil)
	{
		preferences = [[MCPreferences alloc] init];
		[preferences setDelegate:self];
	}
	
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	NSArray *presets = [standardDefaults objectForKey:@"MCPresets"];
	
	NSDictionary *presetDictionary = [presets objectAtIndex:[[standardDefaults objectForKey:@"MCSelectedPreset"] integerValue]];
	NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:[presetDictionary objectForKey:@"Name"], @"Name", [presetDictionary objectForKey:@"Path"], @"Path", nil];

	[preferences savePresetForWindow:mainWindow withDictionary:dictionary];
}

//////////////////
// Menu actions //
//////////////////

#pragma mark -
#pragma mark •• Menu actions

//Open the preferences
- (IBAction)openPreferences:(id)sender
{
	if (preferences == nil)
	{
		preferences = [[MCPreferences alloc] init];
		[preferences setDelegate:self];
	}
	
	[preferences showPreferences];
}

//Open media files
- (IBAction)openFiles:(id)sender
{
	NSOpenPanel *sheet = [NSOpenPanel openPanel];
	[sheet setCanChooseFiles:YES];
	[sheet setCanChooseDirectories:YES];
	[sheet setAllowsMultipleSelection:YES];
	[sheet beginSheetForDirectory:nil file:nil types:nil modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{	
	[sheet orderOut:self];

	if (returnCode == NSOKButton)
	{
		[self checkFiles:[sheet filenames]];
	}
}

//Open internet URL files
- (IBAction)openURLs:(id)sender
{
	[NSApp beginSheet:locationsPanel modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(openURLsPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

//Stop locations panel with return code
- (IBAction)endOpenLocations:(id)sender
{
	[NSApp endSheet:locationsPanel returnCode:[sender tag]];
}

- (void)openURLsPanelDidEnd:(NSWindow *)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[panel orderOut:self];

	if (returnCode == NSOKButton)
	{
		NSString *fieldString = [[locationsTextField textStorage] string];
	
		[self checkFiles:[fieldString componentsSeparatedByString:@"\n"]];
	}
	
	[locationsTextField setString:@""];
}

//Visit the site
- (IBAction)goToSite:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://media-converter.sourceforge.net"]];
}

//Get the application or external applications source (links to a folder)
- (IBAction)downloadSource:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://sourceforge.net/projects/media-converter/files/media-converter/1.2/"]];
}

//Opens internal donation html page
- (IBAction)makeDonation:(id)sender
{
	[[NSWorkspace sharedWorkspace] openFile:[[[NSBundle mainBundle] pathForResource:@"Donation" ofType:@""] stringByAppendingPathComponent:@"donate.html"]];
}

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

//Start a thread to check our files
- (void)checkFiles:(NSArray *)files
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setCancelAdding) name:@"cancelAdding" object:nil];

	cancelAddingFiles = NO;

	progressPanel = [[MCProgress alloc] init];
	[progressPanel setTask:NSLocalizedString(@"Checking files...", nil)];
	[progressPanel setStatus:NSLocalizedString(@"Scanning for files and folders", nil)];
	[progressPanel setIcon:[NSImage imageNamed:@"Media Converter"]];
	[progressPanel setMaximumValue:[NSNumber numberWithDouble:0]];
	[progressPanel setCancelNotification:@"cancelAdding"];
	[progressPanel beginSheetForWindow:mainWindow];

	[NSThread detachNewThreadSelector:@selector(checkFilesInThread:) toTarget:self withObject:files];
}

//Check if the file is folder or file, if it is folder scan it, when a file
//if it's protected
- (void)checkFilesInThread:(NSArray *)paths
{
	//Needed because we're in a new thread
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	MCConverter *convertObject = [[MCConverter alloc] init];
	
	NSFileManager *defaultManager = [MCCommonMethods defaultManager];
	NSMutableArray *files = [NSMutableArray array];
	NSInteger protectedCount = 0;
	BOOL upgradedPython = [MCCommonMethods isPythonUpgradeInstalled];
	
	NSInteger x = 0;
	for (x = 0; x < [paths count]; x++)
	{
		NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
			
		if (cancelAddingFiles == YES)
			break;
			
		NSDirectoryEnumerator *enumer;
		NSString* pathName;
		NSString *realPath = [self getRealPath:[paths objectAtIndex:x]];
		BOOL fileIsFolder = NO;
			
		[defaultManager fileExistsAtPath:realPath isDirectory:&fileIsFolder];

		if (fileIsFolder)
		{
			enumer = [defaultManager enumeratorAtPath:realPath];
			while (pathName = [enumer nextObject])
			{
				NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
						
				if (cancelAddingFiles == YES)
					break;
						
				NSString *realPathName = [self getRealPath:[realPath stringByAppendingPathComponent:pathName]];
			
				if (![self isProtected:realPathName])
				{
					BOOL youTubeURL = [MCCommonMethods isYouTubeURLAtPath:realPathName];
					if ((!youTubeURL | youTubeURL && upgradedPython) && [convertObject isMediaFile:realPathName])
						[files addObject:realPathName];
				}
				else
				{
					protectedCount = protectedCount + 1;
				}
				
				[subPool release];
				subPool = nil;
			}
		}
		else
		{
			if (cancelAddingFiles == YES)
				break;
						
			if (![self isProtected:realPath])
			{
				BOOL youTubeURL = [MCCommonMethods isYouTubeURLAtPath:realPath];
				if ((!youTubeURL | youTubeURL && upgradedPython) && [convertObject isMediaFile:realPath])
					[files addObject:realPath];
			}
			else
			{
				protectedCount = protectedCount + 1;
			}
		}
	
		[subPool release];
		subPool = nil;
	}
	
	if ([files count] > 0)
		inputFiles = [[NSArray alloc] initWithArray:files];
		
	[converter release];
	converter = nil;
		
	cancelAddingFiles = NO;

	//Stop being the observer
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"cancelAdding" object:nil];
	
	if ([files count] > 0)
	{
		[self performSelectorOnMainThread:@selector(showAlert:) withObject:[NSNumber numberWithInteger:protectedCount] waitUntilDone:NO];
	}
	else
	{
		[progressPanel endSheet];
		[progressPanel release];
		progressPanel = nil;
	}

	[pool release];
	pool = nil;
}

//Show an alert if needed (protected or no default files
- (void)showAlert:(NSNumber *)protectedFiles
{
	NSInteger incompatibleFiles = [protectedFiles integerValue];
	
	if (incompatibleFiles > 0)
	{
		[progressPanel endSheet];
		[progressPanel release];
		progressPanel = nil;

		if ([inputFiles count] > 0)
		{
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert addButtonWithTitle:NSLocalizedString(@"Continue", nil)];
			[alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
			[[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\E"];
		
			NSString *protectedString;
		
			if (incompatibleFiles > 1)
			{
				[alert setMessageText:NSLocalizedString(@"Some protected files", nil)];
				protectedString = NSLocalizedString(@"These can't be converted, would you like to continue?", nil);
			}
			else
			{
				[alert setMessageText:NSLocalizedString(@"One protected file", nil)];
				protectedString = NSLocalizedString(@"This file can't be converted, would you like to continue?", nil);;
			}
		
			[alert setInformativeText:protectedString];
			[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
		}
		else if ([inputFiles count] == 0)
		{
			NSString *message;
			NSString *information;
			
			if (incompatibleFiles > 1)
			{
				message = NSLocalizedString(@"Some protected mp4 files", nil);
				information = NSLocalizedString(@"These files can't be converted", nil);
			}
			else
			{
				message = NSLocalizedString(@"One protected mp4 file", nil);
				information = NSLocalizedString(@"This file can't be converted", nil);
			}

			[MCCommonMethods standardAlertWithMessageText:message withInformationText:information withParentWindow:mainWindow withDetails:nil];
		}
	}
	else
	{
		[self saveFiles];
	}
}

//Check preferences for desired save method
- (void)saveFiles
{
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	
	NSInteger saveMethod = [[standardDefaults objectForKey:@"MCSaveMethod"] integerValue];
	if (saveMethod == 2)
	{
		[progressPanel endSheet];
		[progressPanel release];
		progressPanel = nil;
	
		NSOpenPanel *sheet = [NSOpenPanel openPanel];
		[sheet setCanChooseFiles: NO];
		[sheet setCanChooseDirectories: YES];
		[sheet setAllowsMultipleSelection: NO];
		[sheet setCanCreateDirectories: YES];
		[sheet setPrompt:NSLocalizedString(@"Choose", nil)];
		[sheet setMessage:NSLocalizedString(@"Choose a location to save the converted files", nil)];
		[sheet beginSheetForDirectory:nil file:nil types:nil modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
	else
	{
		[NSThread detachNewThreadSelector:@selector(convertFiles:) toTarget:self withObject:[standardDefaults objectForKey:@"MCSaveLocation"]];
	}
}

//Alert did end, whe don't need to do anything special, well releasing the alert we do, the user should
- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[[alert window] orderOut:self];
	
	if (returnCode == NSAlertFirstButtonReturn) 
		[self saveFiles];
}

//Place has been chosen change our editfield with this path
- (void)savePanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];

	if (returnCode == NSOKButton) 
	{
		[NSThread detachNewThreadSelector:@selector(convertFiles:) toTarget:self withObject:[sheet filename]];
	}
	else
	{
		[inputFiles release];
		inputFiles = nil;
	}
}

/////////////////////
// Convert actions //
/////////////////////

#pragma mark -
#pragma mark •• Convert actions

//Convert files to path
- (void)convertFiles:(NSString *)path
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	if (!progressPanel)
	{
		progressPanel = [[MCProgress alloc] init];
		[progressPanel setIcon:[NSImage imageNamed:@"Media Converter"]];
		[progressPanel beginSheetForWindow:mainWindow];
	}
	
	[progressPanel setTask:NSLocalizedString(@"Preparing to encode", nil)];
	[progressPanel setStatus:NSLocalizedString(@"Checking file...", nil)];
	[progressPanel setMaximumValue:[NSNumber numberWithInteger:100 * [inputFiles count]]];

	converter = [[MCConverter alloc] init];
	
	//NSDictionary *options = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:path, @"mpg", [NSNumber numberWithInteger:0], [NSNumber numberWithInteger:3], nil]  forKeys:[NSArray arrayWithObjects:@"MCConvertDestination", @"MCConvertExtension", @"MCConvertRegion", @"MCConvertKind", nil]];
	NSString *errorString = nil;
	
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	NSArray *presets = [standardDefaults objectForKey:@"MCPresets"];
	NSDictionary *options = [NSDictionary dictionaryWithContentsOfFile:[[presets objectAtIndex:[[standardDefaults objectForKey:@"MCSelectedPreset"] integerValue]] objectForKey:@"Path"]];
	
	NSArray *extraOptionMappings = [[NSArray alloc] initWithObjects:	
																//Video
																@"Keep Aspect",									//101
																@"Auto Aspect",									//102
																@"Auto Size",									//103
																
																//Subtitles
																@"Subtitle Type",								//104
																@"Subtitle Default Language",					//105
																// Hardcoded
																@"Font",										//106
																@"Font Size",									//107
																@"Color",										//108
																@"Horizontal Alignment",						//109
																@"Vertical Alignment",							//110
																@"Left Margin",									//111
																@"Right Margin",								//112
																@"Top Margin",									//113
																@"Bottom Margin",								//114
																@"Method",										//115
																@"Box Color",									//116
																@"Box Marge",									//117
																@"Box Alpha Value",								//118
																@"Border Color",								//119
																@"Border Size",									//120
																@"Alpha Value",									//121
																// DVD
																@"Subtitle Font",								//122
																@"Subtitle Font Size",							//123
																@"Subtitle Horizontal Alignment",				//124
																@"Subtitle Vertical Alignment",					//125
																@"Subtitle Left Margin",						//126
																@"Subtitle Right Margin",						//127
																@"Subtitle Top Margin",							//128
																@"Subtitle Bottom Margin",						//129
																
																//Advanced
																@"Two Pass",									//130
																@"Start Atom",									//131
		nil];
		
		NSArray *extraOptionDefaultValues = [[NSArray alloc] initWithObjects:	
																//Video
																[NSNumber numberWithBool:NO],										// Keep Aspect
																[NSNumber numberWithBool:NO],										// Auto Aspect
																[NSNumber numberWithBool:NO],										// Auto Size
																
																//Subtitles
																@"Subtitle Type",													// Subtitle Type
																@"Subtitle Default Language",										// Subtitle Default Language
																// Hardcoded
																@"Helvetica",														// Font
																[NSNumber numberWithCGFloat:24],									// Font Size
																[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]],		// Color
																@"center",															// Horizontal Alignment
																@"bottom",															// Vertical Alignment
																[NSNumber numberWithInteger:0],										// Left Margin
																[NSNumber numberWithInteger:0],										// Right Margin
																[NSNumber numberWithInteger:0],										// Top Margin
																[NSNumber numberWithInteger:0],										// Bottom Margin
																@"border",															// Method
																[NSArchiver archivedDataWithRootObject:[NSColor darkGrayColor]],	// Box Color
																[NSNumber numberWithInteger:10],									// Box Marge
																[NSNumber numberWithDouble:0.50],									// Box Alpha Value
																[NSArchiver archivedDataWithRootObject:[NSColor blackColor]],		// Border Color
																[NSNumber numberWithInteger:4],										// Border Size
																[NSNumber numberWithDouble:1.0],									// Alpha Value
																// DVD
																@"Helvetica",														// Subtitle Font
																[NSNumber numberWithCGFloat:24],									// Subtitle Font Size
																@"center",															// Subtitle Horizontal Alignment
																@"bottom",															// Subtitle Vertical Alignment
																[NSNumber numberWithInteger:60],									// Subtitle Left Margin
																[NSNumber numberWithInteger:60],									// Subtitle Right Margin
																[NSNumber numberWithInteger:20],									// Subtitle Top Margin
																[NSNumber numberWithInteger:30],									// Subtitle Bottom Margin
																
																//Advanced
																[NSNumber numberWithBool:NO],										// Two Pass
																[NSNumber numberWithBool:NO],										// Start Atom
		nil];
	
	NSInteger result = [converter batchConvert:inputFiles toDestination:path withOptions:options withDefaults:[NSDictionary	dictionaryWithObjects:extraOptionDefaultValues forKeys:extraOptionMappings] errorString:&errorString];

	//NSArray *succeededFiles = [NSArray arrayWithArray:[converter succesArray]];
	
	[converter release];
	converter = nil;

	/*NSInteger y;
	for (y=0;y<[succeededFiles count];y++)
	{
		[self addFile:[succeededFiles objectAtIndex:y] isSelfEncoded:YES];
	}*/

	[progressPanel endSheet];
	[progressPanel release];
	progressPanel = nil;

	if (result == 0)
	{
		NSString *finishMessage;
	
		if ([inputFiles count] > 1)
			finishMessage = [NSString stringWithFormat:NSLocalizedString(@"Finished converting %ld files", nil),(long)[inputFiles count]];
		else
			finishMessage = NSLocalizedString(@"Finished converting 1 file", nil);
		
		[[NSNotificationCenter defaultCenter] postNotificationName:@"growlFinishedConverting" object:finishMessage];
	}
	else if (result == 1)
	{
		[self performSelectorOnMainThread:@selector(showConvertFailAlert:) withObject:errorString waitUntilDone:YES];
	}

	[pool release];
	pool = nil;
}

//Show an alert if some files failed to be converted
- (void)showConvertFailAlert:(NSString *)errorString
{
	MCAlert *alert = [[[MCAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
		
	if ([errorString rangeOfString:@"\n"].length > 0)
		[alert setMessageText:NSLocalizedString(@"Media Converter failed to encode some files", nil)];
	else
		[alert setMessageText:NSLocalizedString(@"Media Converter failed to encode one file", nil)];
		
	NSArray *errorParts = [errorString componentsSeparatedByString:@"\nMCLog:"];
	NSString *fileErrors = [errorParts objectAtIndex:0];
	[alert setInformativeText:fileErrors];
	
	[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	
	if ([errorParts count] > 1)
	{
		NSString *ffmpegLog = [errorParts objectAtIndex:1];
		[alert setDetails:ffmpegLog];
	}
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

//Use some c to get the real path
- (NSString *)getRealPath:(NSString *)inPath
{
	char first = [inPath characterAtIndex:0];
	
	if (first != '/')
		return inPath;

	NSString *extension = [inPath pathExtension];
	if ([[extension lowercaseString] isEqualTo:@"webloc"])
		return [[NSDictionary dictionaryWithContentsOfFile:inPath] objectForKey:@"URL"];
	else if ([[extension lowercaseString] isEqualTo:@"url"])
		return [MCCommonMethods stringWithContentsOfFile:inPath];

	CFStringRef resolvedPath = nil;
	CFURLRef url = CFURLCreateWithFileSystemPath(NULL, (CFStringRef)inPath, kCFURLPOSIXPathStyle, NO);
	
	if (url != NULL) 
	{
		FSRef fsRef;
		
		if (CFURLGetFSRef(url, &fsRef)) 
		{
			Boolean targetIsFolder, wasAliased;
			
			if (FSResolveAliasFile (&fsRef, true, &targetIsFolder, &wasAliased) == noErr && wasAliased) 
			{
				CFURLRef resolvedurl = CFURLCreateFromFSRef(NULL, &fsRef);
				
				if (resolvedurl != NULL) 
				{
					resolvedPath = CFURLCopyFileSystemPath(resolvedurl, kCFURLPOSIXPathStyle);
					CFRelease(resolvedurl);
				}
			}
		}
	
		CFRelease(url);
	}
	
	if ((NSString *)resolvedPath)
		return (NSString *)resolvedPath;
	else
		return inPath;
}

//Check for protected file types
- (BOOL)isProtected:(NSString *)path
{
	NSArray *protectedFileTypes = [NSArray arrayWithObjects:@"m4p", @"m4b", NSFileTypeForHFSTypeCode('M4P '), NSFileTypeForHFSTypeCode('M4B '), nil];
	
	return ([protectedFileTypes containsObject:[[path pathExtension] lowercaseString]] | [protectedFileTypes containsObject:NSFileTypeForHFSTypeCode([[[[MCCommonMethods defaultManager] fileAttributesAtPath:path traverseLink:YES] objectForKey:NSFileHFSTypeCode] longValue])]);
}

- (void)closeWindow
{
	[NSApp terminate:self];
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
	if ([mainWindow attachedSheet] && (aSelector == @selector(openFiles:) | aSelector == @selector(openURLs:) | aSelector == @selector(saveDocumentAs:) | aSelector == @selector(edit:)))
		return NO;
	
	return [super respondsToSelector:aSelector];
}

@end
