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
	//Views
	IBOutlet id generalView;
	IBOutlet id presetsView;
	IBOutlet id advancedView;
	
	//General
	IBOutlet id saveFolderPopUp;
	//Add panel
	IBOutlet id addPanel;
	IBOutlet id addTableView;
	//Presets
	IBOutlet id nameField;
	IBOutlet id extensionField;
	IBOutlet id presetsTableView;
	IBOutlet id presetsPanel;
	IBOutlet id containerPopUp;
	IBOutlet id videoFormatPopUp;
	IBOutlet id audioFormatPopUp;
	IBOutlet id aspectRatioButton;
	IBOutlet id aspectRatioField;
	IBOutlet id keepAspectButton;
	IBOutlet id autoAspectButton;
	IBOutlet id autoSizeButton;
	IBOutlet id twoPassButton;
	IBOutlet id modePopup;
	IBOutlet id advancedTableView;
	IBOutlet id advancedAddButton;
	IBOutlet id advancedDeleteButton;
	IBOutlet id advancedBarButton;
	IBOutlet id advancedCompleteButton;
	IBOutlet id saveButton;
	//Advanced
	IBOutlet id commandPanel;
	
	//Install Mode
	IBOutlet id installModePanel;
	IBOutlet id installModePopup;
	IBOutlet id suppressButton;
	
	//Toolbar outlets
	NSToolbar *toolbar;
	NSMutableDictionary *itemsList;
	
	//Variables
	NSArray *viewMappings;
	NSArray *preferenceMappings;
	NSMutableArray *presetsData;
	
	NSString *currentPresetPath;
	NSMutableDictionary *extraOptions;
	
	id delegate;
}

//Main actions
- (void)setDelegate:(id)del;

//Save the window location manually
- (void)saveFrame;

//PrefPane actions
- (void)showPreferences;
- (IBAction)setPreferenceOption:(id)sender;

//Add actions
- (IBAction)endAddSheet:(id)sender;
//Presets actions
- (IBAction)addPreset:(id)sender;
- (IBAction)removePreset:(id)sender;
- (NSInteger)installThemesWithNames:(NSArray *)names presetDictionaries:(NSArray *)dictionaries;
- (void)openPresetFiles:(NSArray *)paths;
- (IBAction)endSheet:(id)sender;
- (IBAction)setMode:(id)sender;
- (IBAction)toggleAdvancedView:(id)sender;
- (IBAction)setOption:(id)sender;
- (IBAction)setAspect:(id)sender;
- (IBAction)setKeepAspect:(id)sender;
- (IBAction)setAutoAspect:(id)sender;
- (IBAction)setAutoSize:(id)sender;
- (IBAction)setTwoPass:(id)sender;
- (IBAction)goToPresetSite:(id)sender;
- (IBAction)savePreset:(id)sender;
//Advanced actions
- (IBAction)chooseFFMPEG:(id)sender;

//Install Mode actions
- (IBAction)endSettingMode:(id)sender;

//Toolbar actions
- (NSToolbarItem *)createToolbarItemWithName:(NSString *)name;
- (void)setupToolbar;
- (void)toolbarAction:(id)object;
- (id)myViewWithIdentifier:(NSString *)identifier;

//TableView actions
- (void)moveRowAtIndex:(NSInteger)index toIndex:(NSInteger)destIndex;

//Other actions
//MatPeterson http://www.cocoadev.com/index.pl?NSWindow
- (void)resizeWindowOnSpotWithRect:(NSRect)aRect;
- (void)setViewOptions:(NSArray *)views infoObject:(id)info mappingsObject:(NSArray *)mappings;
- (void)clearOptionsInViews:(NSArray *)views;
- (void)setProperty:(id)property forControl:(id)control;
- (void)reloadPresets;
- (BOOL)updateForKey:(NSString *)key withProperty:(id)property;
- (void)setupPopups;

@end
