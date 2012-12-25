//
//  MCPreferences.h
//  Media Converter
//
//  Created by Maarten Foukhar on 25-01-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MCCommonMethods.h"


@interface MCPreferences : NSWindowController
{
	/* Preferences views */
	// General
	IBOutlet id generalView;
	IBOutlet id saveFolderPopUp;
	IBOutlet id subtitleLanguagePopup;
	// Presets
	IBOutlet id presetsView;
	IBOutlet id presetsTableView;
	IBOutlet id presetsActionButton;
	// Advanced
	IBOutlet id advancedView;
	IBOutlet id commandPanel;
	
	/* Preset add panel */
	IBOutlet id addPanel;
	IBOutlet id addTableView;
	
	/* Toolbar outlets */
	NSToolbar *toolbar;
	NSMutableDictionary *itemsList;
	
	/* Variables */
	BOOL loaded;
	NSArray *preferenceMappings;
	NSMutableArray *presetsData;
	id delegate;
}

/* Main action */
- (void)setDelegate:(id)del;

/* PrefPane actions */
- (void)showPreferences;
- (IBAction)setPreferenceOption:(id)sender;
- (void)saveFrame;
// Presets
- (IBAction)delete:(id)sender;
- (IBAction)addPreset:(id)sender;
- (IBAction)endAddSheet:(id)sender;
- (IBAction)edit:(id)sender;
- (IBAction)duplicate:(id)sender;
- (IBAction)saveDocumentAs:(id)sender;
- (IBAction)goToPresetSite:(id)sender;
// Advanced
- (IBAction)chooseFFMPEG:(id)sender;
- (IBAction)rebuildFonts:(id)sender;

/* Toolbar actions */
- (NSToolbarItem *)createToolbarItemWithName:(NSString *)name;
- (void)setupToolbar;
- (void)toolbarAction:(id)object;
- (id)myViewWithIdentifier:(NSString *)identifier;

/* TableView actions */
- (void)moveRowAtIndex:(NSInteger)index toIndex:(NSInteger)destIndex;

/* Other actions */
//MatPeterson http://www.cocoadev.com/index.pl?NSWindow
- (void)resizeWindowOnSpotWithRect:(NSRect)aRect;
- (void)clearOptionsInViews:(NSArray *)views;
- (void)reloadPresets;
- (void)updateFontListForWindow:(NSWindow *)window;

@end
