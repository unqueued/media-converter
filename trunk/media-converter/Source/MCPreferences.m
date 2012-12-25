//
//  MCPreferences.m
//  Media Converter
//
//  Created by Maarten Foukhar on 25-01-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCPreferences.h"
#import "MCConverter.h"
#import "MCProgress.h"
#import "MCPopupButton.h"
#import "MCOptionsDelegate.h";
#import "NSArray_Extensions.h"
#import "MCCheckBoxCell.h"
#import "NSNumber_Extensions.h"
#import "MCInstallPanel.h"
#import "MCActionButton.h"
#import "MCFilterDelegate.h"
#import "MCFilter.h"
#import <QuartzCore/QuartzCore.h>
#import "MCPresetManager.h"

@implementation MCPreferences

- (id)init
{
	if (self = [super init])
	{
		preferenceMappings = [[NSArray alloc] initWithObjects:	@"MCUseSoundEffects",			//1
																@"MCSaveMethod",				//2
																@"MCInstallMode",				//3
																@"MCDebug",						//4
																@"MCUseCustomFFMPEG",			//5
																@"MCCustomFFMPEG",				//6
																@"MCSubtitleLanguage",			//7
		nil];
		
		itemsList = [[NSMutableDictionary alloc] init];
		presetsData = [[NSMutableArray alloc] init];
		loaded = NO;
		
		[NSBundle loadNibNamed:@"MCPreferences" owner:self];
	}

	return self;
}

- (void)dealloc
{
	//Release our stuff
	[preferenceMappings release];
	[itemsList release];
	[presetsData release];
	[toolbar release];

	[super dealloc];
}

- (void)awakeFromNib
{
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	NSFileManager *defaultManager = [MCCommonMethods defaultManager];
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	
	[defaultCenter addObserver:self selector:@selector(tableViewSelectionDidChange:) name:@"MCListSelected" object:presetsTableView];
	[defaultCenter addObserver:self selector:@selector(installModeChanged:) name:@"MCInstallModeChanged" object:nil];
	
	//General
	NSString *temporaryFolder = [standardDefaults objectForKey:@"MCSaveLocation"];
	[saveFolderPopUp insertItemWithTitle:[defaultManager displayNameAtPath:temporaryFolder] atIndex:0];
	NSImage *folderImage = [[NSWorkspace sharedWorkspace] iconForFile:temporaryFolder];
	[folderImage setSize:NSMakeSize(16,16)];
	[[saveFolderPopUp itemAtIndex:0] setImage:folderImage];
	[[saveFolderPopUp itemAtIndex:0] setToolTip:[standardDefaults objectForKey:@"MCSaveLocation"]];
	
	NSMutableArray *subtitleLanguages = [NSMutableArray array];
	NSDictionary *languageDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Languages" ofType:@"plist"]];
	NSArray *allKeys = [languageDict allKeys];
	
	NSInteger x;
	for (x = 0; x < [allKeys count]; x ++)
	{
		NSString *currentKey = [allKeys objectAtIndex:x];
		NSString *currentObject = [languageDict objectForKey:currentKey];
		NSDictionary *newDict = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(currentKey, nil), @"Name", currentObject, @"Format", nil];
		[subtitleLanguages addObject:newDict];
	}
	
	[subtitleLanguagePopup setArray:subtitleLanguages];
	
	[self reloadPresets];
	
	[presetsTableView registerForDraggedTypes:[NSArray arrayWithObject:@"NSGeneralPboardType"]];
	
	[presetsTableView setTarget:self];
	[presetsTableView setDoubleAction:@selector(edit:)];
	
	[addTableView setTarget:self];
	[addTableView setDoubleAction:@selector(endAddSheet:)];
	
	[presetsActionButton setDelegate:self];
	[presetsActionButton addMenuWithTitle:NSLocalizedString(@"Edit Preset…", nil) withSelector:@selector(edit:)];
	[presetsActionButton addMenuWithTitle:NSLocalizedString(@"Duplicate Preset", nil) withSelector:@selector(duplicate:)];
	[presetsActionButton addMenuWithTitle:NSLocalizedString(@"Save Preset…", nil) withSelector:@selector(saveDocumentAs:)];
	
	//Load the options for our views
	[MCCommonMethods setViewOptions:[NSArray arrayWithObjects:generalView, presetsView, advancedView, nil] infoObject:[NSUserDefaults standardUserDefaults] fallbackInfo:nil mappingsObject:preferenceMappings startCount:0];
	
	// Store the saved frame for later use
	NSString *savedFrameString = [[self window] stringWithSavedFrame];
	
	[self setupToolbar];
	[toolbar setSelectedItemIdentifier:[standardDefaults objectForKey:@"MCSavedPrefView"]];
	[self toolbarAction:[toolbar selectedItemIdentifier]];

	[defaultCenter addObserver:self selector:@selector(saveFrame) name:NSWindowWillCloseNotification object:nil];
	
	[[self window] setFrameFromString:savedFrameString];
	
	loaded = YES;
}

- (void)saveFrame
{
	[[self window] saveFrameUsingName:@"Preferences"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

/////////////////
// Main action //
/////////////////

#pragma mark -
#pragma mark •• Main action

- (void)setDelegate:(id)del
{
	delegate = del;
}

//////////////////////
// PrefPane actions //
//////////////////////

#pragma mark -
#pragma mark •• PrefPane actions

- (void)showPreferences;
{
	[[self window] makeKeyAndOrderFront:self];
}

- (IBAction)setPreferenceOption:(id)sender
{
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	NSInteger tag = [sender tag];
	id object = [sender objectValue];

	if (tag == 2 && [sender indexOfSelectedItem] == 4)
	{
		NSOpenPanel *sheet = [NSOpenPanel openPanel];
		[sheet setCanChooseFiles:NO];
		[sheet setCanChooseDirectories:YES];
		[sheet setAllowsMultipleSelection:NO];
		[sheet beginSheetForDirectory:nil file:nil types:nil modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(saveLocationOpenPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
	else
	{
		[standardDefaults setObject:object forKey:[preferenceMappings objectAtIndex:tag - 1]];
	}
}

//General

#pragma mark -
#pragma mark •• - General

- (void)saveLocationOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];

	if (returnCode == NSOKButton)
	{
		NSFileManager *defaultManager = [MCCommonMethods defaultManager];
		[saveFolderPopUp removeItemAtIndex:0];
		NSString *temporaryFolder = [sheet filename];
		[saveFolderPopUp insertItemWithTitle:[defaultManager displayNameAtPath:temporaryFolder] atIndex:0];
		NSImage *folderImage = [[NSWorkspace sharedWorkspace] iconForFile:temporaryFolder];
		[folderImage setSize:NSMakeSize(16,16)];
		NSMenuItem *item = [saveFolderPopUp itemAtIndex:0];
		[item setImage:folderImage];
		[item setToolTip:[[temporaryFolder stringByDeletingLastPathComponent] stringByAppendingPathComponent:[defaultManager displayNameAtPath:temporaryFolder]]];
		[saveFolderPopUp selectItemAtIndex:0];
	
		[standardDefaults setObject:[sheet filename] forKey:@"MCSaveLocation"];
		[standardDefaults setObject:[NSNumber numberWithInteger:0] forKey:@"MCSaveMethod"];
	}
	else
	{
		[saveFolderPopUp selectItemAtIndex:[[standardDefaults objectForKey:@"MCSaveMethod"] integerValue]];
	}
}

// PrefPane - Presets

#pragma mark -
#pragma mark •• - Presets

- (IBAction)delete:(id)sender
{
	NSString *alertMessage;
	NSString *alertDetails;
	
	NSArray *selectedObjects = [MCCommonMethods allSelectedItemsInTableView:presetsTableView fromArray:presetsData];
	
	if ([selectedObjects count] > 0)
	{
		if ([selectedObjects count] > 1)
		{
			alertMessage = NSLocalizedString(@"Are you sure you want to remove the selected presets?", nil);
			alertDetails = NSLocalizedString(@"You won't be able to convert files using these presets in the future", nil);
		}
		else
		{
			alertMessage = NSLocalizedString(@"Are you sure you want to remove the selected preset?", nil);
			alertDetails = NSLocalizedString(@"You won't be able to convert files using this preset in the future", nil);
		}
	
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedString(@"Yes", Localized)];
		[alert addButtonWithTitle:NSLocalizedString(@"No", Localized)];
		[alert setMessageText:alertMessage];
		[alert setInformativeText:alertDetails];
		[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(removeAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
}

- (void)removeAlertDidEnd:(NSWindow*)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertFirstButtonReturn)
	{
		NSArray *selectedObjects = [MCCommonMethods allSelectedItemsInTableView:presetsTableView fromArray:presetsData];
		NSInteger i;
		for (i = 0; i < [selectedObjects count]; i ++)
		{
			NSString *presetPath = [selectedObjects objectAtIndex:i];
			[[MCCommonMethods defaultManager] removeFileAtPath:presetPath handler:nil];
		}
	
		[self reloadPresets];
		[presetsTableView deselectAll:nil];
	}
}

- (IBAction)addPreset:(id)sender
{	
	[NSApp beginSheet:addPanel modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(addPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)addPanelDidEnd:(NSWindow*)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[panel orderOut:self];

	if (returnCode == NSOKButton)
	{
		NSInteger selectedRow = [addTableView selectedRow];
		
		if (selectedRow == 0)
		{
			NSOpenPanel *sheet = [NSOpenPanel openPanel];
			[sheet setCanChooseFiles:YES];
			[sheet setCanChooseDirectories:NO];
			[sheet setAllowsMultipleSelection:YES];
			[sheet beginSheetForDirectory:nil file:nil types:[NSArray arrayWithObject:@"mcpreset"] modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(presetOpenPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
		}
		else
		{
			MCPresetManager *presetManager = [[MCPresetManager alloc] init];
			[presetManager setDelegate:self];
			[presetManager editPresetForWindow:[self window] withPresetPath:nil didEndSelector:@selector(presetManagerEnded:returnCode:)];
		}
	}
}

- (void)presetOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
		[[MCPresetManager defaultManager] openPresetFiles:[sheet filenames]];
	
	[sheet orderOut:self];
}

- (IBAction)endAddSheet:(id)sender
{
	[NSApp endSheet:addPanel returnCode:[sender tag]];
}

- (IBAction)edit:(id)sender
{
	NSInteger selectedRow = [presetsTableView selectedRow];
	
	if (selectedRow > - 1)
	{
		NSString *presetPath = [presetsData objectAtIndex:selectedRow];

		MCPresetManager *presetManager = [[MCPresetManager alloc] init];
		[presetManager setDelegate:self];
		[presetManager editPresetForWindow:[self window] withPresetPath:presetPath didEndSelector:@selector(presetManagerEnded:returnCode:)];
	}
}

- (void)presetManagerEnded:(MCPresetManager *)manager returnCode:(NSInteger)returnCode
{
	if (returnCode == NSOKButton)
	{
		[self reloadPresets];
	}
}

- (IBAction)duplicate:(id)sender
{
	NSInteger selRow = [presetsTableView selectedRow];
	
	if (selRow > -1)
	{
		NSArray *selectedObjects = [MCCommonMethods allSelectedItemsInTableView:presetsTableView fromArray:presetsData];
		[presetsTableView deselectAll:nil];
		
		NSInteger i;
		for (i = 0; i < [selectedObjects count]; i ++)
		{
			NSString *path = [selectedObjects objectAtIndex:i];

			NSMutableDictionary *presetDictionary = [NSMutableDictionary dictionaryWithContentsOfFile:path];
			NSString *newPath = [MCCommonMethods uniquePathNameFromPath:path withSeperator:@" "];
			NSString *newName = [[newPath lastPathComponent] stringByDeletingPathExtension];
			[presetDictionary setObject:newName forKey:@"Name"];
		
			NSString *error = nil;
			BOOL result = [MCCommonMethods writeDictionary:presetDictionary toFile:newPath errorString:&error];
		
			if (result == NO)
			{
				[MCCommonMethods standardAlertWithMessageText:NSLocalizedString(@"Failed duplicate to preset file", nil) withInformationText:error withParentWindow:nil withDetails:nil];
			}
			else
			{
				[self reloadPresets];
				NSInteger lastRow = [presetsData count] - 1;
				[presetsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:lastRow] byExtendingSelection:YES];
			}
		}
	}
}

- (IBAction)saveDocumentAs:(id)sender
{
	NSInteger selectedRow = [presetsTableView selectedRow];
	
	if (selectedRow > - 1)
	{
		NSString *presetPath = [presetsData objectAtIndex:selectedRow];
		
		[[MCPresetManager defaultManager] savePresetForWindow:[self window] withPresetPath:presetPath];
	}
}

- (void)savePreset
{
	NSInteger selectedRow = [presetsTableView selectedRow];
	
	if (selectedRow > - 1)
	{
		NSString *presetPath = [presetsData objectAtIndex:selectedRow];
		
		[[MCPresetManager defaultManager] savePresetForWindow:[self window] withPresetPath:presetPath];
	}
}

- (IBAction)goToPresetSite:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://media-converter.sourceforge.net/presets.html"]];
}

// PrefPane - Advanced

#pragma mark -
#pragma mark •• - Advanced

- (IBAction)chooseFFMPEG:(id)sender
{
	[NSApp runModalForWindow:commandPanel];
	[commandPanel orderOut:self];
	//[self setupPopups];
	//[NSThread detachNewThreadSelector:@selector(setupPopups) toTarget:self withObject:nil];
}

- (IBAction)rebuildFonts:(id)sender
{
	[self updateFontListForWindow:[self window]];
}

- (IBAction)ok:(id)sender
{
	[NSApp stopModalWithCode:NSOKButton];
}

- (IBAction)cancel:(id)sender
{
	[NSApp stopModalWithCode:NSCancelButton];
}

/////////////////////
// Toolbar actions //
/////////////////////

#pragma mark -
#pragma mark •• Toolbar actions

- (NSToolbarItem *)createToolbarItemWithName:(NSString *)name
{
	NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:name];
	[toolbarItem autorelease];
	[toolbarItem setLabel:NSLocalizedString(name, Localized)];
	[toolbarItem setPaletteLabel:[toolbarItem label]];
	[toolbarItem setImage:[NSImage imageNamed:name]];
	[toolbarItem setTarget:self];
	[toolbarItem setAction:@selector(toolbarAction:)];
	[itemsList setObject:name forKey:name];

	return toolbarItem;
}

- (void)setupToolbar
{
	toolbar = [[NSToolbar alloc] initWithIdentifier:@"mainToolbar"];
	[toolbar autorelease];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:NO];
	[toolbar setAutosavesConfiguration:NO];
	[[self window] setToolbar:toolbar];
}

- (void)toolbarAction:(id)object
{
	id itemIdentifier;

	if ([object isKindOfClass:[NSToolbarItem class]])
		itemIdentifier = [object itemIdentifier];
	else
		itemIdentifier = object;
	
	id view = [self myViewWithIdentifier:itemIdentifier];
	
	[[self window] setContentView:[[[NSView alloc] initWithFrame:[view frame]] autorelease]];
	[self resizeWindowOnSpotWithRect:[view frame]];
	[[self window] setContentView:view];
	[[self window] setTitle:NSLocalizedString(itemIdentifier, Localized)];
	
	[self saveFrame];

	[[NSUserDefaults standardUserDefaults] setObject:itemIdentifier forKey:@"MCSavedPrefView"];
}

- (id)myViewWithIdentifier:(NSString *)identifier
{
	if ([identifier isEqualTo:@"General"])
		return generalView;
	else if ([identifier isEqualTo:@"Presets"])
		return presetsView;
	else if ([identifier isEqualTo:@"Advanced"])
		return advancedView;
	
	return nil;
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	return [self createToolbarItemWithName:itemIdentifier];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
	return [NSArray arrayWithObjects:NSToolbarSeparatorItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, @"General", @"Presets", @"Advanced", nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
	return [NSArray arrayWithObjects:@"General", @"Presets", @"Advanced", nil];
}

/* -----------------------------------------------------------------------------
	toolbarSelectableItemIdentifiers:
		Make sure all our custom items can be selected. NSToolbar will
		automagically select the appropriate item when it is clicked.
   -------------------------------------------------------------------------- */

-(NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [itemsList allKeys];
}

//////////////////////
// Tableview actions //
///////////////////////

#pragma mark -
#pragma mark •• Tableview actions

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{	
	NSString *newTitle;
	if ([presetsTableView numberOfSelectedRows] > 1)
		newTitle = NSLocalizedString(@"Duplicate Presets", nil);
	else
		newTitle = NSLocalizedString(@"Duplicate Preset", nil);
		
	[presetsActionButton setTitle:newTitle atIndex:1];
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
	if (loaded == YES)
	{
		if (([presetsTableView selectedRow] == -1 | [presetsTableView numberOfSelectedRows] > 1) && (aSelector == @selector(edit:) | aSelector == @selector(saveDocumentAs:)))
			return NO;
		
		if (([presetsTableView selectedRow] == -1) && (aSelector == @selector(duplicate:) | (aSelector == @selector(delete:))))
			return NO;
	}
		
	return [super respondsToSelector:aSelector];
}

//Count the number of rows, not really needed anywhere
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [presetsData count];
}

//return selected row
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSString *presetPath = [presetsData objectAtIndex:row];
	NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:presetPath];

	return [dictionary objectForKey:[tableColumn identifier]];
}

//We don't want to make people change our row values
- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return NO;
}

//Needed to be able to drag rows
- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op
{
	NSInteger result = NSDragOperationNone;
	
	NSPasteboard *pboard = [info draggingPasteboard];
	NSData *data = [pboard dataForType:@"NSGeneralPboardType"];
	NSArray *rows = [NSUnarchiver unarchiveObjectWithData:data];
	NSInteger firstIndex = [[rows objectAtIndex:0] integerValue];
	
	if (row > firstIndex - 1 && row < firstIndex + [rows count] + 1)
		return result;

    if (op == NSTableViewDropAbove) {
        result = NSDragOperationMove;
    }

    return (result);
}

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op
{
	NSPasteboard *pboard = [info draggingPasteboard];

	if ([[pboard types] containsObject:@"NSGeneralPboardType"])
	{
		NSData *data = [pboard dataForType:@"NSGeneralPboardType"];
		NSArray *rows = [NSUnarchiver unarchiveObjectWithData:data];
		NSInteger firstIndex = [[rows objectAtIndex:0] integerValue];
	
		NSMutableArray *presets = [NSMutableArray array];
		
		NSInteger x;
		for (x = 0;x < [rows count];x++)
		{
			[presets addObject:[presetsData objectAtIndex:[[rows objectAtIndex:x] integerValue]]];
		}
		
		if (firstIndex < row)
		{
			for (x = 0;x < [presets count];x++)
			{
				NSInteger index = row - 1;
				
				[self moveRowAtIndex:[presetsData indexOfObject:[presets objectAtIndex:x]] toIndex:index];
			}
		}
		else
		{
			for (x = [presets count] - 1;x < [presets count];x--)
			{
				NSInteger index = row;
				
				[self moveRowAtIndex:[presetsData indexOfObject:[presets objectAtIndex:x]] toIndex:index];
			}
		}
	}
	
    return YES;
}

- (BOOL)tableView:(NSTableView *)view writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
	NSData *data = [NSArchiver archivedDataWithRootObject:rows];
	[pboard declareTypes: [NSArray arrayWithObjects:@"NSGeneralPboardType", nil] owner:nil];
	[pboard setData:data forType:@"NSGeneralPboardType"];
   
	return YES;
}

- (NSArray*)allSelectedItemsInTableView:(NSTableView *)tableView fromArray:(NSArray *)array
{
	NSMutableArray *items = [NSMutableArray array];
	NSIndexSet *indexSet = [tableView selectedRowIndexes];
	
	NSUInteger current_index = [indexSet firstIndex];
    while (current_index != NSNotFound)
    {
		if ([array objectAtIndex:current_index]) 
			[items addObject:[array objectAtIndex:current_index]];
			
        current_index = [indexSet indexGreaterThanIndex: current_index];
    }

	return items;
}

- (void)moveRowAtIndex:(NSInteger)index toIndex:(NSInteger)destIndex
{
	NSArray *allSelectedItems = [self allSelectedItemsInTableView:presetsTableView fromArray:presetsData];
	NSData *data = [NSArchiver archivedDataWithRootObject:[presetsData objectAtIndex:index]];
	BOOL isSelected = [allSelectedItems containsObject:[presetsData objectAtIndex:index]];
		
	if (isSelected)
		[presetsTableView deselectRow:index];
	
	if (destIndex < index)
	{
		NSInteger x;
		for (x = index; x > destIndex; x --)
		{
			id object = [presetsData objectAtIndex:x - 1];
	
			[presetsData replaceObjectAtIndex:x withObject:object];
		
			if ([allSelectedItems containsObject:object])
			{
				[presetsTableView deselectRow:x - 1];
				[presetsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:x] byExtendingSelection:YES];
			}
		}
	}
	else
	{
		NSInteger x;
		for (x = index;x<destIndex;x++)
		{
			id object = [presetsData objectAtIndex:x + 1];
	
			[presetsData replaceObjectAtIndex:x withObject:object];
		
			if ([allSelectedItems containsObject:object])
			{
				[presetsTableView deselectRow:x + 1];
				[presetsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:x] byExtendingSelection:YES];
			
			}
		}
	}
	
	[presetsData replaceObjectAtIndex:destIndex withObject:[NSUnarchiver unarchiveObjectWithData:data]];
				
	[presetsTableView reloadData];
	
	if (isSelected)
		[presetsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:destIndex] byExtendingSelection:YES];
	
	[[NSUserDefaults standardUserDefaults] setObject:presetsData forKey:@"MCPresets"];
	[delegate performSelector:@selector(updatePresets)];
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (void)resizeWindowOnSpotWithRect:(NSRect)aRect
{
    NSRect r = NSMakeRect([[self window] frame].origin.x - 
        (aRect.size.width - [[self window] frame].size.width), [[self window] frame].origin.y - 
        (aRect.size.height+78 - [[self window] frame].size.height), aRect.size.width, aRect.size.height+78);
    [[self window] setFrame:r display:YES animate:YES];
}

- (void)clearOptionsInViews:(NSArray *)views
{
	/*NSEnumerator *iter = [[[NSEnumerator alloc] init] autorelease];
	NSControl *cntl;

	NSInteger x;
	for (x = 0; x < [views count]; x ++)
	{
		NSView *currentView;
	
		if ([[views objectAtIndex:x] isKindOfClass:[NSView class]])
			currentView = [views objectAtIndex:x];
		else
			currentView = [[views objectAtIndex:x] view];
		
		iter = [[currentView subviews] objectEnumerator];
		while ((cntl = [iter nextObject]) != NULL)
		{
			if ([cntl isKindOfClass:[NSTabView class]])
			{
				[self clearOptionsInViews:[(NSTabView *)cntl tabViewItems]];
			}
			else
			{
				NSInteger index = [cntl tag] - 1;
				
				if (index < [viewMappings count])
				{
					if ([cntl isKindOfClass:[NSTextField class]])
						[cntl setEnabled:NO];
							
					[cntl setObjectValue:nil];
				}
				else if (index > 100)
				{
					index = [cntl tag] - 101;
					
					if (index < [extraOptionMappings count])
					{
						if ([cntl isKindOfClass:[NSPopUpButton class]])
							[(NSPopUpButton *)cntl selectItemAtIndex:0];
						else
							[cntl setObjectValue:nil];
					}
				}
			}
		}
	}*/
}

- (void)reloadPresets
{
	[presetsData removeAllObjects];
	
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];

	NSString *folder1 = [@"~/Library/Application Support/Media Converter/Presets" stringByExpandingTildeInPath];
	NSString *folder2 = @"/Library/Application Support/Media Converter/Presets";
	
	NSArray *presetPaths = [MCCommonMethods getFullPathsForFolders:[NSArray arrayWithObjects:folder1, folder2, nil] withType:@"mcpreset"];
	
	NSMutableArray *currentPresets = [NSMutableArray array];
	
	NSInteger i;
	for (i = 0; i < [presetPaths count]; i ++)
	{
		NSString *presetPath = [presetPaths objectAtIndex:i];
		//NSDictionary *presetDictionary = [NSDictionary dictionaryWithContentsOfFile:presetPath];
		
		[currentPresets addObject:presetPath];
	}
	
	NSMutableArray *savedPresets = [NSMutableArray arrayWithArray:[standardDefaults objectForKey:@"MCPresets"]];
	NSArray *staticSavedPresets = [standardDefaults objectForKey:@"MCPresets"];
	
	for (i = 0; i < [staticSavedPresets count]; i ++)
	{
		NSString *savedPath = [staticSavedPresets objectAtIndex:i];
		
		if ([currentPresets containsObject:savedPath])
			[currentPresets removeObjectAtIndex:[currentPresets indexOfObject:savedPath]];
		else
			[savedPresets removeObjectAtIndex:[savedPresets indexOfObject:savedPath]];
	}
	
	[savedPresets addObjectsFromArray:currentPresets];
	[standardDefaults setObject:savedPresets forKey:@"MCPresets"];
	
	[presetsData addObjectsFromArray:savedPresets];
	
	[presetsTableView reloadData];
	
	[delegate performSelector:@selector(updatePresets)];
}

- (void)updateFontListForWindow:(NSWindow *)window
{
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	NSString *savedFontPath = [standardDefaults objectForKey:@"MCFontFolderPath"];
	
	if (savedFontPath != nil)
		[MCCommonMethods removeItemAtPath:savedFontPath];

	MCConverter *converter = [[MCConverter alloc] init];

	NSFileManager *defaultManager = [MCCommonMethods defaultManager];
	MCInstallPanel *installPanel = [[[MCInstallPanel alloc] init] autorelease];
	[installPanel setTaskText:NSLocalizedString(@"Install Subtitle Fonts for:", nil)];
	NSString *applicationSupportFolder = [installPanel installLocation];
	NSString *fontPath = [[applicationSupportFolder stringByAppendingPathComponent:@"Media Converter"] stringByAppendingPathComponent:@"Fonts"];
	[standardDefaults setObject:fontPath forKey:@"MCFontFolderPath"];
	
	MCProgress *progressPanel = [[MCProgress alloc] init];
	[progressPanel setTask:NSLocalizedString(@"Adding fonts (one time)", nil)];
	[progressPanel setStatus:NSLocalizedString(@"Checking font: %@", nil)];
	[progressPanel setIcon:[NSImage imageNamed:@"Media Converter"]];
	[progressPanel setMaximumValue:[NSNumber numberWithDouble:0]];
	[progressPanel setCanCancel:NO];
		
	if (window != nil)
		[progressPanel beginSheetForWindow:window];
	else
		[progressPanel performSelectorOnMainThread:@selector(beginWindow) withObject:nil waitUntilDone:NO];
	
	[defaultManager createDirectoryAtPath:fontPath attributes:nil];
		
	NSString *spumuxPath = [NSHomeDirectory() stringByAppendingPathComponent:@".spumux"];
	NSString *uniqueSpumuxPath = [MCCommonMethods uniquePathNameFromPath:spumuxPath withSeperator:@"_"];
		
	if ([defaultManager fileExistsAtPath:spumuxPath])
		[MCCommonMethods moveItemAtPath:spumuxPath toPath:uniqueSpumuxPath error:nil];
		
	[defaultManager createSymbolicLinkAtPath:spumuxPath pathContent:fontPath];
		
	NSMutableArray *fontFolderPaths = [NSMutableArray arrayWithObjects:@"/System/Library/Fonts", @"/Library/Fonts", nil];
	NSString *homeFontsFolder = [[NSHomeDirectory() stringByAppendingPathComponent:@"Library"] stringByAppendingPathComponent:@"Fonts"];
		
	if ([defaultManager fileExistsAtPath:homeFontsFolder])
	{
		[fontFolderPaths addObject:homeFontsFolder];
			
		NSString *msFonts = [homeFontsFolder stringByAppendingPathComponent:@"Microsoft"];
			
		if ([defaultManager fileExistsAtPath:homeFontsFolder])
			[fontFolderPaths addObject:msFonts];
	}
		
	NSArray *fontPaths = [MCCommonMethods getFullPathsForFolders:fontFolderPaths withType:@"ttf"];
	[progressPanel setMaximumValue:[NSNumber numberWithDouble:[fontPaths count] + 4]];
			
	NSInteger i;
	for (i = 0; i < [fontPaths count]; i ++)
	{
		NSString *currentFontPath = [fontPaths objectAtIndex:i];
		NSString *fontName = [currentFontPath lastPathComponent];
			
		[progressPanel setStatus:[NSString stringWithFormat:NSLocalizedString(@"Checking font: %@", nil), fontName]];

		NSString *newFontPath = [fontPath stringByAppendingPathComponent:fontName];
					
		if (![defaultManager fileExistsAtPath:newFontPath])
		{
			[defaultManager createSymbolicLinkAtPath:newFontPath pathContent:currentFontPath];
					
			if (![converter testFontWithName:fontName])
				[defaultManager removeFileAtPath:newFontPath handler:0];
		}
			
		[progressPanel setValue:[NSNumber numberWithDouble:i + 1]];
	}
		
	[MCCommonMethods removeItemAtPath:spumuxPath];
		
	if ([defaultManager fileExistsAtPath:uniqueSpumuxPath])
		[MCCommonMethods moveItemAtPath:uniqueSpumuxPath toPath:spumuxPath error:nil];
		
	[converter extractImportantFontsToPath:fontPath statusStart:[fontPaths count]];
		
	[progressPanel endSheet];
	[progressPanel release];
	progressPanel = nil;
		
	NSArray *defaultFonts = [NSArray arrayWithObjects:		@"AppleGothic.ttf", @"Hei.ttf", 
															@"Osaka.ttf", 
															@"AlBayan.ttf",
															@"Raanana.ttf", @"Ayuthaya.ttf",
															@"儷黑 Pro.ttf", @"MshtakanRegular.ttf",
															nil];
															
	NSArray *defaultLanguages = [NSArray arrayWithObjects:		NSLocalizedString(@"Korean", nil), NSLocalizedString(@"Simplified Chinese", nil), 
																NSLocalizedString(@"Japanese", nil), 
																NSLocalizedString(@"Arabic", nil),
																NSLocalizedString(@"Hebrew", nil), NSLocalizedString(@"Thai", nil),
																NSLocalizedString(@"Traditional Chinese", nil), NSLocalizedString(@"Armenian", nil),
																nil];
		
	NSString *errorMessage = NSLocalizedString(@"Not found:", nil);
	BOOL shouldWarn = NO;
		
	NSInteger z;
	for (z = 0; z < [defaultFonts count]; z ++)
	{
		NSString *font = [defaultFonts objectAtIndex:z];
			
		if (![defaultManager fileExistsAtPath:[fontPath stringByAppendingPathComponent:font]])
		{
			NSString *language = [defaultLanguages objectAtIndex:z];
			
			shouldWarn = YES;
				
			NSString *warningString = [NSString stringWithFormat:@"%@ (%@)", font, language];
				
			if ([errorMessage isEqualTo:@""])
				errorMessage = warningString;
			else
				errorMessage = [NSString stringWithFormat:@"%@\n%@", errorMessage, warningString];
		}
	}
		
	if (shouldWarn == YES)
		[MCCommonMethods standardAlertWithMessageText:NSLocalizedString(@"Failed to add some default language fonts", nil) withInformationText:NSLocalizedString(@"You can savely ignore this message if you don't use these languages (see details).", nil) withParentWindow:window withDetails:errorMessage];
	
	[converter release];
	converter = nil;
}

- (void)installModeChanged:(NSNotification *)notification
{
	NSInteger mode = [[notification object] integerValue];
	[(NSPopUpButton *)[generalView viewWithTag:3] selectItemAtIndex:mode];
}

@end
