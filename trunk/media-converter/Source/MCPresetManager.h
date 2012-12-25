//
//  MCPresetManager.h
//  Media Converter
//
//  Preset manager (edit, save, install etc.)
//
//  Created by Maarten Foukhar on 18-09-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MCCommonMethods.h"


@interface MCPresetManager : NSWindowController
{
	/* Preset panel */
	IBOutlet id presetsPanel;
	IBOutlet id completeButton;
	// General
	IBOutlet id nameField;
	IBOutlet id containerPopUp;
	IBOutlet id extensionField;
	// Video
	IBOutlet id videoFormatPopUp;
	IBOutlet id aspectRatioButton;
	IBOutlet id aspectRatioField;
	// Audio
	IBOutlet id audioFormatPopUp;
	IBOutlet id modePopup;
	// Subtitles
	IBOutlet id subtitleFormatPopUp;
	IBOutlet id subtitleSettingsView;
	// -> Hardcoded
	IBOutlet id hardcodedSettingsView;
	IBOutlet id hardcodedFontPopup;
	IBOutlet id hardcodedHAlignPopup;
	IBOutlet id hardcodedVAlignPopup;
	IBOutlet id hardcodedVisiblePopup;
	IBOutlet id hardcodedMethodTabView;
	// -> DVD
	IBOutlet id DVDSettingsView;
	IBOutlet id fontPopup;
	IBOutlet id hAlignFormatPopUp;
	IBOutlet id vAlignFormatPopUp;
	// -> Other
	// No settings (yet)
	// Filters
	IBOutlet id filterTableView;
	IBOutlet id filterDelegate;
	// Advanced FFmpeg settings
	IBOutlet id advancedTableView;
	IBOutlet id advancedAddButton;
	IBOutlet id advancedDeleteButton;
	IBOutlet id advancedBarButton;
	
	/* Preview panel */
	IBOutlet id previewImageView;
	IBOutlet id previewPanel;
	
	/* Variables */
	NSArray *viewMappings;
	NSArray *preferenceMappings;
	NSArray *extraOptionMappings;
	NSArray *extraOptionDefaultValues;
	NSString *currentPresetPath;
	NSMutableDictionary *extraOptions;
	NSModalSession session;
	BOOL previewOpened;
	BOOL darkBackground;
	id delegate;
	SEL didEndSelector;
}

/* Main actions */
+ (MCPresetManager *)defaultManager;
- (void)editPresetForWindow:(NSWindow *)window withPresetPath:(NSString *)path didEndSelector:(SEL)selector;
- (void)savePresetForWindow:(NSWindow *)window withPresetPath:(NSString *)path;
- (NSInteger)openPresetFiles:(NSArray *)paths;
- (NSInteger)installPresetsWithNames:(NSArray *)names presetDictionaries:(NSArray *)dictionaries;
- (void)setDelegate:(id)del;
- (NSMutableDictionary *)presetDictionary;

/* Preset panel actions */
- (IBAction)toggleAdvancedView:(id)sender;
- (IBAction)setOption:(id)sender;
- (IBAction)setExtraOption:(id)sender;
- (IBAction)endSheet:(id)sender;
// Video
- (IBAction)setAspect:(id)sender;
//Audio
- (IBAction)setMode:(id)sender;
// Subtitles
- (IBAction)setSubtitleKind:(id)sender;
// -> Hardcoded
- (IBAction)setHarcodedVisibility:(id)sender;

/* Preview actions */
- (void)updatePreview:(NSNotification *)notif;
- (IBAction)showPreview:(id)sender;
- (void)reloadHardcodedPreview;
- (IBAction)toggleDarkBackground:(id)sender;
- (NSImage *)previewBackgroundWithImage:(NSImage *)image forSize:(NSSize)size;

/* Other actions */
- (BOOL)updateForKey:(NSString *)key withProperty:(id)property;
- (void)setupPopups;
- (NSDictionary *)defaults;

@end
