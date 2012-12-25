//
//  MCPresetManager.m
//  Media Converter
//
//  Created by Maarten Foukhar on 18-09-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCPresetManager.h"
#import "MCConverter.h"
#import "MCProgress.h"
#import "MCPopupButton.h"
#import "MCOptionsDelegate.h"
#import "NSArray_Extensions.h"
#import "NSString_Extensions.h"
#import "MCCheckBoxCell.h"
#import "NSNumber_Extensions.h"
#import "MCInstallPanel.h"
#import "MCActionButton.h"
#import "MCFilterDelegate.h"
#import "MCFilter.h"
#import <QuartzCore/QuartzCore.h>


@implementation MCPresetManager

static MCPresetManager *_defaultManager = nil;

- (id)init
{
	if (self = [super init])
	{
		viewMappings = [[NSArray alloc] initWithObjects:		@"-f",		//1
																@"-vcodec",	//2
																@"-b",		//3
																@"-s",		//4
																@"-r",		//5
																@"-acodec",	//6
																@"-ab",		//7
																@"-ar",		//8
		nil];
		
		extraOptionMappings = [[NSArray alloc] initWithObjects:	
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
		
		extraOptionDefaultValues = [[NSArray alloc] initWithObjects:	
																//Video
																[NSNumber numberWithInt:1],											// Keep Aspect
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
		
		darkBackground = NO;
		
		[NSBundle loadNibNamed:@"MCPresetManager" owner:self];
	}

	return self;
}

- (void)dealloc
{
	//Release our stuff
	[preferenceMappings release];
	[viewMappings release];
	[extraOptionMappings release];
	[extraOptionDefaultValues release];

	[super dealloc];
}

- (void)awakeFromNib
{
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	[defaultCenter addObserver:self selector:@selector(updatePreview:) name:@"MCUpdatePreview" object:nil];
	
	[self setupPopups];
}

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

+ (MCPresetManager *)defaultManager
{
	if (!_defaultManager)
		_defaultManager = [[MCPresetManager alloc] init];

	return _defaultManager;
}

- (void)editPresetForWindow:(NSWindow *)window withPresetPath:(NSString *)path didEndSelector:(SEL)selector
{
	didEndSelector = selector;
	
	NSDictionary *presetDictionary;
	
	if (path)
	{
		currentPresetPath = [path retain];
		presetDictionary = [NSDictionary dictionaryWithContentsOfFile:path];
	}
	else
	{
		presetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:	[NSArray array],			@"Encoder Options",
																		@"",						@"Extension",
																		[NSDictionary dictionary],	@"Extra Options",
																		@"",						@"Name",
																		@"1.3",						@"Version"
																		, nil];
	}

	[nameField setStringValue:[presetDictionary objectForKey:@"Name"]];
	[extensionField setStringValue:[presetDictionary objectForKey:@"Extension"]];
	
	NSArray *options = [presetDictionary objectForKey:@"Encoder Options"];

	[MCCommonMethods setViewOptions:[NSArray arrayWithObject:[presetsPanel contentView]] infoObject:options fallbackInfo:nil mappingsObject:viewMappings startCount:0];

	extraOptions = [[NSMutableDictionary alloc] initWithDictionary:[presetDictionary objectForKey:@"Extra Options"]];
		
	[MCCommonMethods setViewOptions:[NSArray arrayWithObjects:[presetsPanel contentView], DVDSettingsView, hardcodedSettingsView, nil] infoObject:extraOptions fallbackInfo:[NSDictionary dictionaryWithObjects:extraOptionDefaultValues forKeys:extraOptionMappings] mappingsObject:extraOptionMappings startCount:100];
	
	NSMutableArray *filters;
	
	if ([[presetDictionary allKeys] containsObject:@"Video Filters"])
		filters = [NSMutableArray arrayWithArray:[presetDictionary objectForKey:@"Video Filters"]];
	else
		filters = [NSMutableArray array];
	
	[(MCFilterDelegate *)[filterTableView delegate] setFilterOptions:filters];
	
	[self setSubtitleKind:nil];
	[self setHarcodedVisibility:nil];
		
	NSString *aspectString = [options objectForKey:@"-vf"];
		
	if (aspectString)
	{
		if ([aspectString rangeOfString:@"setdar="].length > 0 && [[aspectString componentsSeparatedByString:@"setdar="] count] > 1)
			[aspectRatioField setStringValue:[[aspectString componentsSeparatedByString:@"setdar="] objectAtIndex:1]];
		else
			aspectString = nil;
	}

	[aspectRatioButton setState:[[NSNumber numberWithBool:(aspectString != nil)] integerValue]];
		
	if ([options containsObject:[NSDictionary dictionaryWithObject:@"1" forKey:@"-ac"]])
		[modePopup selectItemAtIndex:0];
	else if ([options containsObject:[NSDictionary dictionaryWithObject:@"2" forKey:@"-ac"]])
		[modePopup selectItemAtIndex:1];
	else
		[modePopup selectItemAtIndex:3];
	
	[(MCOptionsDelegate *)[advancedTableView delegate] setOptions:options];
	[advancedTableView reloadData];
	
	[completeButton setTitle:NSLocalizedString(@"Save", nil)];
	
	[self updatePreview:nil];
	
	[NSApp beginSheet:presetsPanel modalForWindow:window modalDelegate:self didEndSelector:nil contextInfo:nil];
}

- (void)savePresetForWindow:(NSWindow *)window withPresetPath:(NSString *)path
{
	NSDictionary *presetDictionary = [[NSDictionary alloc] initWithContentsOfFile:path];
	NSString *name = [presetDictionary objectForKey:@"Name"];

	NSSavePanel *sheet = [NSSavePanel savePanel];
	[sheet setRequiredFileType:@"mcpreset"];
	[sheet setCanSelectHiddenExtension:YES];
	[sheet setMessage:NSLocalizedString(@"Choose a location to save the preset file", nil)];
	[sheet beginSheetForDirectory:nil file:[name stringByAppendingPathExtension:@"mcpreset"] modalForWindow:window modalDelegate:self didEndSelector:@selector(saveDocumentPanelDidEnd:returnCode:contextInfo:) contextInfo:presetDictionary];
}

- (void)saveDocumentPanelDidEnd:(NSSavePanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];

	if (returnCode == NSOKButton) 
	{
		NSString *error = NSLocalizedString(@"An unkown error occured", nil);
		BOOL result = [MCCommonMethods writeDictionary:(NSDictionary *)contextInfo toFile:[sheet filename] errorString:&error];
		[(NSDictionary *)contextInfo release];

		if (result == NO)
			[MCCommonMethods standardAlertWithMessageText:NSLocalizedString(@"Failed save preset file", nil) withInformationText:error withParentWindow:nil withDetails:nil];
	}
}

- (NSInteger)openPresetFiles:(NSArray *)paths
{
	NSInteger numberOfFiles = [paths count];
	NSMutableArray *names = [NSMutableArray array];
	NSMutableArray *dictionaries = [NSMutableArray array];

	NSInteger i;
	for (i = 0; i < numberOfFiles; i ++)
	{
		NSString *path = [paths objectAtIndex:i];
		NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:path];
			
		if (dictionary)
		{
			[names addObject:[dictionary objectForKey:@"Name"]];
			[dictionaries addObject:dictionary];
		}
	}
		
	NSInteger numberOfDicts = [dictionaries count];
	if (numberOfDicts == 0 | numberOfDicts < numberOfFiles)
	{
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			
		if (numberOfDicts == 0)
		{
			[alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
		}
		else
		{
			[alert addButtonWithTitle:NSLocalizedString(@"Continue", nil)];
			[alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
			[[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\E"];
		}
		
		NSString *warningString;
		NSString *detailsString;
			
		if ((numberOfFiles - numberOfDicts) > 1)
		{
			warningString = NSLocalizedString(@"Failed to open preset files.", nil);
			detailsString = NSLocalizedString(@"Try re-downloading or re-copying them.", nil);
		}
		else
		{
			warningString = [NSString stringWithFormat:NSLocalizedString(@"Failed to open '%@'.", nil), [[MCCommonMethods defaultManager] displayNameAtPath:[paths objectAtIndex:0]]];
			detailsString = NSLocalizedString(@"Try re-downloading or re-copying it.", nil);
		}
			
		if (numberOfDicts > 0)
			detailsString = [NSString stringWithFormat:NSLocalizedString(@"%@ Would you like to continue?", nil), detailsString];
		
		[alert setMessageText:warningString];
		[alert setInformativeText:detailsString];
		NSInteger result = [alert runModal];

		if (result != NSAlertFirstButtonReturn | numberOfDicts == 0)
		{
			return 0;
		}

	}
			
	[self installPresetsWithNames:names presetDictionaries:dictionaries];
	
	return [dictionaries count];
}

- (NSInteger)installPresetsWithNames:(NSArray *)names presetDictionaries:(NSArray *)dictionaries
{
	NSString *savePath = nil;

	BOOL editingPreset = (currentPresetPath && [[[NSDictionary dictionaryWithContentsOfFile:currentPresetPath] objectForKey:@"Name"] isEqualTo:[names objectAtIndex:0]]);

	if (editingPreset == YES)
	{
		savePath = currentPresetPath;
		
		NSDictionary *firstDictionary = [dictionaries objectAtIndex:0];
		NSString *newName = [firstDictionary objectForKey:@"Name"];
		NSString *oldName = [names objectAtIndex:0];
		
		if (![newName isEqualTo:oldName])
		{
			/*NSDictionary *preset = [NSDictionary dictionaryWithObjectsAndKeys:newName, @"Name", currentPresetPath, @"Path", nil];
			
			[presetsData replaceObjectAtIndex:[presetsTableView selectedRow] withObject:preset];
			[standardDefaults setObject:presetsData forKey:@"MCPresets"];*/
		}
	}

	if (!savePath)
	{
		MCInstallPanel *installPanel = [[[MCInstallPanel alloc] init] autorelease];
		[installPanel setTaskText:NSLocalizedString(@"Install Presets for:", nil)];
		NSString *applicationSupportFolder = [installPanel installLocation];
			
		NSFileManager *defaultManager = [MCCommonMethods defaultManager];
		NSString *folder = [applicationSupportFolder stringByAppendingPathComponent:@"Media Converter"];
			
		BOOL supportWritable = YES;
		NSString *error = NSLocalizedString(@"An unkown error occured", nil);
		
		if (![defaultManager fileExistsAtPath:folder])
			supportWritable = [MCCommonMethods createDirectoryAtPath:folder errorString:&error];
			
		if (supportWritable)
		{
			savePath = [folder stringByAppendingPathComponent:@"Presets"];
			
			if (![defaultManager fileExistsAtPath:savePath])
				supportWritable = [MCCommonMethods createDirectoryAtPath:savePath errorString:&error];
		}
		
		if (!supportWritable)
		{
			[MCCommonMethods standardAlertWithMessageText:NSLocalizedString(@"Failed to create 'Presets' folder", nil) withInformationText:error withParentWindow:nil withDetails:nil];
				
			return NSCancelButton;
		}
	}
	
	if (!editingPreset)
	{
		NSMutableArray *duplicatePresetNames = [NSMutableArray array];
	
		NSInteger i;
		for (i = 0; i < [names count]; i ++)
		{
			//NSString *name = [names objectAtIndex:i];
		
			//if ([[presetsData objectsForKey:@"Name"] containsObject:name])
			//	[duplicatePresetNames addObject:name];
		}
	
		if ([duplicatePresetNames count] > 0)
		{
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert addButtonWithTitle:NSLocalizedString(@"Replace", nil)];
			[alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
			[[alert window] setDefaultButtonCell:[[[alert buttons] objectAtIndex:1] cell]];
		
			NSString *warningString;
			NSString *detailsString;
		
			if ([duplicatePresetNames count] > 1)
			{
				warningString = NSLocalizedString(@"Some presets allready exist. Do you want to replace them?", nil);
				detailsString = NSLocalizedString(@"There are some presets with the same names. Replacing them will remove the presets with the same name.", nil);
			}
			else
			{
				warningString = [NSString stringWithFormat:NSLocalizedString(@"'%@' already exists. Do you want to replace it?", nil), [duplicatePresetNames objectAtIndex:0]];
				detailsString = NSLocalizedString(@"A preset with the same name already exists. Replacing it will remove the preset with the same name.", nil);
			}
		
			[alert setMessageText:warningString];
			[alert setInformativeText:detailsString];
			NSInteger result = [alert runModal];

			if (result == NSAlertFirstButtonReturn)
			{
				for (i = 0; i < [duplicatePresetNames count]; i ++)
				{
					//NSString *name = [duplicatePresetNames objectAtIndex:i];
					//NSDictionary *presetDictionary = [presetsData objectAtIndex:[presetsData indexOfObject:name forKey:@"Name"]];
					//[[MCCommonMethods defaultManager] removeFileAtPath:[presetDictionary objectForKey:@"Path"] handler:nil];
				}
			}
			else
			{
				return NSCancelButton;
			}
		}
	}
	
	NSInteger i;
	for (i = 0; i < [names count]; i ++)
	{
		NSString *name = [names objectAtIndex:i];
		
		// '/' in the Finder is in reality ':' took me a while to figure that out (failed to save the "iPod / iPhone" dict)
		NSMutableString *mString = [name mutableCopy];
		[mString replaceOccurrencesOfString:@"/" withString:@":" options:NSCaseInsensitiveSearch range:(NSRange){0,[mString length]}];
		name = [NSString stringWithString:[mString autorelease]];
		
		NSDictionary *dictionary = [dictionaries objectAtIndex:i];
		NSString *filePath;
		
		if (editingPreset)
			filePath = currentPresetPath;
		else
			filePath = [MCCommonMethods uniquePathNameFromPath:[[savePath stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"mcpreset"] withSeperator:@" "];
		
		NSString *error = NSLocalizedString(@"An unkown error occured", nil);
		BOOL result = [MCCommonMethods writeDictionary:dictionary toFile:filePath errorString:&error];
		
		if (result == NO)
		{
			[MCCommonMethods standardAlertWithMessageText:NSLocalizedString(@"Failed install preset file", nil) withInformationText:error withParentWindow:nil withDetails:nil];
		
			return NSCancelButton;
		}
	}
		
	//[self reloadPresets];
	
	return NSOKButton;
}

- (void)setDelegate:(id)del
{
	delegate = del;
}

- (NSMutableDictionary *)presetDictionary
{
	NSMutableDictionary *presetDictionary;
	NSString *name;
		
	if (!currentPresetPath)
	{
		presetDictionary = [NSMutableDictionary dictionary];
		name = [nameField stringValue];
	}
	else
	{
		presetDictionary = [NSMutableDictionary dictionaryWithContentsOfFile:currentPresetPath];
		name = [NSString stringWithString:[presetDictionary objectForKey:@"Name"]];
	}
	
	[presetDictionary setObject:[nameField stringValue] forKey:@"Name"];
	[presetDictionary setObject:@"1.3" forKey:@"Version"];
	[presetDictionary setObject:[extensionField stringValue] forKey:@"Extension"];
	[presetDictionary setObject:[(MCOptionsDelegate *)[advancedTableView delegate] options] forKey:@"Encoder Options"];
	[presetDictionary setObject:extraOptions forKey:@"Extra Options"];
	[presetDictionary setObject:[[filterTableView delegate] filterOptions] forKey:@"Video Filters"];
	
	return presetDictionary;
}

//////////////////////////
// Preset panel actions //
//////////////////////////

#pragma mark -
#pragma mark •• Preset panel actions

- (IBAction)toggleAdvancedView:(id)sender
{
	BOOL shouldExpand = ([sender state] == NSOnState);
	
	NSRect windowFrame = [presetsPanel frame];
	NSInteger newHeight = windowFrame.size.height;
	NSInteger newY = windowFrame.origin.y;

	if (shouldExpand)
	{
		newHeight = newHeight + 194;
		newY = newY - 194;
	}
	else
	{
		newHeight = newHeight - 194;
		newY = newY + 194;
	}
	
	if (shouldExpand)
		[presetsPanel setFrame:NSMakeRect(windowFrame.origin.x, newY, windowFrame.size.width, newHeight) display:YES animate:YES];
	
	[[advancedTableView enclosingScrollView] setHidden:(!shouldExpand)];
	[advancedAddButton setHidden:(!shouldExpand)];
	[advancedDeleteButton setHidden:(!shouldExpand)];
	[advancedBarButton setHidden:(!shouldExpand)];
	
	if (!shouldExpand)
		[presetsPanel setFrame:NSMakeRect(windowFrame.origin.x, newY, windowFrame.size.width, newHeight) display:YES animate:YES];
}

- (IBAction)setOption:(id)sender
{
	NSInteger index = [sender tag] - 1;
	NSString *option = [viewMappings objectAtIndex:index];
	NSString *settings = [sender objectValue];
	
	NSMutableArray *advancedOptions = [(MCOptionsDelegate *)[advancedTableView delegate] options];
	
	if ([sender isKindOfClass:[MCPopupButton class]])
	{
		if ([settings isEqualTo:@"none"])
		{
			NSString *object = [advancedOptions objectForKey:option];

			if (object)
			{
				NSInteger index = [advancedOptions indexOfObject:[NSDictionary dictionaryWithObject:object forKey:option]];
				[advancedOptions removeObjectAtIndex:index];
			}
			
			if ([option isEqualTo:@"-acodec"])
				[advancedOptions setObject:@"" forKey:@"-an"];
			else
				[advancedOptions setObject:@"" forKey:@"-vn"];
				
			[advancedTableView reloadData];
				
			return;
		}
		else if ([option isEqualTo:@"-acodec"])
		{
			NSInteger index = [advancedOptions indexOfObject:[NSDictionary dictionaryWithObject:@"" forKey:@"-an"]];
			
			if (index != NSNotFound)
				[advancedOptions removeObjectAtIndex:index];
		}
		else if ([option isEqualTo:@"-vcodec"])
		{
			NSInteger index = [advancedOptions indexOfObject:[NSDictionary dictionaryWithObject:@"" forKey:@"-vn"]];
			
			if (index != NSNotFound)
				[advancedOptions removeObjectAtIndex:index];
		}
	}
	else
	{
		if ([sender objectValue])
			settings = [sender stringValue];
	}

	[advancedOptions setObject:settings forKey:option];
	[advancedTableView reloadData];
}

- (IBAction)setExtraOption:(id)sender
{
	NSInteger index = [sender tag] - 101;
	NSString *option = [extraOptionMappings objectAtIndex:index];

	[extraOptions setObject:[sender objectValue] forKey:option];
	[advancedTableView reloadData];
	
	if ([sender tag] > 105 && [sender tag] < 122)
		[self updatePreview:nil];
}

- (IBAction)endSheet:(id)sender
{
	NSInteger tag = [sender tag];
	NSInteger result = (NSInteger)(tag != 98);
	
	if (result)
	{
		//Make sure the text fields are saved when ending the edit sheet
		[presetsPanel endEditingFor:nil];
	
		NSDictionary *newDictionary = [self presetDictionary];
		NSString *fileName = [newDictionary objectForKey:@"Name"];
		
		fileName = [fileName stringByReplacingOccurrencesOfString:@"/" withString:@":"];
	
		if (!currentPresetPath)
		{
			MCInstallPanel *installPanel = [[[MCInstallPanel alloc] init] autorelease];
			NSString *folder = [installPanel installLocation];
			folder = [folder stringByAppendingPathComponent:@"Media Converter"];
			folder = [folder stringByAppendingPathComponent:@"Presets"];
			NSString *path = [folder stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mcpreset", fileName]];
		
			currentPresetPath = [[MCCommonMethods uniquePathNameFromPath:path withSeperator:@" "] retain];
		}
	
		//Save the (new) dictionary
		[newDictionary writeToFile:currentPresetPath atomically:YES];
	
		NSString *oldFileName = [[currentPresetPath lastPathComponent] stringByDeletingPathExtension];

		if (![fileName isEqualTo:oldFileName])
		{
			NSString *newPresetPath = [[[currentPresetPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"mcpreset"];
			newPresetPath = [MCCommonMethods uniquePathNameFromPath:newPresetPath withSeperator:@" "];

			[MCCommonMethods moveItemAtPath:currentPresetPath toPath:newPresetPath error:nil];
		
			NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
			NSMutableArray *newPresets = [NSMutableArray arrayWithArray:[standardDefaults objectForKey:@"MCPresets"]];
			[newPresets replaceObjectAtIndex:[newPresets indexOfObject:currentPresetPath] withObject:newPresetPath];
			[standardDefaults setObject:newPresets forKey:@"MCPresets"];
		}
	}
	
	//Perform end selector, with 0 or 1 (a.k.a NSOkButton or NSCancelButton)
	[MCCommonMethods sendEndSelector:didEndSelector toObject:delegate withObject:self withReturnCode:result];

	[NSApp endSheet:presetsPanel];
	[presetsPanel orderOut:self];
	
	if (currentPresetPath)
	{
		[currentPresetPath release];
		currentPresetPath = nil;
	}

	[extraOptions release];
	extraOptions = nil;
}

// Video
#pragma mark -
#pragma mark •• - Video

- (IBAction)setAspect:(id)sender
{
	NSMutableArray *advancedOptions = [(MCOptionsDelegate *)[advancedTableView delegate] options];

	NSString *option = @"-vf";
	NSString *option2 = @"-aspect";
	NSString *settings = nil;
	NSString *settings2 = nil;
	
	if ([sender objectValue])
	{
		if (![[sender stringValue] isEqualTo:@""])
		{
			settings = [NSString stringWithFormat:@"setdar=%@", [sender stringValue]];
			settings2 = [sender stringValue];
		}
	}
		
	[advancedOptions setObject:settings forKey:option];
	[advancedOptions setObject:settings2 forKey:option2];
	[advancedTableView reloadData];
}

// Audio
#pragma mark -
#pragma mark •• - Audio

- (IBAction)setMode:(id)sender
{
	NSString *settings = nil;

	if ([sender indexOfSelectedItem] < 2)
	{
		settings = [NSString stringWithFormat:@"%i", [sender indexOfSelectedItem] + 1];
	}

	NSMutableArray *advancedOptions = [(MCOptionsDelegate *)[advancedTableView delegate] options];
	[advancedOptions setObject:settings forKey:@"-ac"];
	[advancedTableView reloadData];
}

// Subtitles
#pragma mark -
#pragma mark •• - Subtitles

- (IBAction)setSubtitleKind:(id)sender
{
	if (sender)
		[extraOptions setObject:[sender objectValue] forKey:@"Subtitle Type"];
	
	NSString *settings = [extraOptions objectForKey:@"Subtitle Type"];

	if (settings == nil)
		settings = @"";
	
	BOOL isDVD = ([settings isEqualTo:@"dvd"]);
	BOOL isHardcoded = ([settings isEqualTo:@"hard"]);
	
	NSArray *subviews = [subtitleSettingsView subviews];
	
	if ([subviews containsObject:DVDSettingsView])
		[DVDSettingsView removeFromSuperview];
	else if ([subviews containsObject:hardcodedSettingsView])
		[hardcodedSettingsView removeFromSuperview];
	
	if (isDVD | isHardcoded)
	{
		NSView *subview;
		if (isDVD)
			subview = DVDSettingsView;
		else
			subview = hardcodedSettingsView;

		[subview setFrame:NSMakeRect(0, [subtitleSettingsView frame].size.height - [subview frame].size.height, [subview frame].size.width, [subview frame].size.height)];
		[subtitleSettingsView addSubview:subview];
		
		[[self window] recalculateKeyViewLoop];
	}
}

// Subtitles
#pragma mark -
#pragma mark ••  -> Hardcoded

- (IBAction)setHarcodedVisibility:(id)sender
{
	NSInteger selectedIndex = [(MCPopupButton *)hardcodedVisiblePopup indexOfSelectedItem];
	
	//Seems when editing a preset from the main window, we have to try until we're woken from the NIB
	while (selectedIndex == -1)
		selectedIndex = [(MCPopupButton *)hardcodedVisiblePopup indexOfSelectedItem];
	
	if (selectedIndex < 2)
		[hardcodedMethodTabView selectTabViewItemAtIndex:selectedIndex];
		
	[hardcodedMethodTabView setHidden:(selectedIndex == 2)];

	if (sender != nil)
		[self setExtraOption:sender];
}

/////////////////////
// Preview actions //
/////////////////////

#pragma mark -
#pragma mark •• Preview actions

- (void)updatePreview:(NSNotification *)notif
{
	NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithObjects:extraOptionDefaultValues forKeys:extraOptionMappings];
	[settings addEntriesFromDictionary:extraOptions];
	
	NSString *backgroundName = @"Sintel-frame";
	if (darkBackground == YES)
		backgroundName = @"Sintel-frame-dark";
	
	NSImage *previewImage = [self previewBackgroundWithImage:[NSImage imageNamed:backgroundName] forSize:[previewImageView frame].size];
	NSSize imageSize = [previewImage size];
	NSImage *filterImage = [filterDelegate previewImageWithSize:imageSize];
	
	[previewImage lockFocus];
	[filterImage drawInRect:NSMakeRect(0, 0, imageSize.width, imageSize.height) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	
	[previewImage unlockFocus];
	
	if ([[settings objectForKey:@"Subtitle Type"] isEqualTo:@"hard"])
		previewImage = [MCCommonMethods overlayImageWithObject:NSLocalizedString(@"This is a scene from the movie Sintel watch it at: www.sintel.org<br><i>second line in italic</i>", nil) withSettings:settings inputImage:previewImage];
	
	[previewImageView setImage:previewImage];
	[previewImageView display];
}

- (IBAction)showPreview:(id)sender
{
	if ([previewPanel isVisible])
		[previewPanel orderOut:nil];
	else
		[previewPanel orderFront:nil];
}

- (void)reloadHardcodedPreview
{
	NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithObjects:extraOptionDefaultValues forKeys:extraOptionMappings];
	[settings addEntriesFromDictionary:extraOptions];
			
	NSImage *previewImage = [MCCommonMethods overlayImageWithObject:NSLocalizedString(@"This is a scene from the movie Sintel watch it at: www.sintel.org<br><i>second line in italic</i>", nil) withSettings:settings inputImage:[NSImage imageNamed:@"Sintel-frame"]];
	[previewImageView setImage:previewImage];
	[previewImageView display];
}

- (IBAction)toggleDarkBackground:(id)sender
{
	darkBackground = !darkBackground;
	
	[self updatePreview:nil];
}

- (NSImage *)previewBackgroundWithImage:(NSImage *)image forSize:(NSSize)size
{
	NSSize imageSize = [image size];
	CGFloat imageAspect = imageSize.width / imageSize.height;
	CGFloat outputAspect = size.width / size.height;
	NSImage *outputImage = [[NSImage alloc] initWithSize:size];
	
	// Height is smaller
	if (outputAspect > imageAspect)
	{
		CGFloat y = ((size.width / imageAspect) - size.height) / 2;
		
		[outputImage lockFocus];
		
		[image drawInRect:NSMakeRect(0, 0 - y, size.width, size.height + y) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
		
		[outputImage unlockFocus];
	}
	else
	{
		CGFloat x = ((size.height * imageAspect) - size.width) / 2;

		[outputImage lockFocus];
		
		[image drawInRect:NSMakeRect(0 - x, 0, size.width + x, size.height) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
		
		[outputImage unlockFocus];
	}
	
	return [outputImage autorelease];
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (BOOL)updateForKey:(NSString *)key withProperty:(id)property
{
	if ([viewMappings containsObject:key])
	{
		NSInteger tag = [viewMappings indexOfObject:key] + 1;
		
		id control = [[presetsPanel contentView] viewWithTag:tag];
		
		if (!control)
		{
			NSArray *subViews = [[presetsPanel contentView] subviews];
			NSInteger i;
			for (i = 0; i < [subViews count]; i ++)
			{
				id subView = [subViews objectAtIndex:i];
				
				if ([subView isKindOfClass:[NSTabView class]])
				{
					NSArray *tabViewItems = [(NSTabView *)subView tabViewItems];
					NSInteger x;
					for (x = 0; x < [tabViewItems count]; x ++)
					{
						control = [[[tabViewItems objectAtIndex:x] view] viewWithTag:tag];
				
						if (control)
							break;
					}
				}
			}
		}
		
		if (control)
		{
			[MCCommonMethods setProperty:property forControl:control];
			
			if ([[control cell] respondsToSelector:@selector(dependChild)])
				[MCCommonMethods setProperty:property forControl:[[control cell] dependChild]];
		}
		
		return YES;
	}
	
	return NO;
}

- (void)setupPopups
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	MCConverter *converter = [[MCConverter alloc] init];
	[containerPopUp setArray:[converter getFormats]];
	
	NSArray *videoCodecs = [NSArray arrayWithArray:[converter getCodecsOfType:@"V"]];
	NSMutableArray *audioCodecs = [NSMutableArray arrayWithArray:[converter getCodecsOfType:@"A"]];
	NSArray *codecsNames = [NSArray arrayWithObjects:NSLocalizedString(@"Disable", nil), NSLocalizedString(@"Passthrough", nil), @"", nil];
	NSArray *codecsFormats = [NSArray arrayWithObjects:@"none", @"copy", @"", nil];
	
	NSMutableArray *videoPopupItems = [MCCommonMethods popupArrayWithNames:codecsNames forFormats:codecsFormats];
	NSMutableArray *audioPopupItems = [NSMutableArray arrayWithArray:videoPopupItems];
	
	[videoPopupItems addObjectsFromArray:videoCodecs];
	[audioPopupItems addObjectsFromArray:audioCodecs];
	
	[videoFormatPopUp setArray:videoPopupItems];
	[audioFormatPopUp setArray:audioPopupItems];
	
	NSArray *subtitleNames = [NSArray arrayWithObjects:		NSLocalizedString(@"Disable", nil), 
															@"",
															NSLocalizedString(@"Hardcoded", nil),
															NSLocalizedString(@"DVD MPEG2", nil),
															NSLocalizedString(@"MPEG4 / 3GP", nil),
															NSLocalizedString(@"Matroska (SRT)", nil),
															NSLocalizedString(@"Ogg (Kate)", nil),
															NSLocalizedString(@"SRT (External)", nil),
	nil];
	
	NSArray *subtitleFormats = [NSArray arrayWithObjects:	@"none",
															@"",
															@"hard",
															@"dvd",
															@"mp4",
															@"mkv",
															@"kate",
															@"srt",
	nil];
	
	[subtitleFormatPopUp setArray:[MCCommonMethods popupArrayWithNames:subtitleNames forFormats:subtitleFormats]];
	
	NSArray *horizontalAlignments = [MCCommonMethods defaultHorizontalPopupArray];
	[hAlignFormatPopUp setArray:horizontalAlignments];
	[hardcodedHAlignPopup setArray:horizontalAlignments];
	
	NSArray *verticalAlignments = [MCCommonMethods defaultVerticalPopupArray];
	[vAlignFormatPopUp setArray:verticalAlignments];
	[hardcodedVAlignPopup setArray:verticalAlignments];
	
	NSArray *textVisibleNames = [NSArray arrayWithObjects:NSLocalizedString(@"Text Border", nil), NSLocalizedString(@"Surounding Box", nil), NSLocalizedString(@"None", nil), nil];
	NSArray *textVisibleFormats = [NSArray arrayWithObjects:@"border", @"box", @"none", nil];
	[hardcodedVisiblePopup setArray:[MCCommonMethods popupArrayWithNames:textVisibleNames forFormats:textVisibleFormats]];
	
	[hardcodedFontPopup removeAllItems];
	[hardcodedFontPopup addItemWithTitle:NSLocalizedString(@"Loading…", nil)];
	[hardcodedFontPopup setEnabled:NO];
	[hardcodedFontPopup setDelayed:YES];
	
	[fontPopup removeAllItems];
	[fontPopup addItemWithTitle:NSLocalizedString(@"Loading…", nil)];
	[fontPopup setEnabled:NO];
	[fontPopup setDelayed:YES];
	
	[NSThread detachNewThreadSelector:@selector(setupSlowPopups) toTarget:self withObject:nil];
	
	[converter release];
	converter = nil;
	
	[pool release];
}

- (void)setupSlowPopups
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSArray *fontFamilies = [[NSFontManager sharedFontManager] availableFontFamilies];
	NSMutableArray *hardcodedFontDictionaries = [NSMutableArray array];
	[hardcodedFontPopup removeAllItems];

	NSInteger i;
	for (i = 0; i < [fontFamilies count]; i ++)
	{
		NSString *fontName = [fontFamilies objectAtIndex:i];
		NSFont *newFont = [NSFont fontWithName:fontName size:12.0];
				
		if (newFont)
		{
			NSAttributedString *titleString;
			NSMutableDictionary *titleAttr = [NSMutableDictionary dictionary];
			[titleAttr setObject:newFont forKey:NSFontAttributeName];
			titleString = [[NSAttributedString alloc] initWithString:[newFont displayName] attributes:titleAttr];

			[hardcodedFontDictionaries addObject:[NSDictionary dictionaryWithObjectsAndKeys:titleString, @"Name", fontName, @"Format", nil]];
				
			[titleString release];
			titleString = nil;
		}
		else
		{
			[hardcodedFontDictionaries addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:NSLocalizedString(@"%@ (no preview)", nil), fontName], @"Name", fontName, @"Format", nil]];
		}
	}

	[hardcodedFontPopup setArray:hardcodedFontDictionaries];
	[hardcodedFontPopup setDelayed:NO];
	[hardcodedFontPopup setEnabled:YES];
	
	NSFileManager *defaultManager = [MCCommonMethods defaultManager];
	NSString *fontPath = [[NSUserDefaults standardUserDefaults] objectForKey:@"MCFontFolderPath"];
		
	NSMutableArray *fontDictionaries = [NSMutableArray array];
	NSArray *fonts = [defaultManager subpathsAtPath:fontPath];
	[fontPopup removeAllItems];

	NSInteger y;
	for (y = 0; y < [fonts count]; y ++)
	{
		NSString *font = [fonts objectAtIndex:y];
			
		if ([[font pathExtension] isEqualTo:@"ttf"])
		{
			NSString *fontName = [font stringByDeletingPathExtension];
			NSFont *newFont = [NSFont fontWithName:fontName size:12.0];
				
			if (newFont)
			{
				NSAttributedString *titleString;
				NSMutableDictionary *titleAttr = [NSMutableDictionary dictionary];
				[titleAttr setObject:newFont forKey:NSFontAttributeName];
				titleString = [[NSAttributedString alloc] initWithString:[newFont displayName] attributes:titleAttr];

				[fontDictionaries addObject:[NSDictionary dictionaryWithObjectsAndKeys:titleString, @"Name", fontName, @"Format", nil]];
				
				[titleString release];
				titleString = nil;
			}
			else
			{
				[fontDictionaries addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:NSLocalizedString(@"%@ (no preview)", nil), fontName], @"Name", fontName, @"Format", nil]];
			}
		}
	}

	[fontPopup setArray:fontDictionaries];
	[fontPopup setDelayed:NO];
	[fontPopup setEnabled:YES];
	
	[pool release];
}

- (NSDictionary *)defaults
{
	return [NSDictionary dictionaryWithObjects:extraOptionDefaultValues forKeys:extraOptionMappings];
}

@end
