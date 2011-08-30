//
//  MCCommonMethods.m
//  Media Converter
//
//  Created by Maarten Foukhar on 22-4-07.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCCommonMethods.h"
#import "NSString_Extensions.h"
#import "NSNumber_Extensions.h"
#import "MCAlert.h"
#import "MCCheckBoxCell.h"
#import "MCPopupButton.h"

@interface NSFileManager (MyUndocumentedMethodsForNSTheClass)

- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error;
- (BOOL)copyItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error;
- (BOOL)moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error;
- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error;

@end


@implementation MCCommonMethods

////////////////
// OS actions //
////////////////

#pragma mark -
#pragma mark •• OS actions

+ (NSInteger)OSVersion
{
	SInt32 MacVersion;
	
	Gestalt(gestaltSystemVersion, &MacVersion);
	
	return (NSInteger)MacVersion;
}

//////////////////
// File actions //
//////////////////

#pragma mark -
#pragma mark •• File actions

+ (NSString *)uniquePathNameFromPath:(NSString *)path withSeperator:(NSString *)seperator
{
	if ([[MCCommonMethods defaultManager] fileExistsAtPath:path])
	{
		NSString *newPath = [path stringByDeletingPathExtension];
		NSString *pathExtension;

		if ([[path pathExtension] isEqualTo:@""])
			pathExtension = @"";
		else
			pathExtension = [@"." stringByAppendingString:[path pathExtension]];

		NSInteger y = 0;
		while ([[MCCommonMethods defaultManager] fileExistsAtPath:[newPath stringByAppendingString:pathExtension]])
		{
			newPath = [path stringByDeletingPathExtension];
			
			y = y + 1;
			newPath = [NSString stringWithFormat:@"%@%@%i", newPath, seperator, y];
		}

		return [newPath stringByAppendingString:pathExtension];
	}
	else
	{
		return path;
	}
}

//Get full paths for multiple folders in an array
+ (NSArray *)getFullPathsForFolders:(NSArray *)folders withType:(NSString *)type
{
	NSMutableArray *paths = [NSMutableArray array];

	NSInteger x;
	for (x = 0; x < [folders count]; x ++)
	{
		NSString *folder = [folders objectAtIndex:x];
		NSArray *folderContents = [[MCCommonMethods defaultManager] directoryContentsAtPath:folder];
	
		NSInteger i;
		for (i = 0; i < [folderContents count]; i ++)
		{
			NSString *item = [folderContents objectAtIndex:i];
			
			if (type == nil | [[[item pathExtension] lowercaseString] isEqualTo:[type lowercaseString]])
			{
				NSString *path = [folder stringByAppendingPathComponent:item];
				[paths addObject:path];
			}
		}
	}
	
	return paths;
}

///////////////////
// Error actions //
///////////////////

#pragma mark -
#pragma mark •• Error actions

+ (BOOL)createDirectoryAtPath:(NSString *)path errorString:(NSString **)error
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	NSFileManager *defaultManager = [MCCommonMethods defaultManager];
	NSError *myError;
	BOOL succes = [defaultManager createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:&myError];
			
	if (!succes && error != nil)
		*error = [myError localizedDescription];
	#else
	
	BOOL succes = YES;
	NSString *details;
	NSFileManager *defaultManager = [MCCommonMethods defaultManager];
	
	if (![defaultManager fileExistsAtPath:path])
	{
		if ([MCCommonMethods OSVersion] >= 0x1050)
		{
			NSError *myError;
			succes = [defaultManager createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:&myError];
			
			if (!succes)
				details = [myError localizedDescription];
		}
		else
		{
			succes = [defaultManager createDirectoryAtPath:path attributes:nil];
			NSString *folder = [defaultManager displayNameAtPath:path];
			NSString *parent = [defaultManager displayNameAtPath:[path stringByDeletingLastPathComponent]];
			details = [NSString stringWithFormat:NSLocalizedString(@"Failed to create folder '%@' in '%@'.", nil), folder, parent];
		}
		
		if (!succes && error != nil)
			*error = details;
	}
	#endif
	
	return succes;
}

+ (BOOL)copyItemAtPath:(NSString *)inPath toPath:(NSString *)newPath errorString:(NSString **)error
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	NSFileManager *defaultManager = [MCCommonMethods defaultManager];
	BOOL succes;
	NSError *myError;
	succes = [defaultManager copyItemAtPath:inPath toPath:newPath error:&myError];
			
	if (!succes && error != nil)
		*error = [myError localizedDescription];
	
	return succes;
	#else

	BOOL succes = YES;
	NSString *details = @"";
	NSFileManager *defaultManager = [MCCommonMethods defaultManager];

	if ([MCCommonMethods OSVersion] >= 0x1050)
	{
		NSError *myError;
		succes = [defaultManager copyItemAtPath:inPath toPath:newPath error:&myError];
			
		if (!succes)
			details = [myError localizedDescription];
	}
	else
	{
		succes = [defaultManager copyPath:inPath toPath:newPath handler:nil];
	}
		
	if (!succes && error != nil)
	{
		NSString *inFile = [defaultManager displayNameAtPath:inPath];
		NSString *outFile = [defaultManager displayNameAtPath:[newPath stringByDeletingLastPathComponent]];

		details = [NSString stringWithFormat:NSLocalizedString(@"Failed to copy '%@' to '%@'. %@", nil), inFile, outFile, details];
		*error = details;
	}
	#endif

	return succes;
}

+ (BOOL)moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSString **)error
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	NSFileManager *defaultManager = [MCCommonMethods defaultManager];
	BOOL succes;
	NSError *myError;
	succes = [defaultManager moveItemAtPath:srcPath toPath:dstPath error:&myError];
			
	if (!succes && error != nil)
		*error = [myError localizedDescription];
	
	return succes;
	#else

	BOOL succes = YES;
	NSString *details = @"";
	NSFileManager *defaultManager = [MCCommonMethods defaultManager];

	if ([MCCommonMethods OSVersion] >= 0x1050)
	{
		NSError *myError;
		succes = [defaultManager moveItemAtPath:srcPath toPath:dstPath error:&myError];
			
		if (!succes)
			details = [myError localizedDescription];
	}
	else
	{
		succes = [defaultManager movePath:srcPath toPath:dstPath handler:nil];
	}
		
	if (!succes && error != nil)
	{
		NSString *inFile = [defaultManager displayNameAtPath:srcPath];
		NSString *outFile = [defaultManager displayNameAtPath:[dstPath stringByDeletingLastPathComponent]];
		details = [NSString stringWithFormat:NSLocalizedString(@"Failed to move '%@' to '%@'. %@", nil), inFile, outFile, details];
		*error = details;
	}
	#endif

	return succes;
}

+ (BOOL)removeItemAtPath:(NSString *)path
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	NSFileManager *defaultManager = [MCCommonMethods defaultManager];
	BOOL succes = YES;
	NSString *details;
	
	if ([defaultManager fileExistsAtPath:path])
	{
		NSError *myError;
		succes = [defaultManager removeItemAtPath:path error:&myError];
			
		if (!succes)
			details = [myError localizedDescription];
		
		if (!succes)
		{
			NSString *file = [defaultManager displayNameAtPath:path];
			[MCCommonMethods standardAlertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Failed to delete '%@'.", nil), file ] withInformationText:details withParentWindow:nil withDetails:nil];
		}
	}
	#else
	
	BOOL succes = YES;
	NSString *details;
	NSFileManager *defaultManager = [MCCommonMethods defaultManager];
	
	if ([defaultManager fileExistsAtPath:path])
	{
		if ([MCCommonMethods OSVersion] >= 0x1050)
		{
			NSError *myError;
			succes = [defaultManager removeItemAtPath:path error:&myError];
			
			if (!succes)
				details = [myError localizedDescription];
		}
		else
		{
			succes = [defaultManager removeFileAtPath:path handler:nil];
			details = [NSString stringWithFormat:NSLocalizedString(@"File path: %@", nil), path];
		}
		
		if (!succes)
		{
			NSString *file = [defaultManager displayNameAtPath:path];
			[MCCommonMethods standardAlertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Failed to delete '%@'.", nil), file ] withInformationText:details withParentWindow:nil withDetails:nil];
		}
	}
	#endif

	return succes;
}

+ (BOOL)writeString:(NSString *)string toFile:(NSString *)path errorString:(NSString **)error
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	BOOL succes;
	NSError *myError;
	succes = [string writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&myError];
			
	if (!succes && error != nil)
		*error = [myError localizedDescription];
	#else

	BOOL succes;
	NSString *details;
	
	if ([MCCommonMethods OSVersion] >= 0x1040)
	{
		NSError *myError;
		succes = [string writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&myError];
			
			if (!succes)
			details = [myError localizedDescription];
	}
	else
	{
		succes = [string writeToFile:path atomically:YES];
		NSFileManager *defaultManager = [MCCommonMethods defaultManager];
		NSString *file = [defaultManager displayNameAtPath:path];
		NSString *parent = [defaultManager displayNameAtPath:[path stringByDeletingLastPathComponent]];
		details = [NSString stringWithFormat:NSLocalizedString(@"Failed to write '%@' to '%@'", nil), file, parent];
	}

	if (!succes && error != nil)
		*error = details;
		
	#endif

	return succes;
}

+ (BOOL)writeDictionary:(NSDictionary *)dictionary toFile:(NSString *)path errorString:(NSString **)error
{
	if (![dictionary writeToFile:path atomically:YES])
	{
		NSFileManager *defaultManager = [MCCommonMethods defaultManager];
		NSString *file = [defaultManager displayNameAtPath:path];
		NSString *parent = [defaultManager displayNameAtPath:[path stringByDeletingLastPathComponent]];
		
		if (error != nil)
		*error = [NSString stringWithFormat:NSLocalizedString(@"Failed to write '%@' to '%@'", nil), file, parent];
	
		return NO;
	}

	return YES;
}

////////////////////////
// Compatible actions //
////////////////////////

#pragma mark -
#pragma mark •• Compatible actions

+ (id)stringWithContentsOfFile:(NSString *)path
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED < 1040
	if ([MCCommonMethods OSVersion] < 0x1040)
		return [NSString stringWithContentsOfFile:path];
	else
	#endif
		return [NSString stringWithContentsOfFile:path usedEncoding:nil error:nil];
}

+ (id)stringWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)enc error:(NSError **)error
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED < 1040
	if ([MCCommonMethods OSVersion] < 0x1040)
	{
		NSData *stringData = [NSData dataWithContentsOfFile:path];
		return [[NSString alloc] initWithData:stringData encoding:enc];
	}
	else
	#endif
		return [NSString stringWithContentsOfFile:path encoding:enc error:&*error];
}

+ (NSFileManager *)defaultManager
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
	if ([MCCommonMethods OSVersion] < 0x1050)
		return [NSFileManager defaultManager];
	else
	#endif
		return [[[NSFileManager alloc] init] autorelease];
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

+ (NSString *)ffmpegPath
{
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];

	if ([standardDefaults boolForKey:@"MCUseCustomFFMPEG"] == YES && [[MCCommonMethods defaultManager] fileExistsAtPath:[standardDefaults objectForKey:@"MCCustomFFMPEG"]])
		return [[NSUserDefaults standardUserDefaults] objectForKey:@"MCCustomFFMPEG"];
	else
		return [[NSBundle mainBundle] pathForResource:@"ffmpeg" ofType:@""];
}

+ (NSString *)logCommandIfNeeded:(NSTask *)command
{
	//Set environment to UTF-8
	NSMutableDictionary *environment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
	[environment setObject:@"en_US.UTF-8" forKey:@"LC_ALL"];
	[command setEnvironment:environment];

	NSArray *showArgs = [command arguments];
	NSString *commandString = [command launchPath];

	NSInteger i;
	for (i = 0; i < [showArgs count]; i ++)
		{
			commandString = [NSString stringWithFormat:@"%@ %@", commandString, [showArgs objectAtIndex:i]];
		}
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"MCDebug"] == YES) 
		NSLog(@"%@", commandString);
	
	return commandString;
}

+ (BOOL)launchNSTaskAtPath:(NSString *)path withArguments:(NSArray *)arguments outputError:(BOOL)error outputString:(BOOL)string output:(id *)data inputPipe:(NSPipe *)inPipe predefinedTask:(NSTask *)preTask
{
	id output;
	
	NSTask *task;
	if (preTask != nil)
		task = preTask;
	else
		task = [[NSTask alloc] init];
	
	NSPipe *pipe =[ [NSPipe alloc] init];
	NSPipe *outputPipe = [[NSPipe alloc] init];
	NSFileHandle *handle;
	NSFileHandle *outputHandle;
	NSString *errorString = @"";
	[task setLaunchPath:path];
	[task setArguments:arguments];
	[task setStandardError:pipe];
	handle = [pipe fileHandleForReading];
	
	if (!error)
	{
		[task setStandardOutput:outputPipe];
		outputHandle=[outputPipe fileHandleForReading];
	}
	
	if (inPipe != nil)
		[task setStandardInput:inPipe];
	
	[MCCommonMethods logCommandIfNeeded:task];
	[task launch];
	
	if (error)
		output = [handle readDataToEndOfFile];
	else
		output = [outputHandle readDataToEndOfFile];
		
	output = [[[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding] autorelease];
		
	if (!error && string)
		errorString = [[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding] autorelease];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"MCDebug"])
		NSLog(@"%@\n%@", output, errorString);
		
	[task waitUntilExit];
	
	NSInteger result = [task terminationStatus];

	if (!error && result != 0)
		output = errorString;
	
	[pipe release];
	pipe = nil;
	[outputPipe release];
	outputPipe = nil;
	[task release];
	task = nil;
	
	if (error | string)
	*data = output;
	
	return (result == 0);
}

+ (void)standardAlertWithMessageText:(NSString *)message withInformationText:(NSString *)information withParentWindow:(NSWindow *)parent withDetails:(NSString *)details
{
	MCAlert *alert = [[[MCAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"OK", Localized)];
	[alert setMessageText:message];
	[alert setInformativeText:information];
	
	if (details != nil)
		[alert setDetails:details];
	
	if (parent)
		[alert beginSheetModalForWindow:parent modalDelegate:self didEndSelector:nil contextInfo:nil];
	else
		[alert runModal];
}

+ (NSArray *)allSelectedItemsInTableView:(NSTableView *)tableView fromArray:(NSArray *)array
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

+ (BOOL)isYouTubeURLAtPath:(NSString *)path
{
	return ([path rangeOfString:@"youtube.com/"].length > 0 && [path rangeOfString:@"http://"].length > 0 && [[[path componentsSeparatedByString:@"youtube.com"] objectAtIndex:0] rangeOfString:@"cache"].length == 0);
}

+ (BOOL)isPythonUpgradeInstalled
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	return YES;
	#else
	if ([MCCommonMethods OSVersion] >= 0x1050)
	{
		return YES;
	}
	else
	{
		if (![[MCCommonMethods defaultManager] fileExistsAtPath:@"/usr/local/bin/python"])
			return NO;
	
		NSString *string;
		[MCCommonMethods launchNSTaskAtPath:@"/usr/local/bin/python" withArguments:[NSArray arrayWithObject:@"-V"] outputError:YES outputString:YES output:&string inputPipe:nil predefinedTask:nil];
		NSInteger version = [[[[[string componentsSeparatedByString:@"Python 2."] objectAtIndex:1] componentsSeparatedByString:@"."] objectAtIndex:0] integerValue];
		
		return (version >= 5);
	}
	#endif
}

+ (NSImage *)overlayImageWithObject:(id)object withSettings:(NSDictionary *)settings inputImage:(NSImage *)image
{
	BOOL isString = ([object isKindOfClass:[NSString class]]);
	BOOL isAttributedString = ([object isKindOfClass:[NSAttributedString class]]);

	NSString *fontName;
	CGFloat fontSize;
	NSColor *fontColor;
	NSString *visibilityMethod;
	NSColor *borderColor;
	NSNumber *borderSize;
	NSColor *boxColor;
	CGFloat boxMarge = 0;
	CGFloat boxAlpha;

	if (isString)
	{
		fontName = [settings objectForKey:@"Font"];
		fontSize = [[settings objectForKey:@"Font Size"] cgfloatValue];
		fontColor = [NSUnarchiver unarchiveObjectWithData:[settings objectForKey:@"Color"]];
	}

	if (isString | isAttributedString)
	{
		visibilityMethod = [settings objectForKey:@"Method"];
		borderColor = [NSUnarchiver unarchiveObjectWithData:[settings objectForKey:@"Border Color"]];
		borderSize = [settings objectForKey:@"Border Size"];
		boxColor = [NSUnarchiver unarchiveObjectWithData:[settings objectForKey:@"Box Color"]];
		boxMarge = [[settings objectForKey:@"Box Marge"] cgfloatValue];
		boxAlpha = [[settings objectForKey:@"Box Alpha Value"] cgfloatValue];
	}

	NSString *hAlignString = [settings objectForKey:@"Horizontal Alignment"];
	NSString *vAlignString = [settings objectForKey:@"Vertical Alignment"];
	CGFloat leftMargin = [[settings objectForKey:@"Left Margin"] cgfloatValue];
	CGFloat rightMargin = [[settings objectForKey:@"Right Margin"] cgfloatValue];
	CGFloat topMargin = [[settings objectForKey:@"Top Margin"] cgfloatValue];
	CGFloat bottomMargin = [[settings objectForKey:@"Bottom Margin"] cgfloatValue];
	double alphaValue = [[settings objectForKey:@"Alpha Value"] doubleValue];

	BOOL border;
	BOOL box;

	NSMutableAttributedString *attrStr;
	NSMutableAttributedString *strokeAttrStr;

	if (isString | isAttributedString)
	{
		border = ([visibilityMethod isEqualTo:@"border"]);
		box = ([visibilityMethod isEqualTo:@"box"]);

		if (isAttributedString)
		{
			attrStr = [object mutableCopy];
		}
		else
		{
			NSString *boldFont = [fontName stringByAppendingString:@"-Bold"];
			
			NSFont *font = nil;
			
			font = [NSFont fontWithName:boldFont size:fontSize];
			
			if (font == nil)
				[NSFont fontWithName:fontName size:fontSize];
		
			attrStr = [MCCommonMethods initOnMainThreadWithHTML:(NSString *)object];

			NSRange range;
			NSFontManager *fontManager = [NSFontManager sharedFontManager];

			range = NSMakeRange(0,0);
		
			while(NSMaxRange(range) < [attrStr length])
			{
				NSDictionary *attributes = [attrStr attributesAtIndex:NSMaxRange(range) effectiveRange:&range];
				NSFont *oldFont = [attributes objectForKey:NSFontAttributeName];
				NSFontTraitMask oldTraits = [fontManager traitsOfFont:oldFont];
				NSFont *newFont = [fontManager convertFont:font toHaveTrait:oldTraits];
				[attrStr addAttribute:NSFontAttributeName value:newFont range:range];
			}
		}

		if (border)
			strokeAttrStr = [attrStr mutableCopy];
	}
	
	NSImage *subImage = [image copy];
	NSSize imageSize = [subImage size];

	NSRect objectFrame;
	
	if (isString | isAttributedString)
	{
		objectFrame = [MCCommonMethods frameForStringDrawing:attrStr forWidth:imageSize.width];
	}
	else
	{
		NSSize objectSize = [(NSImage *)object size];
		objectFrame = NSMakeRect(0, 0, objectSize.width, objectSize.height);
	}
	
	CGFloat width;
	CGFloat height;
	
	if (isString | isAttributedString)
	{
		width = imageSize.width - leftMargin - rightMargin;
		height = objectFrame.size.height + 10;
	}
	else
	{
		width = [[settings objectForKey:@"Width"] intValue];
		height = [[settings objectForKey:@"Height"] intValue];
	}
	
	CGFloat x = leftMargin;
	CGFloat y = bottomMargin;
	
	if ([vAlignString isEqualTo:@"top"])
		y = imageSize.height - height - topMargin - (boxMarge * 2);
	else if ([vAlignString isEqualTo:@"center"])
		y = (imageSize.height - height) / 2 + (bottomMargin - topMargin);
	else if ([vAlignString isEqualTo:@"bottom"])
		y = 0 + bottomMargin;
	
	if (isString | isAttributedString)
	{
		NSMutableParagraphStyle *centeredStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	
		if ([hAlignString isEqualTo:@"center"])
			[centeredStyle setAlignment:NSCenterTextAlignment];
		else if ([hAlignString isEqualTo:@"left"])
			[centeredStyle setAlignment:NSLeftTextAlignment];
		else if ([hAlignString isEqualTo:@"right"])
			[centeredStyle setAlignment:NSRightTextAlignment];
		
		NSDictionary *attsDict;
		
		if (isString)
			attsDict = [NSDictionary dictionaryWithObjectsAndKeys:centeredStyle, NSParagraphStyleAttributeName, fontColor, NSForegroundColorAttributeName, [NSNumber numberWithInteger:NSNoUnderlineStyle], NSUnderlineStyleAttributeName, nil];
		else
			attsDict = attsDict = [NSDictionary dictionaryWithObjectsAndKeys:centeredStyle, NSParagraphStyleAttributeName, nil];
		
		[attrStr addAttributes:attsDict range:NSMakeRange(0, [[attrStr string] length])];
		
		NSDictionary *strokeAttsDict;
		
		if (border)
			strokeAttsDict = [NSDictionary dictionaryWithObjectsAndKeys:borderSize, NSStrokeWidthAttributeName , borderColor, NSStrokeColorAttributeName, centeredStyle, NSParagraphStyleAttributeName, [NSNumber numberWithInteger:NSNoUnderlineStyle], NSUnderlineStyleAttributeName, nil];
		
		[centeredStyle release];
		
		if (border)
			[strokeAttrStr addAttributes:strokeAttsDict range:NSMakeRange(0, [[strokeAttrStr string] length])];
	}
	else
	{
		if ([hAlignString isEqualTo:@"center"])
			x = leftMargin + ((imageSize.width - width) / 2) - rightMargin;
		else if ([hAlignString isEqualTo:@"right"])
			x = (imageSize.width - width - rightMargin);
	}
		
	[subImage lockFocus];
	
	if (isString | isAttributedString)
	{
		if (box)
		{
			NSSize attrSize = [attrStr size];
			NSInteger boxX;
			
			if ([hAlignString isEqualTo:@"center"])
				boxX = leftMargin + ((imageSize.width - attrSize.width) / 2) - rightMargin - boxMarge;
			else if ([hAlignString isEqualTo:@"right"])
				boxX = (imageSize.width - attrSize.width - rightMargin - boxMarge);
			else
				boxX = x;
		
			[[boxColor colorWithAlphaComponent:boxAlpha] set];
			
			NSBezierPath *path = [NSBezierPath bezierPathWithRect:NSMakeRect(boxX, y, attrSize.width + boxMarge * 2, height + boxMarge * 2)];
			[path fill];
		}
		
		if (!box)
			boxMarge = 0;
			
		NSGraphicsContext* currentContent = [NSGraphicsContext currentContext];
		CGContextRef cgContext = (CGContextRef)[currentContent graphicsPort];

		[currentContent saveGraphicsState];
		[currentContent setCompositingOperation:NSCompositeSourceOver];
		CGContextSetAlpha(cgContext, alphaValue);
	
		[attrStr drawInRect:NSMakeRect(x + boxMarge, y + boxMarge, width - (boxMarge * 2), height)];
		
		if (border)
			[strokeAttrStr drawInRect:NSMakeRect(x, y, width, height)];

		[attrStr release];
		attrStr = nil;
		
		if (border)
		{
			[strokeAttrStr release];
			strokeAttrStr = nil;
		}
	}
	else
	{
		[(NSImage *)object drawInRect:NSMakeRect(x, y, width, height) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:alphaValue];
	}
		
	[subImage unlockFocus];
		
	return [subImage autorelease];
}

+ (NSMutableAttributedString *)initOnMainThreadWithHTML:(NSString *)html
{
	SEL theSelector = @selector(initWithHTML:);
	NSMethodSignature *aSignature;
	NSInvocation *anInvocation;

	//Get the methods signature and set the selector
	aSignature = [[MCCommonMethods class] instanceMethodSignatureForSelector:theSelector];
	anInvocation = [NSInvocation invocationWithMethodSignature:aSignature];
	[anInvocation setSelector:theSelector];
	//Set arguments
	[anInvocation setArgument:&html atIndex:2];
	//Perform selector
	MCCommonMethods *object = [[MCCommonMethods alloc] init];
	
	[anInvocation performSelectorOnMainThread:@selector(invokeWithTarget:) withObject:object waitUntilDone:YES];
	
	NSMutableAttributedString *attString;
	[anInvocation getReturnValue:&attString];
	
	return attString;
}

- (NSMutableAttributedString *)initWithHTML:(NSString *)html
{
	return [[NSMutableAttributedString alloc] initWithHTML:[html dataUsingEncoding:NSUTF8StringEncoding] options:[NSDictionary dictionaryWithObjectsAndKeys:@"utf-8", @"TextEncodingName", nil] documentAttributes:nil];
}

+ (NSRect)frameForStringDrawing:(NSAttributedString *)myString forWidth:(float)myWidth
{
	NSTextStorage *textStorage = [[[NSTextStorage alloc] initWithAttributedString:myString] autorelease];
	NSTextContainer *textContainer = [[[NSTextContainer alloc] initWithContainerSize:NSMakeSize(myWidth, FLT_MAX)] autorelease];;
	NSLayoutManager *layoutManager = [[[NSLayoutManager alloc] init] autorelease];
	[layoutManager addTextContainer:textContainer];
	[textStorage addLayoutManager:layoutManager];
	[textContainer setLineFragmentPadding:0.0];

	(void) [layoutManager glyphRangeForTextContainer:textContainer];
	return [layoutManager usedRectForTextContainer:textContainer];
}

+ (void)setViewOptions:(NSArray *)views infoObject:(id)info fallbackInfo:(id)fallback mappingsObject:(NSArray *)mappings startCount:(NSInteger)start
{
	NSEnumerator *iter = [[[NSEnumerator alloc] init] autorelease];
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
			NSInteger tag = [cntl tag] - start;

			if ([cntl isKindOfClass:[NSTabView class]])
			{
				[MCCommonMethods setViewOptions:[(NSTabView *)cntl tabViewItems] infoObject:info fallbackInfo:fallback mappingsObject:mappings startCount:start];
			}
			else if ([cntl isKindOfClass:[NSBox class]])
			{
				[MCCommonMethods setViewOptions:[(NSBox *)cntl subviews] infoObject:info fallbackInfo:fallback mappingsObject:mappings startCount:start];
			}
			else if (tag > 0)
			{
				NSInteger index = tag - 1;

				if (index < [mappings count])
				{
					NSString *currentKey = [mappings objectAtIndex:index];
					id property = [info objectForKey:currentKey];
					
					if (property == nil && fallback != nil)
						property = [fallback objectForKey:currentKey];
					
					[MCCommonMethods setProperty:property forControl:cntl];

					property = nil;
				}
			}
		}
	}
}

+ (void)setProperty:(id)property forControl:(id)control
{
	if (property)
	{
		if ([control isKindOfClass:[NSTextField class]])
		{
			[control setObjectValue:property];
		}
		else if ([[control cell] isKindOfClass:[MCCheckBoxCell class]])
		{
			[(MCCheckBoxCell *)[control cell] setStateWithoutSelecting:NSOnState];
		}
		else
		{
			[control setObjectValue:property];
		}
						
		[control setEnabled:YES];
	}
	else if ([control isKindOfClass:[MCPopupButton class]])
	{
		[(MCPopupButton *)control selectItemAtIndex:0];
	}
	else if (![control isKindOfClass:[NSButton class]])
	{
		if ([control tag] < 100)
			[control setEnabled:NO];
		else
			[control setStringValue:@""];
	}
	else if ([[control cell] isKindOfClass:[MCCheckBoxCell class]])
	{
		[(MCCheckBoxCell *)[control cell] setStateWithoutSelecting:NSOffState];
	}
	else if ([control isKindOfClass:[NSButton class]])
	{
		[control setState:NSOffState];
	}
}

+ (NSArray *)defaultHorizontalPopupArray
{
	NSMutableArray *horizontalAlignments = [NSMutableArray array];
	[horizontalAlignments insertObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Left", nil), @"Name", @"left", @"Format", nil] atIndex:0];
	[horizontalAlignments insertObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Center", nil), @"Name", @"center", @"Format", nil] atIndex:1];
	[horizontalAlignments insertObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Right", nil), @"Name", @"right", @"Format", nil] atIndex:2];
	
	return horizontalAlignments;
}

+ (NSArray *)defaultVerticalPopupArray
{
	NSArray *names = [NSArray arrayWithObjects:NSLocalizedString(@"Top", nil), NSLocalizedString(@"Center", nil), NSLocalizedString(@"Bottom", nil), nil];
	NSArray *formats = [NSArray arrayWithObjects:@"top", @"center", @"bottom", nil];
	
	return [MCCommonMethods popupArrayWithNames:names forFormats:formats];
}

+ (NSMutableArray *)popupArrayWithNames:(NSArray *)names forFormats:(NSArray *)formats
{
	NSMutableArray *newArray = [NSMutableArray array];

	NSInteger i;
	for (i = 0; i < [formats count]; i ++)
	{
		NSString *format = [formats objectAtIndex:i];
		NSString *name = [names objectAtIndex:i];
		
		NSDictionary *popupDictionary = [NSDictionary dictionaryWithObjectsAndKeys:name, @"Name", format, @"Format", nil];
		
		[newArray addObject:popupDictionary];
	}
	
	return newArray;
}

@end