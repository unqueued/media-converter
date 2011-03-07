//
//  MCCommonMethods.h
//  Media Converter
//
//  Created by Maarten Foukhar on 22-4-07.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
typedef int NSInteger;
typedef unsigned int NSUInteger;
typedef float CGFloat;
#endif

@interface MCCommonMethods : NSObject 
{

}

//OS actions
//Check for Snow Leopard (used to show new sizes divided by 1000 instead of 1024)
+ (NSInteger)OSVersion;

//File actions
//Get a non existing file name (example Folder 1, Folder 2 etc.)
+ (NSString *)uniquePathNameFromPath:(NSString *)path;
//Get full paths for multiple folders in an array
+ (NSArray *)getFullPathsForFolders:(NSArray *)folders;

//Error actions
+ (BOOL)createDirectoryAtPath:(NSString *)path errorString:(NSString **)error;
+ (BOOL)copyItemAtPath:(NSString *)inPath toPath:(NSString *)newPath errorString:(NSString **)error;
+ (BOOL)removeItemAtPath:(NSString *)path;
+ (BOOL)writeDictionary:(NSDictionary *)dictionary toFile:(NSString *)path errorString:(NSString **)error;

//Mac OS X 10.3.9 compatible methods
+ (id)stringWithContentsOfFile:(NSString *)path;

//Other actions
//Get used ffmpeg
+ (NSString *)ffmpegPath;
//Log command with arguments for easier debugging
+ (void)logCommandIfNeeded:(NSTask *)command;
//Conveniant method to load a NSTask
+ (BOOL)launchNSTaskAtPath:(NSString *)path withArguments:(NSArray *)arguments outputError:(BOOL)error outputString:(BOOL)string output:(id *)data;
//Standard informative alert
+ (void)standardAlertWithMessageText:(NSString *)message withInformationText:(NSString *)information withParentWindow:(NSWindow *)parent;
//Get the selected items in the tableview
+ (NSArray *)allSelectedItemsInTableView:(NSTableView *)tableView fromArray:(NSArray *)array;

@end