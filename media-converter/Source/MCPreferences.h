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
	IBOutlet id presetsActionButton;
	IBOutlet id presetsPanel;
	IBOutlet id containerPopUp;
	IBOutlet id videoFormatPopUp;
	IBOutlet id audioFormatPopUp;
	IBOutlet id subtitleFormatPopUp;
	IBOutlet id subtitleLanguagePopup;
	IBOutlet id fontPopup;
	IBOutlet id hAlignFormatPopUp;
	IBOutlet id vAlignFormatPopUp;
	IBOutlet id aspectRatioButton;
	IBOutlet id aspectRatioField;
	IBOutlet id modePopup;
	IBOutlet id advancedTableView;
	IBOutlet id advancedAddButton;
	IBOutlet id advancedDeleteButton;
	IBOutlet id advancedBarButton;
	IBOutlet id advancedCompleteButton;
	IBOutlet id saveButton;
	IBOutlet id imageIcon;
	IBOutlet id imageName;
	
	IBOutlet id hardcodedFontPopup;
	IBOutlet id hardcodedHAlignPopup;
	IBOutlet id hardcodedVAlignPopup;
	IBOutlet id hardcodedVisiblePopup;
	
	IBOutlet id hardcodedMethodTabView;
	
	IBOutlet id hardcodedPreviewImage;
	IBOutlet id hardcodedPreview;
	
	IBOutlet id subtitleSettingsView;
	IBOutlet id hardcodedSettingsView;
	IBOutlet id DVDSettingsView;
	
	IBOutlet id filterTableView;
	IBOutlet id filterDelegate;
	
	//Advanced
	IBOutlet id commandPanel;
	
	//Toolbar outlets
	NSToolbar *toolbar;
	NSMutableDictionary *itemsList;
	
	//Variables
	BOOL loaded;
	NSArray *viewMappings;
	NSArray *preferenceMappings;
	NSArray *extraOptionMappings;
	NSArray *extraOptionDefaultValues;
	NSMutableArray *presetsData;
	
	NSString *currentPresetPath;
	NSMutableDictionary *extraOptions;
	
	NSModalSession session;
	
	BOOL previewOpened;
	BOOL darkBackground;
	
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
//Also external
- (void)editPresetForWindow:(NSWindow *)window withDictionary:(NSDictionary *)dictionary;
- (void)savePresetForWindow:(NSWindow *)window withDictionary:(NSDictionary *)dictionary;

- (void)updatePreview:(NSNotification *)notif;

- (IBAction)edit:(id)sender;
- (IBAction)addPreset:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)duplicate:(id)sender;
- (NSInteger)installThemesWithNames:(NSArray *)names presetDictionaries:(NSArray *)dictionaries;
- (void)openPresetFiles:(NSArray *)paths;
- (IBAction)endSheet:(id)sender;
- (IBAction)setMode:(id)sender;
- (IBAction)toggleAdvancedView:(id)sender;
- (IBAction)setOption:(id)sender;
- (IBAction)setAspect:(id)sender;
- (IBAction)setExtraOption:(id)sender;
- (IBAction)setSubtitleKind:(id)sender;

- (void)savePreset;

- (IBAction)showPreview:(id)sender;
- (void)reloadHardcodedPreview;
- (IBAction)setHarcodedVisibility:(id)sender;
- (IBAction)toggleDarkBackground:(id)sender;

- (IBAction)chooseImage:(id)sender;
- (IBAction)setImageHAlignment:(id)sender;
- (IBAction)setImageVAlignment:(id)sender;

- (IBAction)goToPresetSite:(id)sender;
- (IBAction)saveDocumentAs:(id)sender;
//Advanced actions
- (IBAction)chooseFFMPEG:(id)sender;
- (IBAction)rebuildFonts:(id)sender;

- (IBAction)ok:(id)sender;
- (IBAction)cancel:(id)sender;

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
- (void)setViewOptions:(NSArray *)views infoObject:(id)info fallbackInfo:(id)fallback mappingsObject:(NSArray *)mappings startCount:(NSInteger)start;
- (void)clearOptionsInViews:(NSArray *)views;
- (void)setProperty:(id)property forControl:(id)control;
- (void)reloadPresets;
- (BOOL)updateForKey:(NSString *)key withProperty:(id)property;
- (void)setupPopups;
- (void)updateFontListForWindow:(NSWindow *)window;

@end
