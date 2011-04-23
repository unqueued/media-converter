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
#import "MCAlert.h"

@implementation MCMainController

+ (void)initialize
{
	NSDictionary *infoDictionary = [[NSBundle mainBundle] localizedInfoDictionary];

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; // standard user defaults
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
	NSString *error = NSLocalizedString(@"An unkown error occured", nil);

	if ([MCCommonMethods OSVersion] < 0x1050)
		[presetPopUp setBezelStyle:NSRoundedBezelStyle];

	[NSApp setDelegate:self];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closeWindow) name:NSWindowWillCloseNotification object:mainWindow];

	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];

	[presetPopUp removeAllItems];
	
	NSFileManager *defaultManager = [MCCommonMethods defaultManager];
	NSString *folder = @"/Library/Application Support/Media Converter/Presets";
	NSString *supportFolder = [folder stringByDeletingLastPathComponent];
	
	NSString *userSupportFolder = [@"~/Library/Application Support/Media Converter" stringByExpandingTildeInPath];
	NSString *userFolder = [userSupportFolder stringByAppendingPathComponent:@"Presets"];
	
	NSArray *presets = [standardDefaults objectForKey:@"MCPresets"];
	
	BOOL hasSupportFolder = ([defaultManager fileExistsAtPath:folder] | [defaultManager fileExistsAtPath:userFolder]);
	
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
				[MCCommonMethods standardAlertWithMessageText:NSLocalizedString(@"Failed to copy 'Presets' folder", nil) withInformationText:error withParentWindow:nil];
				
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

	[self update];
	
	[[MCGrowlController alloc] init];
}

- (void)update
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

///////////////////////
// Interface actions //
///////////////////////

#pragma mark -
#pragma mark •• Interface actions

- (IBAction)setPresetPopup:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setObject:[sender objectValue] forKey:@"MCSelectedPreset"];
}

//////////////////
// Menu actions //
//////////////////

#pragma mark -
#pragma mark •• Menu actions

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

- (IBAction)openURLs:(id)sender
{
	[NSApp beginSheet:locationsPanel modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(openURLsPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
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

//Open preferences
- (IBAction)openPreferences:(id)sender
{
	if (preferences == nil)
	{
		preferences = [[MCPreferences alloc] init];
		[preferences setDelegate:self];
	}
	
	[preferences showPreferences];
}

- (IBAction)goToSite:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://media-converter.sourceforge.net"]];
}

- (IBAction)downloadSource:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://sourceforge.net/projects/media-converter/files/media-converter/1.1/"]];
}

- (IBAction)makeDonation:(id)sender
{
	[[NSWorkspace sharedWorkspace] openFile:[[[NSBundle mainBundle] pathForResource:@"Donation" ofType:@""] stringByAppendingPathComponent:@"donate.html"]];
}

//Locations actions

- (IBAction)endOpenLocations:(id)sender
{
	[NSApp endSheet:locationsPanel returnCode:[sender tag]];
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
	
	NSFileManager *defaultManager = [MCCommonMethods defaultManager];
	NSMutableArray *files = [NSMutableArray array];
	NSInteger protectedCount = 0;
	
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
					if ([[MCConverter alloc] isMediaFile:realPathName])
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
					if ([[MCConverter alloc] isMediaFile:realPath])
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
	
	inputFiles = [[NSArray alloc] initWithArray:files];
		
	cancelAddingFiles = NO;

	//Stop being the observer
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"cancelAdding" object:nil];

	[self performSelectorOnMainThread:@selector(showAlert:) withObject:[NSNumber numberWithInteger:protectedCount] waitUntilDone:NO];

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

			[MCCommonMethods standardAlertWithMessageText:message withInformationText:information withParentWindow:mainWindow];
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
	
	NSInteger result = [converter batchConvert:inputFiles toDestination:path withOptions:options errorString:&errorString];

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

@end
