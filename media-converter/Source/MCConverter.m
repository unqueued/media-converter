//
//  MCConverter.m
//  Media Converter
//
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCConverter.h"
#import "NSNumber_Extensions.h"
#import "NSString_Extensions.h"
#import "NSArray_Extensions.h"
#import "MCFilter.h"
#import "MCPresetManager.h"

@implementation MCConverter

/////////////////////
// Default actions //
/////////////////////

#pragma mark -
#pragma mark •• Default actions

- (id)init
{
	self = [super init];

	status = 0;
	userCanceled = NO;
	
	convertedFiles = [[NSMutableArray alloc] init];
	
	NSArray *oldLanguageCodes = [NSArray arrayWithObjects:	@"alb", @"arm", @"baq", @"bur", @"chi", @"ger", @"fre", @"geo", @"gre", 
															@"ice", @"scr", @"mac", @"may", @"dut", @"per", @"rum", @"scc", @"slo", 
															@"tib", @"cze", @"wel", @"al", @"am", @"ba", @"cn", @"cz", @"dk", @"jp", 
															@"gr", @"zh_TW", @"zh_CN", @"chs", @"cht", nil];
															
	NSArray	*newLanguageCodes = [NSArray arrayWithObjects:	@"sqi", @"hye", @"eus", @"mya", @"zho", @"deu", @"fra", @"kat", @"ell", 
															@"isl", @"hrv", @"mkd", @"msa", @"nld", @"fas", @"ron", @"srp", @"slk", 
															@"bod", @"ces", @"cym", @"sq", @"hy", @"bs", @"zhs", @"cs", @"da", @"ja", 
															@"el", @"zht", @"zhs", @"zhs", @"zht", nil];
															
	oldToNewLanguageCodes = [NSDictionary dictionaryWithObjects:newLanguageCodes forKeys:oldLanguageCodes];
	
	cyrillicLanguages = [NSArray arrayWithObjects:			@"abk", @"ab", @"ava", @"av", @"aze", @"az", @"bak", @"ba", @"bel", @"be",
															@"bul", @"bg", @"che", @"ce", @" chu", @"cu", @"chv", @"cv", @"kaz", @"kk",
															@"kom", @"kv", @"mkd", @"mk", @"mon", @"mn", @"sme", @"se",
															@"ron", @"ro", @"rus", @"ru", @"srp", @"sr", @"tgk", @"tg", @"tat", @"tt", @"tuk",
															@"tk", @"ukr", @"uk", @"uzb", @"uz", nil];
															
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	[defaultCenter addObserver:self selector:@selector(cancelEncoding) name:@"MCStopConverter" object:nil];
	[defaultCenter postNotificationName:@"MCCancelNotificationChanged" object:@"MCStopConverter"];
	
	return self;
}

- (void)dealloc
{
	[convertedFiles release];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[super dealloc];
}

/////////////////////
// Encode actions //
/////////////////////

#pragma mark -
#pragma mark •• Encode actions

- (NSInteger)batchConvert:(NSArray *)files toDestination:(NSString *)destination withOptions:(NSDictionary *)options errorString:(NSString **)error
{
	//Set the options
	convertDestination = destination;
	convertExtension = [options objectForKey:@"Extension"];
	convertOptions = options;
	
	NSFileManager *defaultManager = [MCCommonMethods defaultManager];
	
	NSString *ffmpegOutput = nil;

	NSInteger i;
	for (i = 0; i < [files count]; i ++)
	{
		NSString *currentPath = [files objectAtIndex:i];
		NSString *displayName = [defaultManager displayNameAtPath:currentPath];
	
		if (userCanceled == NO)
		{
			number = i;
		
			[[NSNotificationCenter defaultCenter] postNotificationName:@"MCTaskChanged" object:[NSString stringWithFormat:NSLocalizedString(@"Encoding file %i of %i to '%@'", nil), i + 1, [files count], [options objectForKey:@"Name"]]];
		
			//Test the file on how to encode it
			NSInteger output = [self testFile:currentPath errorString:&*error];
			
			useWav = (output == 2 | output == 4 | output == 8);
			useQuickTime = (output == 2 | output == 3 | output == 6);
			
			BOOL stream = (![defaultManager fileExistsAtPath:currentPath]);
			if (stream && (useWav | useQuickTime))
			{
				NSString *streamError;
				if (useWav)
					streamError = NSLocalizedString(@"%@ (Unsupported audio)", nil);
				else
					streamError = NSLocalizedString(@"%@ (Unsupported video)", nil);
				
				[self setErrorStringWithString:[NSString stringWithFormat:streamError, displayName]];
				
				continue;
			}
					
			
			if (useWav)
				output = [self encodeAudioAtPath:currentPath errorString:&ffmpegOutput];
			else if (output != 0)
				output = [self encodeFileAtPath:currentPath errorString:&ffmpegOutput];
			else
				output = 3;
		
			if (output == 0)
			{
				NSDictionary *output = [NSDictionary dictionaryWithObjectsAndKeys:encodedOutputFile, @"Path", nil];
			
				[convertedFiles addObject:output];
			}
			else if (output == 1)
			{
				NSString *problem = NSLocalizedString(@"%@ (Unknown error)", nil);
				
				if (subtitleProblem == YES)
					problem = NSLocalizedString(@"%@ (Subtitle problem)", nil);
				
				[self setErrorStringWithString:[NSString stringWithFormat:problem, displayName]];
			}
			else if (output == 2)
			{
				if (errorString)
				{
					if (ffmpegOutput)
						*error = [NSString stringWithFormat:@"%@\nMCLog:%@", errorString, ffmpegOutput];
					else
						*error = errorString;
					
					return 1;
				}
				else
				{
					return 2;
				}
			}
		}
		else
		{
			if (errorString)
			{
				if (ffmpegOutput)
					*error = [NSString stringWithFormat:@"%@\nMCLog:%@", errorString, ffmpegOutput];
				else
					*error = errorString;
					
				return 1;
			}
			else
			{
				return 2;
			}
		}
	}
	
	if (errorString)
	{
		if (ffmpegOutput)
			*error = [NSString stringWithFormat:@"%@\nMCLog:%@", errorString, ffmpegOutput];
		else
			*error = errorString;
					
		return 1;
	}
	
	return 0;
}

//Encode the file, use wav file if quicktime created it, use pipe (from movtoy4m)
- (NSInteger)encodeFileAtPath:(NSString *)path errorString:(NSString **)error
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSFileManager *defaultManager = [MCCommonMethods defaultManager];

	//Check if the url is a YouTube url
	BOOL isYoutubeURL = [MCCommonMethods isYouTubeURLAtPath:path];
	
	// DVD Subtitle variables
	NSString *spumuxPath;
	NSString *uniqueSpumuxPath;
	
	// Reset our stuff
	subtitleProblem = NO;
	detailedErrorString = nil;
	
	NSMutableArray *options = [NSMutableArray arrayWithArray:[convertOptions objectForKey:@"Encoder Options"]];
	NSDictionary *extraOptions = [convertOptions objectForKey:@"Extra Options"];
	
	// Encoder options for ffmpeg, movtoy4m
	NSString *fileName;
	
	if (isYoutubeURL)
		fileName = [self getYouTubeName:path];
	else
		fileName = [[[path lastPathComponent] stringByDeletingPathExtension] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		
	NSString *outFileWithExtension = [MCCommonMethods uniquePathNameFromPath:[NSString stringWithFormat:@"%@/%@.%@", convertDestination, fileName, convertExtension] withSeperator:@" "];
	NSString *outputFile = [outFileWithExtension stringByDeletingPathExtension];
	temporaryFolder = [[NSString alloc] initWithString:[NSTemporaryDirectory() stringByAppendingPathComponent:@"MCTemp"]];
	[MCCommonMethods createDirectoryAtPath:temporaryFolder errorString:nil];
	
	NSString *subtitleType = [extraOptions objectForKey:@"Subtitle Type"];

	if (subtitleType == nil)
		subtitleType = @"none";
	
	NSDictionary *streamDictionary = [self firstAudioAndVideoStreamAtPath:path];

	//No need to use subtitles with no video
	if ([streamDictionary objectForKey:@"Video"] == nil)
		subtitleType = @"none";

	NSString *temporarySubtitleFile = nil;
	
	NSArray *quicktimeOptions = [NSArray array];
	NSArray *wavOptions = [NSArray array];
	NSArray *inputOptions = [NSArray array];
	
	NSArray *padOptions = [NSArray array];
	
	NSString *aspectString = nil;
	
	if (![options objectForKey:@"-r"])
		[options setObject:[NSString stringWithFormat:@"%.2f", inputFps] forKey:@"-r"];

	if ([[extraOptions objectForKey:@"Auto Size"] boolValue] == YES && [options objectForKey:@"-s"])
	{
		[options setObject:nil forKey:@"-aspect"];
		
		//Must be a better way since multiple videofilters can be set
		//if ([[options objectForKey:@"-vf"] rangeOfString:@"setdar"].length > 0)
		//	[options setObject:nil forKey:@"-vf"];
	
		NSString *newSizeString;

		NSString *sizeString = [options objectForKey:@"-s"];
		NSArray *sizeParts = [sizeString componentsSeparatedByString:@"x"];
		CGFloat width = [[sizeParts objectAtIndex:0] cgfloatValue];

		CGFloat aspect;
		if (inputAspect <= (CGFloat)4 / (CGFloat)3)
		{
			aspectString = @"4:3";
			aspect = (CGFloat)4 / (CGFloat)3;
		}
		else
		{
			aspectString = @"16:9";
			aspect = (CGFloat)16 / (CGFloat)9;
		}
		
		newSizeString = [NSString stringWithFormat:@"%ix%i", (NSInteger)width, evenInteger((NSInteger)(width / aspect))];
		
		[options setObject:newSizeString forKey:@"-s"];
	}
	else if ([[extraOptions objectForKey:@"Auto Aspect"] boolValue] == YES)
	{
		NSString *newAspectString;
		
		if (inputAspect <= (CGFloat)4 / (CGFloat)3)
			newAspectString = @"4:3";
		else
			newAspectString = @"16:9";
	
		[options setObject:newAspectString forKey:@"-aspect"];
		[options setObject:[NSString stringWithFormat:@"setdar=%@", newAspectString] forKey:@"-vf"];
	}
	
	NSString *padString = nil;
	NSString *sizeString = [options objectForKey:@"-s"];

	NSSize movieSize = NSMakeSize((CGFloat)inputWidth, (CGFloat)inputHeight);
	if (sizeString)
	{
		NSArray *sizeParts = [sizeString componentsSeparatedByString:@"x"];
		CGFloat width = [[sizeParts objectAtIndex:0] cgfloatValue];
		CGFloat height = [[sizeParts objectAtIndex:1] cgfloatValue];
		movieSize = NSMakeSize(width, height);
		
		NSInteger keepAspect = [[extraOptions objectForKey:@"Keep Aspect"] integerValue];
		
		if (keepAspect > 0)
		{
			if (!aspectString)
				aspectString = [options objectForKey:@"-aspect"];
			
			CGFloat aspectWidth;
			CGFloat aspectHeight;
			
			if (aspectString)
			{
				NSArray *aspectParts = [aspectString componentsSeparatedByString:@":"];
				aspectWidth = [[aspectParts objectAtIndex:0] cgfloatValue];
				aspectHeight = [[aspectParts objectAtIndex:1] cgfloatValue];
					
				if ((width / height) > (aspectWidth / aspectHeight))
					height = evenInteger((NSInteger)(width / (aspectWidth / aspectHeight)));
				else
					width = evenInteger((NSInteger)(height * (aspectWidth / aspectHeight)));
			}
			else
			{
				aspectWidth = width;
				aspectHeight = height;
			}
			
			if (inputAspect != (aspectWidth / aspectHeight))
			{
				BOOL largerOutputAspect = ((aspectWidth / aspectHeight) > inputAspect);
				movieSize = NSMakeSize(width, height);
					
				NSInteger newWidth = width;
				NSInteger newHeight = height;
		
				if (keepAspect == 1)
				{
					NSInteger padX = 0;
					NSInteger padY = 0;
						
					if (largerOutputAspect)
					{
						padX = evenInteger((NSInteger)(((width * aspectWidth / aspectHeight) / ((CGFloat)inputWidth / (CGFloat)inputHeight) - width) / 2.0));
						newWidth = (NSInteger)width - (padX * 2.0);
					}
					else
					{
						padY = evenInteger((NSInteger)((height - (height * (aspectWidth / aspectHeight) / ((CGFloat)inputWidth / (CGFloat)inputHeight))) / 2.0));
						newHeight = (NSInteger)height - (padY * 2.0);
					}
						
					padString = [NSString stringWithFormat:@"scale=%i:%i,pad=%i:%i:%i:%i:black", (NSInteger)newWidth, (NSInteger)newHeight, (NSInteger)width, (NSInteger)height, padX, padY];
				}
				else
				{
					NSInteger cropX = 0;
					NSInteger cropY = 0;
		
					if (largerOutputAspect)
					{
						newHeight = evenInteger((NSInteger)((width / (CGFloat)inputWidth) * (CGFloat)inputHeight));
						cropY = (NSInteger)(((CGFloat)newHeight - height) / 2.0);
					}
					else
					{
						newWidth = evenInteger((NSInteger)(width / (aspectWidth / aspectHeight) * ((CGFloat)inputWidth / (CGFloat)inputHeight)));
						cropX = (newWidth - width) / 2.0;
					}
				
					padString = [NSString stringWithFormat:@"scale=%i:%i,crop=%i:%i:%i:%i:0", (NSInteger)newWidth, (NSInteger)newHeight, (NSInteger)width, (NSInteger)height, (NSInteger)cropX, (NSInteger)cropY];
				}
			}
		}
		
		if (!padString)
			padString = [NSString stringWithFormat:@"scale=%i:%i", (NSInteger)width, (NSInteger)height];
		
		[options setObject:padString forKey:@"-vf"];
	}
	
	NSInteger passes = 1;
	if ([[extraOptions objectForKey:@"Two Pass"] boolValue] == YES)
		passes = 2;
		
	NSString *displayName;
	if (isYoutubeURL)
		displayName = fileName;
	else
		displayName  = [[[MCCommonMethods defaultManager] displayNameAtPath:path] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

	if (![subtitleType isEqualTo:@"none"] && ![subtitleType isEqualTo:@"dvd"])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MCStatusChanged" object:[NSString stringWithFormat:NSLocalizedString(@"Converting subtitles: %@…", nil), displayName]];
		temporarySubtitleFile = [[temporaryFolder stringByAppendingPathComponent:@"tmpmovie"] stringByAppendingPathExtension:subtitleType];
		BOOL createdFile = [self createMovieWithSubtitlesAtPath:temporarySubtitleFile inputFile:path ouputType:subtitleType currentOptions:options withSize:movieSize];

		//When the're no subtitle files the above method will fail
		if (createdFile == NO)
			subtitleType = @"none";
	}

	NSInteger taskStatus = 1;
	NSMutableString *ffmpegErrorString = nil;
	
	if (!userCanceled)
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MCStatusChanged" object:[NSLocalizedString(@"Encoding: ", Localized) stringByAppendingString:displayName]];
	
		NSInteger pass;
		for (pass = 0; pass < passes; pass ++)
		{
			ffmpeg = [[NSTask alloc] init];
			NSPipe *pipe2;
			NSPipe *errorPipe;
		
			if (isYoutubeURL)
				[self downloadYouTubeURL:path toTask:ffmpeg outPipe:nil];

			//Check if we need to use movtoy4m to decode
			if (useQuickTime == YES)
			{
				quicktimeOptions = [NSArray arrayWithObjects:@"-f", @"yuv4mpegpipe", @"-i", @"-", nil];
	
				movtoy4m = [[NSTask alloc] init];
				pipe2 = [[NSPipe alloc] init];
				[movtoy4m setLaunchPath:[[NSBundle mainBundle] pathForResource:@"movtoy4m" ofType:@""]];
				[movtoy4m setArguments:[NSArray arrayWithObjects:@"-w",[NSString stringWithFormat:@"%i", inputWidth],@"-h",[NSString stringWithFormat:@"%i", inputHeight],@"-F",[NSString stringWithFormat:@"%f:1", inputFps],@"-a",[NSString stringWithFormat:@"%i:%i", inputWidth, inputHeight], path, nil]];
				[movtoy4m setStandardOutput:pipe2];
		
				if ([defaults boolForKey:@"MCDebug"] == NO)
				{
					errorPipe = [[NSPipe alloc] init];
					[movtoy4m setStandardError:[NSFileHandle fileHandleWithNullDevice]];
				}
	
				[ffmpeg setStandardInput:pipe2];
				[MCCommonMethods logCommandIfNeeded:movtoy4m];
				[movtoy4m launch];
			}
	
			if (useWav == YES)
			{
				wavOptions = [NSArray arrayWithObjects:@"-i", [outputFile stringByAppendingString:@" (tmp).wav"], nil];
			}
		
			if (isYoutubeURL)
			{
				inputOptions = [NSArray arrayWithObjects:@"-i", @"-", nil];
			}
			else if (useWav == NO | useQuickTime == NO)
			{
				inputOptions = [NSArray arrayWithObjects:@"-i", path, nil];
			}

			NSPipe *pipe = [[NSPipe alloc] init];
			NSFileHandle *handle;
			NSData *data;
	
			[ffmpeg setLaunchPath:[MCCommonMethods ffmpegPath]];
	
			NSMutableArray *args = [NSMutableArray array];
		
			NSString *timeLimit = [options objectForKey:@"-t"];
			if (timeLimit != nil)
			{
				[args addObject:@"-t"];
				[args addObject:timeLimit];
			}
		
			[args addObjectsFromArray:quicktimeOptions];
			[args addObjectsFromArray:wavOptions];
			[args addObjectsFromArray:inputOptions];
	
			NSString *threads = @"1";
	
			NSInteger x;
			for (x = 0; x < [options count]; x ++)
			{
				NSDictionary *dict = [options objectAtIndex:x];
				NSString *key = [[dict allKeys] objectAtIndex:0];
				NSString *object = [dict objectForKey:key];
		
				if ([key isEqualTo:@"-threads"])
				{
					threads = object;
				}
				else if (![key isEqualTo:@"-t"])
				{
					[args addObject:key];
			
					if (![object isEqualTo:@""])
						[args addObject:object];
				}
			}
		
			if ([subtitleType isEqualTo:@"mkv"])
			{
				[args addObject:@"-scodec"];
				[args addObject:@"copy"];
			}
			else if ([subtitleType isEqualTo:@"none"])
			{
				[args addObject:@"-sn"];
			}
	
			NSArray *threadObjects = [NSArray arrayWithObjects:@"-threads", threads, nil];
			NSString *pathExtension = [outFileWithExtension pathExtension];
			if ([pathExtension isEqualTo:@"mov"] | [pathExtension isEqualTo:@"m4v"] | [pathExtension isEqualTo:@"mp4"])
				[args addObjectsFromArray:threadObjects];
			else
				[args insertObjects:threadObjects atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)]];
	
			NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
			[args addObjectsFromArray:padOptions];
			[args addObject:@"-metadata"];
			[args addObject:[NSString stringWithFormat:@"frontend=Media Encoder %@", version]];
		
			NSString *vfFilterString = @"";
			NSArray *vfFilters = [options objectsForKey:@"-vf"];
			NSString *movieString = @"";
			BOOL useHardSubtitles = ([subtitleType isEqualTo:@"hard"]);
			NSString *overlayString = @"";
			NSArray *filters = [convertOptions objectForKey:@"Video Filters"];
		
			NSInteger outCount = 0;
			NSString *outString = @"[out]";
			NSString *inString = @"[in]";
		
			if ([vfFilters count] > 0)
			{
				NSInteger y;
				for (y = 0; y < [vfFilters count]; y ++)
				{
					if (y > 0)
						inString = [NSString stringWithFormat:@"[out%i]", outCount - 1];
				
					if (y == [vfFilters count] - 1 && !(useHardSubtitles | [filters count] > 0))
					{
						outString = @"[out]";
					}
					else
					{
						outString = [NSString stringWithFormat:@"[out%i]", outCount];
						outCount =+ 1;
					}
			
					NSString *vfFilter = [vfFilters objectAtIndex:y];
					vfFilterString = [NSString stringWithFormat:@"%@%@%@%@", vfFilterString, inString, vfFilter, outString];
				
					if (y == [vfFilters count] - 1 && (useHardSubtitles | [filters count] > 0))
						vfFilterString = [NSString stringWithFormat:@"%@;", vfFilterString];
				}
			}
		
		
			if ([filters count] > 0)
			{
				NSString *newImagePath = [temporaryFolder stringByAppendingPathComponent:@"overlay.png"];
			
				NSString *sizeString = [options objectForKey:@"-s"];
				CGFloat width;
				CGFloat height;

				if (sizeString)
				{
					NSArray *sizeParts = [sizeString componentsSeparatedByString:@"x"];
					width = [[sizeParts objectAtIndex:0] cgfloatValue];
					height = [[sizeParts objectAtIndex:1] cgfloatValue];
				}
				else
				{
					width = (CGFloat)inputWidth;
					height = (CGFloat)inputHeight;
				}
			
				NSImage *overlayImage = [[NSImage alloc] initWithSize:NSMakeSize(width, height)];

				NSInteger z;
				for (z = 0; z < [filters count]; z ++)
				{
					NSDictionary *filterDictionary = [filters objectAtIndex:z];
					MCFilter *filter = [[NSClassFromString([filterDictionary objectForKey:@"Type"]) alloc] init];
					[filter setOptions:[filterDictionary objectForKey:@"Options"]];
				
					NSImage *filterImage = [filter imageWithSize:NSMakeSize(width, height)];

					if (filterImage != nil)
					{
						[overlayImage lockFocus];
						[filterImage drawInRect:NSMakeRect(0, 0, width, height) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
						[overlayImage unlockFocus];
					}
				}
			
				NSData *tiffData = [overlayImage TIFFRepresentation];
				NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:tiffData];
				NSData *imageData = [bitmap representationUsingType:NSPNGFileType properties:nil];
				
				NSError *writeError;
				BOOL succes = [imageData writeToFile:newImagePath options:NSAtomicWrite error:&writeError];
			
				[overlayImage release];
				
				if (succes == NO && writeError != nil)
					NSLog(@"Error: %@", writeError);
				
				if ([vfFilters count] > 0)
					inString = outString;
			
				NSString *outString = @"[out]";
				NSString *myString = @"[wm]";

				if ([subtitleType isEqualTo:@"hard"])
				{
					outString = [NSString stringWithFormat:@"[out%i];", outCount];
					myString = @"[wm0]";
				}
			
				movieString = [NSString stringWithFormat:@"movie=%@ %@;", newImagePath, myString];
				overlayString = [NSString stringWithFormat:@"%@%@ overlay=0:0 %@", inString, myString, outString];
			}
		
			if ([subtitleType isEqualTo:@"hard"])
			{
				NSString *inString = @"[in]";
				NSString *myString = @"[wm]";
			
				if ([filters count] > 0)
				{
					inString = [NSString stringWithFormat:@"[out%i]", outCount];
					myString = @"[wm1]";
				}
				else if ([vfFilters count] > 0)
				{
					inString = [NSString stringWithFormat:@"[out%i]", outCount - 1];
					myString = @"[wm1]";
				}
		
				movieString = [NSString stringWithFormat:@"%@movie=%@ %@;", movieString, temporarySubtitleFile, myString];
				overlayString = [NSString stringWithFormat:@"%@%@%@ overlay=0:0 [out]", overlayString, inString, myString];
			}
		
			if ([filters count] > 0 | [subtitleType isEqualTo:@"hard"] | [vfFilters count] > 0)
			{
				[args addObject:@"-vf"];
				[args addObject:[NSString stringWithFormat:@"%@%@%@", vfFilterString, movieString, overlayString]];

				[options setObject:nil forKey:@"-vf"];
			}
		
			if (passes == 2)
				[ffmpeg setCurrentDirectoryPath:@"/tmp"];
		
			if (passes == 2 && pass == 0)
			{
				[args addObjectsFromArray:[NSArray arrayWithObjects:@"-an", @"-pass", @"1", @"-y", @"/dev/null", nil]];
			}
			else if (passes == 2 && pass == 1)
			{
				[args addObjectsFromArray:[NSArray arrayWithObjects:@"-pass", @"2", nil]];
			
				if (![subtitleType isEqualTo:@"dvd"])
					[args addObject:outFileWithExtension];
				else	
					[args addObject:@"-"];
			}
			else
			{
				if (![subtitleType isEqualTo:@"dvd"])
					[args addObject:outFileWithExtension];
				else
					[args addObject:@"-"];
			}
		
			[ffmpeg setArguments:args];
			//ffmpeg uses stderr to show the progress
			[ffmpeg setStandardError:pipe];
		
			NSPipe *outputPipe = [[NSPipe alloc] init];
			[ffmpeg setStandardOutput:outputPipe];
			handle = [pipe fileHandleForReading];
	
			ffmpegErrorString = [[NSMutableString alloc] initWithString:[MCCommonMethods logCommandIfNeeded:ffmpeg]];
			[ffmpeg launch];
		
			if ([subtitleType isEqualTo:@"dvd"])
			{
				spumuxPath = [NSHomeDirectory() stringByAppendingPathComponent:@".spumux"];
				uniqueSpumuxPath = [MCCommonMethods uniquePathNameFromPath:spumuxPath withSeperator:@"_"];
		
				if ([defaultManager fileExistsAtPath:spumuxPath])
					[MCCommonMethods moveItemAtPath:spumuxPath toPath:uniqueSpumuxPath error:nil];
			
				NSString *savedFontPath = [defaults objectForKey:@"MCFontFolderPath"];

				[defaultManager createSymbolicLinkAtPath:spumuxPath pathContent:savedFontPath];
		
				[self createMovieWithSubtitlesAtPath:outFileWithExtension inputFile:path ouputType:@"dvd" currentOptions:nil withSize:movieSize];
			}

			if (useQuickTime == YES)
				status = 3;
			else
				status = 2;

			NSString *string = nil;
	
			//Get the time we want to encode
			NSString *timeString = [options objectForKey:@"-t"];
	
			if (timeString)
				inputTotalTime = [timeString cgfloatValue];
			
			//inputTotalTime = inputTotalTime * (CGFloat)passes;
		
			BOOL started = NO;

			//Here we go
			while([data = [handle availableData] length]) 
			{
				NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
	
				if (string)
				{
					[string release];
					string = nil;
				}
	
				//The string containing ffmpeg's output
				string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	
				if ([defaults boolForKey:@"MCDebug"] == YES)
					NSLog(@"%@", string);
		
				//Format the time string ffmpeg outputs and format it to percent
				if ([string rangeOfString:@"time="].length > 0)
				{
					started = YES;
		
					NSString *timeString = [[[[string componentsSeparatedByString:@"time="] objectAtIndex:1] componentsSeparatedByString:@" "] objectAtIndex:0];
					double total_time = [MCCommonMethods secondsFromTimeString:timeString];
					CGFloat percent = (total_time + (inputTotalTime * (CGFloat)pass)) / (inputTotalTime + inputTotalTime * (passes - 1)) * 100.0;
				
					NSString *currentPass = @"";
						
					if (passes == 2)
						currentPass = [NSString stringWithFormat: @"pass %i - ", pass + 1];
				
					if (inputTotalTime > 0.0)
					{
						if (percent < 100.0)
						{
							[[NSNotificationCenter defaultCenter] postNotificationName:@"MCStatusByAddingPercentChanged" object:[NSString stringWithFormat: @" (%@%.0f%@)", currentPass, percent, @"%"]];
							[[NSNotificationCenter defaultCenter] postNotificationName:@"MCValueChanged" object:[NSNumber numberWithDouble:percent + (double)number * 100]];
						}
					}
					else
					{
						[[NSNotificationCenter defaultCenter] postNotificationName:@"MCStatusByAddingPercentChanged" object:[NSString stringWithFormat:@" (%@?%)", currentPass]];
					}
				}

				data = nil;
		
				if (started == NO)
					[ffmpegErrorString appendString:string];
	
				[innerPool release];
				innerPool = nil;
			}

			//After there's no output wait for ffmpeg to stop
			[ffmpeg waitUntilExit];

			//Check if the encoding succeeded, if not remove the mpg file ,NOT POSSIBLE :-(
			taskStatus = [ffmpeg terminationStatus];

			//Release ffmpeg
			[ffmpeg release];
			ffmpeg = nil;
	
			//If we used a wav file, delete it
			if (useWav == YES)
				[MCCommonMethods removeItemAtPath:[outputFile stringByAppendingString:@" (tmp).wav"]];
	
			if (useQuickTime == YES)
			{	
				[movtoy4m release];
				movtoy4m = nil;
		
				[pipe2 release];
				pipe2 = nil;
			}
	
			[pipe release];
			pipe = nil;

			if (taskStatus != 0)
			{
				break;
			}
			else
			{
				[ffmpegErrorString release];
				ffmpegErrorString = nil;
			}
		
			[string release];
			string = nil;
		}
	
		//Do some other stuff with the movie if encoding succeeded
		if (taskStatus == 0)
		{
			if ([[extraOptions objectForKey:@"Start Atom"] boolValue] == YES)
			{
				status = 4;
				qtfaststart = [[NSTask alloc] init];
				[qtfaststart setLaunchPath:[[NSBundle mainBundle] pathForResource:@"qt-faststart" ofType:@""]];
				NSString *extension = [outFileWithExtension pathExtension];
				NSString *extensionlessFile = [outFileWithExtension stringByDeletingPathExtension];
				NSString *tempFile = [MCCommonMethods uniquePathNameFromPath:[NSString stringWithFormat:@"%@ (tmp).%@", extensionlessFile, extension] withSeperator:@" "];
				[qtfaststart setArguments:[NSArray arrayWithObjects:outFileWithExtension, tempFile, nil]];
				[qtfaststart launch];
				[qtfaststart waitUntilExit];
				taskStatus = [qtfaststart terminationStatus];
			
				if (taskStatus == 0)
				{
					[MCCommonMethods removeItemAtPath:outFileWithExtension];
					[MCCommonMethods moveItemAtPath:tempFile toPath:outFileWithExtension error:nil];
				}
				else
				{
					if (ffmpegErrorString)
					{
						[ffmpegErrorString release];
						ffmpegErrorString = nil;
					}
			
					ffmpegErrorString = [[NSMutableString alloc] initWithString:@"Failed to set moov atom to the start of the file"];
				}
		
				[qtfaststart release];
				qtfaststart = nil;
			}

			if (temporarySubtitleFile && [defaultManager fileExistsAtPath:temporarySubtitleFile])
			{
				if ([subtitleType isEqualTo:@"mp4"])
				{
					[self addTracksFromMP4Movie:temporarySubtitleFile toPath:outFileWithExtension];
				}
				else if ([subtitleType isEqualTo:@"kate"])
				{
					NSString *temporaryFile = [temporaryFolder stringByAppendingPathComponent:[outFileWithExtension lastPathComponent]];
					BOOL result = [self addTracksFromOGGMovies:[NSArray arrayWithObjects:outFileWithExtension, temporarySubtitleFile, nil] toPath:temporaryFile];
	
					if (result)
					{
						[MCCommonMethods removeItemAtPath:outFileWithExtension];
						[MCCommonMethods moveItemAtPath:temporaryFile toPath:outFileWithExtension error:nil];
					}
				}
				else if ([subtitleType isEqualTo:@"mkv"])
				{
					NSString *temporaryFile = [temporaryFolder stringByAppendingPathComponent:[outFileWithExtension lastPathComponent]];
					BOOL result = [self addTracksFromMKVMovie:[NSArray arrayWithObjects:outFileWithExtension, temporarySubtitleFile, nil] toPath:temporaryFile];
	
					if (result)
					{
						[MCCommonMethods removeItemAtPath:outFileWithExtension];
						[MCCommonMethods moveItemAtPath:temporaryFile toPath:outFileWithExtension error:nil];
					}
				}
			}
		
			encodedOutputFile = outFileWithExtension;
		
			if ([subtitleType isEqualTo:@"srt"])
				[self extractSubtitlesFromMovieAtPath:path toPath:[outFileWithExtension stringByDeletingPathExtension] shouldRename:YES];
		}
	
		if ([subtitleType isEqualTo:@"dvd"])
		{
			[MCCommonMethods removeItemAtPath:spumuxPath];
			
			if ([defaultManager fileExistsAtPath:uniqueSpumuxPath])
				[MCCommonMethods moveItemAtPath:uniqueSpumuxPath toPath:spumuxPath error:nil];
		}
	}

	[MCCommonMethods removeItemAtPath:temporaryFolder];
	[temporaryFolder release];
	temporaryFolder = nil;
	
	//Return if ffmpeg failed or not
	if (taskStatus == 0)
	{
		status = 0;
	
		return 0;
	}
	else if (userCanceled == YES)
	{
		status = 0;
		
		[MCCommonMethods removeItemAtPath:outFileWithExtension];
		
		return 2;
	}
	else
	{
		status = 0;
		
		[MCCommonMethods removeItemAtPath:outFileWithExtension];
		
		if (detailedErrorString != nil)
		{
			*error = [NSString stringWithString:detailedErrorString];
			
			[detailedErrorString release];
			detailedErrorString = nil;
		}
		else
		{
			if (*error != nil)
				*error = [NSString stringWithFormat:@"%@\n\n%@", *error, ffmpegErrorString];
			else
				*error = [NSString stringWithString:ffmpegErrorString];
		}
			
		[ffmpegErrorString release];
		ffmpegErrorString = nil;
		
		return 1;
	}
}

//Encode sound to wav
- (NSInteger)encodeAudioAtPath:(NSString *)path errorString:(NSString **)error
{
	NSFileManager *defaultFileManager = [MCCommonMethods defaultManager];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MCStatusChanged" object:[NSString stringWithFormat:NSLocalizedString(@"Decoding sound: %@", nil), [defaultFileManager displayNameAtPath:path]]];

	//Output file (without extension)
	NSString *outputName = [[path lastPathComponent] stringByDeletingPathExtension];
	outputName = [NSString stringWithFormat:@"%@ (tmp).wav", outputName];
	NSString *outputFile = [MCCommonMethods uniquePathNameFromPath:[convertDestination stringByAppendingPathComponent:outputName] withSeperator:@"-"];
	
	//movtowav encodes quicktime movie's sound to wav
	movtowav = [[NSTask alloc] init];
	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"movtowav" ofType:@""];
	NSArray *arguments = [NSArray arrayWithObjects:@"-o", outputFile, path, nil];
	
	NSString *string;
	BOOL result = [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:YES outputString:NO output:&string inputPipe:nil predefinedTask:movtowav];

	status = 1;
	
	//Check if it all went OK if not remove the wave file and return NO
    if (result == NO)
	{
		[MCCommonMethods removeItemAtPath:outputFile];
	
		status = 0;
		
		if (userCanceled == YES)
		{
			return 2;
		}
		else
		{
			*error = string;

			return 1;
		}
	}
	
	return [self encodeFileAtPath:path errorString:&*error];	
}

//Stop encoding (stop ffmpeg, movtowav and movtoy4m if they're running
- (void)cancelEncoding
{
	userCanceled = YES;
	
	if (status == 1 | status == 3)
		[movtowav terminate];
	
	if (status == 2 | status == 3)
		[ffmpeg terminate];
	
	if (status == 4)
		[qtfaststart terminate];
}

/////////////////////
// Test actions //
/////////////////////

#pragma mark -
#pragma mark •• Test actions

//Test if ffmpeg can encode, sound and/or video, and if it does have any sound
- (NSInteger)testFile:(NSString *)path errorString:(NSString **)ffmpegError
{
	NSString *displayName = [[MCCommonMethods defaultManager] displayNameAtPath:path];
	NSString *tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tmpkf"];
	
	BOOL audioWorks = YES;
	BOOL videoWorks = YES;
	BOOL keepGoing = YES;
	
	NSArray *options = [convertOptions objectForKey:@"Encoder Options"];
	
	BOOL needsAudio = ([options objectForKey:@"-vn"] != nil);
	BOOL needsVideo = ([options objectForKey:@"-an"] != nil);

	while (keepGoing == YES)
	{
		BOOL isYoutubeURL = ([path rangeOfString:@"youtube.com/"].length > 0 && [path rangeOfString:@"http://"].length > 0);
		
		NSString *outputPath = path;
		
		if (isYoutubeURL)
			outputPath = @"-";
			
		NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-i", outputPath,@"-t", @"1", @"-vframes", @"1", nil];
		
		NSInteger i;
		for (i = 0; i < [options count]; i ++)
		{
			NSDictionary *dict = [options objectAtIndex:i];
			NSString *key = [[dict allKeys] objectAtIndex:0];
			NSString *object = [dict objectForKey:key];
			
			if (![key isEqualTo:@"-t"] | ![key isEqualTo:@"-ss"] | ![key isEqualTo:@"-vframes"] | ![key isEqualTo:@"-dframes"])
			{
				[arguments addObject:key];
			
				if (![object isEqualTo:@""])
					[arguments addObject:object];
			}
		}
			
		if (videoWorks == NO)
			[arguments addObject:@"-vn"];
		else if (audioWorks == NO)
			[arguments addObject:@"-an"];
				
		[arguments addObjectsFromArray:[NSArray arrayWithObjects:@"-ac", @"2", @"-r", @"25", @"-y", tempFile, nil]];
		
		NSString *string;
		
		NSPipe *youtubePipe = nil;
		if (isYoutubeURL)
			[self downloadYouTubeURL:path toTask:nil outPipe:&youtubePipe];
		
		BOOL result = [MCCommonMethods launchNSTaskAtPath:[MCCommonMethods ffmpegPath] withArguments:arguments outputError:YES outputString:YES output:&string inputPipe:youtubePipe predefinedTask:nil];
		
		keepGoing = NO;
		
		NSInteger code = 0;
		NSString *error = NSLocalizedString(@"%@ (Unknown error)", nil);
		
		if ([string rangeOfString:@"Video: Apple Intermediate Codec"].length > 0)
		{
			if ([self setTimeAndAspectFromOutputString:string fromFile:path])
				return 2;
			else
				return 0;
		}
		
		if (result == YES)
		{
			if ([self setTimeAndAspectFromOutputString:string fromFile:path])
				return 1;
			else
				return 0;
		}
			
		if ([string rangeOfString:@"error reading header: -1"].length > 0 && [string rangeOfString:@"iDVD"].length > 0)
			code = 2;
	
		// Check if ffmpeg reconizes the file
		if ([string rangeOfString:@"Unknown format"].length > 0 && [string rangeOfString:@"Unknown format is not supported as input pixel format"].length == 0)
		{
			error = [NSString stringWithFormat:NSLocalizedString(@"%@ (Unknown format)", nil), displayName];
			[self setErrorStringWithString:error];
			
			return 0;
		}
		
		//Check if ffmpeg reconizes the codecs
		if ([string rangeOfString:@"could not find codec parameters"].length > 0)
			error = [NSString stringWithFormat:NSLocalizedString(@"%@ (Couldn't get attributes)", nil), displayName];
			
		//No audio
		if ([string rangeOfString:@"error: movie contains no audio tracks!"].length > 0 && needsAudio)
			error = [NSString stringWithFormat:NSLocalizedString(@"%@ (No audio)", nil), displayName];
	
		//Check if the movie is a (internet/local)reference file
		if ([self isReferenceMovie:string])
			code = 2;
			
		if (code == 0 | !error)
		{
			if ([string rangeOfString:@"edit list not starting at 0, a/v desync might occur, patch welcome"].length > 0)
				videoWorks = NO;
			
			if ([string rangeOfString:@"Unknown format is not supported as input pixel format"].length > 0)
				videoWorks = NO;
				
			if ([string rangeOfString:@"Resampling with input channels greater than 2 unsupported."].length > 0)
				audioWorks = NO;
			
			NSString *input = [[[[string componentsSeparatedByString:@"Output #0"] objectAtIndex:0] componentsSeparatedByString:@"Input #0"] objectAtIndex:1];
			if ([input rangeOfString:@"mp2"].length > 0 && [input rangeOfString:@"mov,"].length > 0)
				audioWorks = NO;
			
			BOOL hasVideoCheck = ([string rangeOfString:@"Video:"].length > 0);
			BOOL hasAudioCheck = ([string rangeOfString:@"Audio:"].length > 0);
			BOOL videoWorksCheck = [self streamWorksOfKind:@"Video" inOutput:string];
			BOOL audioWorksCheck = [self streamWorksOfKind:@"Audio" inOutput:string];
			
			if (hasVideoCheck && hasAudioCheck)
			{
				if (audioWorksCheck && videoWorksCheck && videoWorks && audioWorks)
				{
					code = 1;
				}
				else if (!audioWorksCheck | !videoWorksCheck)
				{
					if (videoWorks && audioWorks)
						keepGoing = YES;
				
					if (!audioWorksCheck)
						audioWorks = NO;
					else if (!videoWorksCheck)
						videoWorks = NO;
				}
			}
			else
			{
				if (!hasVideoCheck && !hasAudioCheck)
				{
					error = [NSString stringWithFormat:NSLocalizedString(@"%@ (No audio/video)", nil), displayName];
				}
				else if (!hasVideoCheck && hasAudioCheck)
				{
					if (needsVideo)
					{
						error = [NSString stringWithFormat:NSLocalizedString(@"%@ (No video)", nil), displayName];
					}
					else
					{
						code = 8;
						if (audioWorksCheck)
							code = 7;
					}
				}
				else if (hasVideoCheck && !hasAudioCheck)
				{
					if (needsAudio)
					{
						error = [NSString stringWithFormat:NSLocalizedString(@"%@ (No audio)", nil), displayName];
					}
					else
					{
						code = 6;
						if (videoWorksCheck)
							code = 5;
					}
				}
			}
		}
		
		if (!keepGoing)
		{
			if (code == 0 | !error)
			{
				if (videoWorks && !audioWorks)
				{
					if ([[[path pathExtension] lowercaseString] isEqualTo:@"mpg"] | [[[path pathExtension] lowercaseString] isEqualTo:@"mpeg"] | [[[path pathExtension] lowercaseString] isEqualTo:@"m2v"])
						error = [NSString stringWithFormat:NSLocalizedString(@"%@ (Unsupported audio)", nil), displayName];
					else
						code = 4;
				}
				else if (!videoWorks && audioWorks)
				{
					code = 3;
				}
				else if (!videoWorks && !audioWorks)
				{
					code = 2;
				}
			}
			
			//useWav = (code == 2 | code == 4 | code == 8);
			//useQuickTime = (code == 2 | code == 3 | code == 6);
			
			if (code > 0)
			{
				if ([self setTimeAndAspectFromOutputString:string fromFile:path])
					return code;
				else
					return 0;
			}
			else
			{
				if (*ffmpegError != nil)
					*ffmpegError = [NSString stringWithFormat:@"%@\n\n%@", *ffmpegError, string];
				else
					*ffmpegError = [NSString stringWithString:string];
			
				[self setErrorStringWithString:error];
				
				return 0;
			}
		}
	}
	
	[MCCommonMethods removeItemAtPath:tempFile];
	
	return 0;
}

- (BOOL)streamWorksOfKind:(NSString *)kind inOutput:(NSString *)output
{
	NSString *one = [[[[[[output componentsSeparatedByString:@"Output #0"] objectAtIndex:0] componentsSeparatedByString:@"Stream #0:0"] objectAtIndex:1] componentsSeparatedByString:@": "] objectAtIndex:1];
	NSString *two = @"";
	
	if ([output rangeOfString:@"Stream #0:1"].length > 0)
		two = [[[[[[output componentsSeparatedByString:@"Output #0"] objectAtIndex:0] componentsSeparatedByString:@"Stream #0:1"] objectAtIndex:1] componentsSeparatedByString:@": "] objectAtIndex:1];

	//Is stream 0:0 audio or video
	if ([output rangeOfString:@"for input stream #0:0"].length > 0 | [output rangeOfString:@"Error while decoding stream #0:0"].length > 0)
	{
		if ([one isEqualTo:kind])
		{
			return NO;
		}
	}
			
	//Is stream 0:1 audio or video
	if ([output rangeOfString:@"for input stream #0:1"].length > 0| [output rangeOfString:@"Error while decoding stream #0:1"].length > 0)
	{
		if ([two isEqualTo:kind])
		{
			return NO;
		}
	}
	
	return YES;
}

- (BOOL)isReferenceMovie:(NSString *)output
{
	//Found in reference or streaming QuickTime movies
	return ([output rangeOfString:@"unsupported slice header"].length > 0 | [output rangeOfString:@"bitrate: 5 kb/s"].length > 0);
}

- (BOOL)setTimeAndAspectFromOutputString:(NSString *)output fromFile:(NSString *)file
{	
	NSFileManager *defaultManager = [MCCommonMethods defaultManager];
	NSString *inputString = [[output componentsSeparatedByString:@"\nInput"] objectAtIndex:1];

	inputString = [[inputString componentsSeparatedByString:@"\nOutput"] objectAtIndex:0];

	inputWidth = 0;
	inputHeight = 0;
	inputFps = 0;
	inputTotalTime = 0.0;
	inputAspect = 0;
	inputFormat = 0;

	//Calculate the aspect ratio width / height	
	if ([inputString rangeOfString:@"Video:"].length > 0)
	{
		NSArray *resolutionArray = [[[[[inputString componentsSeparatedByString:@"Video:"] objectAtIndex:1] componentsSeparatedByString:@"\n"] objectAtIndex:0] componentsSeparatedByString:@"x"];
		
		NSString *fpsIdentifier = @" tbr";
		
		if ([inputString rangeOfString:fpsIdentifier].length == 0)
			fpsIdentifier = @" tbc";
		
		if ([inputString rangeOfString:fpsIdentifier].length == 0)
			fpsIdentifier = @" tbn";
		
		NSArray *fpsArray = [[[inputString componentsSeparatedByString:fpsIdentifier] objectAtIndex:0] componentsSeparatedByString:@","];
		
		NSInteger resolutionArrayCount = [resolutionArray count];
		
		NSArray *beforeX = [[resolutionArray objectAtIndex:resolutionArrayCount - 2] componentsSeparatedByString:@" "];
		NSArray *afterX = [[resolutionArray objectAtIndex:resolutionArrayCount - 1] componentsSeparatedByString:@" "];

		inputWidth = [[beforeX objectAtIndex:[beforeX count] - 1] integerValue];
		inputHeight = [[afterX objectAtIndex:0] integerValue];
		inputFps = [[fpsArray objectAtIndex:[fpsArray count] - 1] cgfloatValue];
	
		if (inputFps == 25 && [inputString rangeOfString:@"Video: dvvideo"].length > 0)
		{
			inputWidth = 720;
			inputHeight = 576;
		}

		inputAspect = (CGFloat)inputWidth / (CGFloat)inputHeight;
		
		if (inputWidth == 352 && (inputHeight == 288 | inputHeight == 240))
			inputAspect = (CGFloat)4 / (CGFloat)3;
		else if ((inputWidth == 480 | inputWidth == 720 | inputWidth == 784) && (inputHeight == 576 | inputHeight == 480))
			inputAspect = (CGFloat)4 / (CGFloat)3;

		//Check if the iMovie project is 4:3 or 16:9
		if ([inputString rangeOfString:@"Video: dvvideo"].length > 0)
		{
			if ([file rangeOfString:@".iMovieProject"].length > 0)
			{
				NSString *projectName = [[[[[file stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingPathExtension] lastPathComponent];
				NSString *projectLocation = [[[file stringByDeletingLastPathComponent] stringByDeletingLastPathComponent]stringByDeletingLastPathComponent];
				NSString *projectSettings = [[projectLocation stringByAppendingPathComponent:projectName] stringByAppendingPathExtension:@"iMovieProj"];
			
				if ([defaultManager fileExistsAtPath:projectSettings])
				{
					if ([[MCCommonMethods stringWithContentsOfFile:projectSettings] rangeOfString:@"WIDE"].length > 0)
					{
						inputWidth = 1024;
						inputAspect = (CGFloat)16 / (CGFloat)9;
					}
					else
					{
						inputAspect = (CGFloat)4 / (CGFloat)3;
					}
				}
			}
			else 
			{
				if ([inputString rangeOfString:@"[PAR 59:54 DAR 295:216]"].length > 0 | [inputString rangeOfString:@"[PAR 10:11 DAR 15:11]"].length)
					inputAspect = (CGFloat)4 / (CGFloat)3;
				else if ([inputString rangeOfString:@"[PAR 118:81 DAR 295:162]"].length > 0 | [inputString rangeOfString:@"[PAR 40:33 DAR 20:11]"].length)
					inputAspect = (CGFloat)16 / (CGFloat)9;
			}
		
			inputFormat = 1;
		}

		if ([inputString rangeOfString:@"DAR 16:9"].length > 0)
		{
			inputAspect = (CGFloat)16 / (CGFloat)9;
			
			if ([inputString rangeOfString:@"mpeg2video"].length > 0)
			{
				inputWidth = 1024;
				inputFormat = 2;
			}
		}
	
		//iMovie projects with HDV 1080i are 16:9, ffmpeg guesses 4:3
		if ([inputString rangeOfString:@"Video: Apple Intermediate Codec"].length > 0)
		{
			if ([file rangeOfString:@".iMovieProject"].length > 0)
			{
				inputAspect = (CGFloat)16 / (CGFloat)9;
				inputWidth = 1024;
				inputHeight = 576;
			}
		}
	}
	
	if ([inputString rangeOfString:@"DAR 119:90"].length > 0)
		inputAspect = (CGFloat)4 / (CGFloat)3;
	
	if ([inputString rangeOfString:@"Duration:"].length > 0)	
	{
		inputTotalTime = 0.0;
	
		if (![inputString rangeOfString:@"Duration: N/A,"].length > 0)
		{
			
			NSString *timeString = [[[[inputString componentsSeparatedByString:@"Duration: "] objectAtIndex:1] componentsSeparatedByString:@","] objectAtIndex:0];
			inputTotalTime = [MCCommonMethods secondsFromTimeString:timeString];
		}
	}
	
	BOOL hasOutput = YES;
		
	if (hasOutput)
	{
		return YES;
	}
	else
	{
		[self setErrorStringWithString:[NSString stringWithFormat:NSLocalizedString(@"%@ (Couldn't get attributes)", nil), [defaultManager displayNameAtPath:file]]];
		return NO;
	}
}

///////////////////////
// Compilant actions //
///////////////////////

#pragma mark -
#pragma mark •• Compilant actions

- (NSString *)ffmpegOutputForPath:(NSString *)path
{
	NSString *string;
	NSArray *arguments;
	
	BOOL isYoutubeURL = ([path rangeOfString:@"youtube.com/"].length > 0 && [path rangeOfString:@"http://"].length > 0);
	
	if (isYoutubeURL)
		arguments = [NSArray arrayWithObjects:@"-i", @"-", nil];
	else
		arguments = [NSArray arrayWithObjects:@"-i", path, nil];
	
	NSPipe *youtubePipe = nil;
	if (isYoutubeURL)
		[self downloadYouTubeURL:path toTask:nil outPipe:&youtubePipe];
	
	[MCCommonMethods launchNSTaskAtPath:[MCCommonMethods ffmpegPath] withArguments:arguments outputError:YES outputString:YES output:&string inputPipe:youtubePipe predefinedTask:nil];
	
	if (![string rangeOfString:@"Unknown format"].length > 0 && [string rangeOfString:@"Input #0"].length > 0)
		return [[string componentsSeparatedByString:@"Input #0"] objectAtIndex:1];
	else
		return nil;
}

//Check if the file is a valid media file (return YES if it is valid)
- (BOOL)isMediaFile:(NSString *)path
{
	NSString *string = [self ffmpegOutputForPath:path];

	if (string)
		return ([string rangeOfString:@"Invalid data found when processing input"].length == 0);

	return NO;
}

//Check for ac3 audio
- (BOOL)containsAC3:(NSString *)path
{
	NSString *string = [self ffmpegOutputForPath:path];
	
	if (string)
		return ([string rangeOfString:@"Audio: ac3"].length > 0);

	return NO;
}

- (NSDictionary *)firstAudioAndVideoStreamAtPath:(NSString *)path
{
	NSString *string = [self ffmpegOutputForPath:path];

	NSArray *streams = [string componentsSeparatedByString:@"Stream #"];
	NSString *videoNumber = nil;
	NSString *audioNumber = nil;
	
	NSMutableDictionary *firstStreams = [NSMutableDictionary dictionary];
	
	NSInteger i;
	for (i = 0; i < [streams count]; i ++)
	{
		NSString *streamContent = [streams objectAtIndex:i];
		NSString *streamnumber = [[[[streamContent componentsSeparatedByString:@":"] objectAtIndex:0] componentsSeparatedByString:@"("] objectAtIndex:0];
		
		if (!videoNumber && [streamContent rangeOfString:@"Video:"].length > 0)
			videoNumber = streamnumber;
		else if (!audioNumber && [streamContent rangeOfString:@"Audio:"].length > 0)
			audioNumber = streamnumber;
	}
	
	//Just a guess
	if (videoNumber)
		[firstStreams setObject:videoNumber forKey:@"Video"];
	
	if (audioNumber)
		[firstStreams setObject:audioNumber forKey:@"Audio"];

	return firstStreams;
}

//////////////////////
// Subtitle actions //
//////////////////////

#pragma mark -
#pragma mark •• Subtitle actions

//outputType: 0 = mp4, 1 = mkv, 2 = ogg (kate)
- (BOOL)createMovieWithSubtitlesAtPath:(NSString *)path inputFile:(NSString *)inFile ouputType:(NSString *)type currentOptions:(NSArray *)options withSize:(NSSize)size
{
	BOOL result;
	BOOL firstSubtitle = YES;

	//Extract subtitles from input mp4 / mkv / ogg, when possible
	NSString *subPath = [temporaryFolder stringByAppendingPathComponent:[[inFile lastPathComponent] stringByDeletingPathExtension]];
	[self extractSubtitlesFromMovieAtPath:inFile toPath:subPath shouldRename:(![type isEqualTo:@"dvd"])];
	
	NSArray *folderContents = [MCCommonMethods getFullPathsForFolders:[NSArray arrayWithObject:temporaryFolder] withType:@"srt"];
	NSMutableArray *subtitlePaths = [NSMutableArray array];
	NSMutableArray *languages = [NSMutableArray array];
	
	NSInteger i;
	for (i = 0; i < [folderContents count]; i ++)
	{
		result = YES;
	
		NSString *currentPath = [folderContents objectAtIndex:i];		
		NSString *language = [[[[currentPath stringByDeletingPathExtension] pathExtension] componentsSeparatedByString:@"_"] objectAtIndex:0];
			
		// Not working right now (would allow extra options in presets, by editing ttxt file)
		/*if ([type isEqualTo:@"mp4"])
		{
			NSString *newPath = [[currentPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"ttxt"];
			[self convertSRT:currentPath toTTXT:newPath];
					
			result = [self addSubtitleToMP4Movie:newPath outPath:path forLanguage:language firstSubtitle:firstSubtitle];
							
			if (result == YES)
			{
				firstSubtitle = NO;
				continue;
			}
		}
		else*/
			
		if (![type isEqualTo:@"mp4"])
		{
			[subtitlePaths addObject:currentPath];
			[languages addObject:language];
		}
			
		if ([type isEqualTo:@"mp4"])
			[self addSubtitleToMP4Movie:currentPath outPath:path forLanguage:language firstSubtitle:firstSubtitle];
					
		firstSubtitle = NO;
	}
	
	if ([subtitlePaths count] > 0)
	{
		if ([type isEqualTo:@"mkv"])
		{
			[self addSubtitlesToMKVMovie:subtitlePaths outPath:path forLanguages:languages];
		}
		else if ([type isEqualTo:@"kate"])
		{
			[self addSubtitlesToOGGMovie:subtitlePaths outPath:path forLanguages:languages];
		}
		else if ([type isEqualTo:@"hard"])
		{
			NSString *defaultLanguage = [[NSUserDefaults standardUserDefaults] objectForKey:@"MCSubtitleLanguage"];
		
			NSString *subtitlePath = [[[temporaryFolder stringByAppendingPathComponent:[inFile lastPathComponent]] stringByDeletingPathExtension] stringByAppendingPathExtension:@"srt"];

			if (![[MCCommonMethods defaultManager] fileExistsAtPath:subtitlePath])
				subtitlePath = [[[[temporaryFolder stringByAppendingPathComponent:[inFile lastPathComponent]] stringByDeletingPathExtension] stringByAppendingPathExtension:defaultLanguage] stringByAppendingPathExtension:@"srt"];
			
			// Just use the first subtitle file
			if (![[MCCommonMethods defaultManager] fileExistsAtPath:subtitlePath])
				subtitlePath = [subtitlePaths objectAtIndex:0];

			[self createSubtitleMovieAtPath:path withOptions:options subtitleFile:subtitlePath withSize:size];
		}
	}
	else if ([type isEqualTo:@"mp4"])
	{
		return [[NSFileManager defaultManager] fileExistsAtPath:path];
	}
	else if (![type isEqualTo:@"dvd"])
	{
		return NO;
	}
	
	if ([type isEqualTo:@"dvd"])
	{
		[self addDVDSubtitlesToOutputStreamFromTask:ffmpeg withSubtitles:subtitlePaths toPath:path];
	}
	
	return YES;
}

- (BOOL)extractSubtitlesFromMovieAtPath:(NSString *)inPath toPath:(NSString *)outPath shouldRename:(BOOL)rename
{
	BOOL result = YES;
	NSArray *supportedFileTypes = [NSArray arrayWithObjects:@"srt", @"ttxt", @"kate", nil];
	NSString *inputFolder = [inPath stringByDeletingLastPathComponent];
	NSString *fileName = [[inPath lastPathComponent] stringByDeletingPathExtension];
	
	NSArray *beforeFolderContents = [MCCommonMethods getFullPathsForFolders:[NSArray arrayWithObject:inputFolder] withType:nil];

	//Extract subtitles from input mp4 / mkv / ogg, when possible
	NSString *inputExtension = [[inPath pathExtension] lowercaseString];
	if ([inputExtension isEqualTo:@"mp4"] | [inputExtension isEqualTo:@"3gp"] | [inputExtension isEqualTo:@"mov"] | [inputExtension isEqualTo:@"m4v"])
		[self extractSubtitlesFromMP4Movie:inPath ofType:@"srt" toPath:outPath];
	else if ([inputExtension isEqualTo:@"mkv"])
		[self extractSubtitlesFromMKVMovie:inPath ofType:@"srt" toPath:outPath];
	else if ([inputExtension isEqualTo:@"ogg"] | [inputExtension isEqualTo:@"ogv"])
		[self extractSubtitlesFromOGGMovie:inPath ofType:@"srt" toPath:outPath];
	
	NSArray *folderContents = [MCCommonMethods getFullPathsForFolders:[NSArray arrayWithObject:inputFolder] withType:nil];
	NSMutableArray *subtitlePaths = [NSMutableArray array];
	NSMutableArray *languages = [NSMutableArray array];
	NSArray *languageCodes = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"LanguageCodes" ofType:@"plist"]];

	NSInteger i;
	for (i = 0; i < [folderContents count]; i ++)
	{
		NSString *currentPath = [folderContents objectAtIndex:i];
		NSString *extensionlessPath = [currentPath stringByDeletingPathExtension];
		
		if ([languageCodes containsObject:[extensionlessPath pathExtension]])
			extensionlessPath = [extensionlessPath stringByDeletingPathExtension];
		
		extensionlessPath = [extensionlessPath lastPathComponent];
		result = YES;

		if ([extensionlessPath isEqualTo:fileName])
		{
			NSString *fileExtension = [[currentPath pathExtension] lowercaseString];
			
			if ([supportedFileTypes containsObject:fileExtension])
			{
				NSString *newPath = currentPath;
				NSString *language = [[currentPath stringByDeletingPathExtension] pathExtension];
				language = [[language componentsSeparatedByString:@"-"] objectAtIndex:0];
				
				if (![language isEqualTo:@"zh_TW"] | ![language isEqualTo:@"zh_CN"])
					language = [[language componentsSeparatedByString:@"_"] objectAtIndex:0];

				if ([fileExtension isEqualTo:@"srt"])
				{
					//Don't copy a srt file when using the same input folder as the output folder
					if ([beforeFolderContents containsObject:currentPath])
					{
						NSString *originalString = [MCCommonMethods stringWithContentsOfFile:currentPath encoding:NSUTF8StringEncoding error:nil];
						
						NSDictionary *languageDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Languages" ofType:@"plist"]];
						if ([[languageDict allKeysForObject:language] count] == 0)
						{
							if ([[oldToNewLanguageCodes allKeys] containsObject:language])
								language = [oldToNewLanguageCodes objectForKey:language];
						}

						if (!originalString)
						{
							NSStringEncoding encoding = 0x0000000C;
							
							if ([cyrillicLanguages containsObject:language])
								encoding = 0x0000000B;
							else if ([language isEqualTo:@"zh"] | [language isEqualTo:@"zht"])
								encoding = 0x80000632;
							else if ([language isEqualTo:@"cn"] | [language isEqualTo:@"zhs"])
								encoding = 0x80000421;
							else if ([language isEqualTo:@"ara"] | [language isEqualTo:@"ar"] | [language isEqualTo:@"som"] | [language isEqualTo:@"so"] | [language isEqualTo:@"kur"] | [language isEqualTo:@"ku"])
								encoding = 0x80000506;
							else if ([language isEqualTo:@"ell"] | [language isEqualTo:@"el"])
								encoding = 0x0000000D;
							else if ([language isEqualTo:@"heb"] | [language isEqualTo:@"he"] | [language isEqualTo:@"yid"] | [language isEqualTo:@"yi"])
								encoding = 0x80000505;
							else if ([language isEqualTo:@"jpn"] | [language isEqualTo:@"ja"])
								encoding = 0x00000003;
							else if ([language isEqualTo:@"tur"] | [language isEqualTo:@"tr"])
								encoding = 0x0000000E;
							else if ([language isEqualTo:@"tha"] | [language isEqualTo:@"th"])
								encoding = 0x8000041D;
							else if ([language isEqualTo:@"kor"] | [language isEqualTo:@"ko"])
								encoding = 0x80000422;
							else if ([language isEqualTo:@"vie"] | [language isEqualTo:@"vi"])
								encoding = 0x80000508;
							
							originalString = [MCCommonMethods stringWithContentsOfFile:currentPath encoding:encoding error:nil];
						}
						
						if (!originalString)
							originalString = [MCCommonMethods stringWithContentsOfFile:currentPath encoding:NSUnicodeStringEncoding error:nil];
						
						if ([language isEqualTo:@""])
							language = [[NSUserDefaults standardUserDefaults] objectForKey:@"MCSubtitleLanguage"];
						
						if (rename == YES)
						{
							if ([language isEqualTo:@"zht"] | [language isEqualTo:@"zhs"])
								language = @"zh";
						}
						
						NSString *tmpUTFFileName = [MCCommonMethods uniquePathNameFromPath:[[outPath stringByAppendingPathExtension:language] stringByAppendingPathExtension:@"srt"] withSeperator:@"_"];
				
						NSString *outString = nil;
						[MCCommonMethods writeString:originalString toFile:tmpUTFFileName errorString:&outString];
						newPath = tmpUTFFileName;
					}
			
					[subtitlePaths addObject:newPath];
					[languages addObject:language];
				}
				else if ([fileExtension isEqualTo:@"ttxt"])
				{
					NSString *language = [[currentPath stringByDeletingPathExtension] pathExtension];
					NSString *newFileName = [MCCommonMethods uniquePathNameFromPath:[[outPath stringByAppendingPathExtension:language] stringByAppendingPathExtension:@"srt"] withSeperator:@"_"];
					[self convertSubtitleFromMP4Movie:currentPath toSubtitle:newFileName outType:@"srt" fromID:nil];
				}
				else if ([fileExtension isEqualTo:@"kate"])
				{
					[self extractSubtitlesFromOGGMovie:currentPath ofType:@"srt" toPath:outPath];
				}
			}
		}
	}
	
	return result;
}

- (NSArray *)trackDictionariesFromPath:(NSString *)path withType:(NSString *)type
{	
	if ([type isEqualTo:@"mp4"])
		return [self trackDictionariesFromMP4MovieAtPath:path];
	else if ([type isEqualTo:@"mkv"])
		return [self trackDictionariesFromMKVMovieAtPath:path];
	else if ([type isEqualTo:@"ogg"])
		return [self trackDictionariesFromOGGMovieAtPath:path];
		
	return nil;
}

//Hardcoded Subtitle methods

#pragma mark -
#pragma mark ••• Hardcoded Subtitle methods

- (void)createSubtitleMovieAtPath:(NSString *)path withOptions:(NSArray *)options subtitleFile:(NSString *)file withSize:(NSSize)size
{
	CGFloat fps;
	//NSString *fpsString = [options objectForKey:@"-r"];
	//if (fpsString != nil)
		//fps = [fpsString cgfloatValue];
	//else
		fps = inputFps;

	NSString *srtFile = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];

	NSInteger i = 1;
	//Calculate time to fill the empty spaces between subtitles
	NSInteger currentTime = 0;

	CGFloat secondPerFrame = 1.00 / fps;

	//Replace returns with html return
	//Windows return 0d 0a
	srtFile = [srtFile stringByReplacingOccurrencesOfString:@"\r\n" withString:@"<br>"];
	//Unix-like (including Mac OS X) return 0a
	srtFile = [srtFile stringByReplacingOccurrencesOfString:@"\n" withString:@"<br>"];
	//Old Mac (Mac OS 9 and earlier) return 0d -- just in case ;-)
	srtFile = [srtFile stringByReplacingOccurrencesOfString:@"\r" withString:@"<br>"];
	
	//A srt file should start with a new line or carriage return + new line, but doesn't always so fix it then
	if (![[srtFile substringWithRange:NSMakeRange(0, 4)] isEqualTo:@"<br>"])
		srtFile = [NSString stringWithFormat:@"<br>%@", srtFile];
	
	//Create a empty image used between subtitles (do some bogus drawing so it can be saved or served to pipe
	NSImage *emptyImage = [[NSImage alloc] initWithSize:size];
	[emptyImage lockFocus];
	NSBezierPath *emptyPath = [NSBezierPath bezierPathWithRect:NSMakeRect(0, 0, 0, 0)];
	[emptyPath fill]; 
	[emptyImage unlockFocus];
		
	NSData *tiffData = [emptyImage TIFFRepresentation];
	NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:tiffData];
	NSData *emptyImageData = [bitmap representationUsingType:NSPNGFileType properties:nil];
	
	NSString *emptyImagePath = [temporaryFolder stringByAppendingPathComponent:@"empty.png"];
	[emptyImageData writeToFile:emptyImagePath atomically:YES];
	
	[emptyImage release];
	
	//Create a filehandle to write all movie data to
	[[NSFileManager defaultManager] createFileAtPath:path contents:[NSData data] attributes:nil];
	NSFileHandle *outHandle = [NSFileHandle fileHandleForUpdatingAtPath:path];
	
	BOOL timeLimit = ([options objectForKey:@"-t"] != nil);
	
	while ([srtFile rangeOfString:[NSString stringWithFormat:@"<br>%i<br>", i]].length > 0)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		if (userCanceled)
		{
			[pool release];
			break;
		}
		
		NSArray *components = [srtFile componentsSeparatedByString:[NSString stringWithFormat:@"<br>%i<br>", i]];
		
		NSInteger startIndex = 0;
		if ([components count] > 1)
			startIndex = 1;
		
		if ([srtFile rangeOfString:[NSString stringWithFormat:@"<br>%i<br>", i + 1]].length > 0)
		{
			components = [[components objectAtIndex:startIndex] componentsSeparatedByString:[NSString stringWithFormat:@"<br>%i<br>", i + 1]];
			startIndex = 0;
		}
		else
		{
			startIndex = 1;
		}	
		
		NSString *subSentence = [components objectAtIndex:startIndex];
		NSArray *sentences = [subSentence componentsSeparatedByString:@"<br>"];
		NSString *timeString = [sentences objectAtIndex:0];
		NSArray *times = [timeString componentsSeparatedByString:@" --> "];
		
		if (timeLimit && ([self secondsFromFormatedString:[times objectAtIndex:0]] > [[options objectForKey:@"-t"] cgfloatValue]))
			break;
			
		NSInteger totalTime = (NSInteger)inputTotalTime;
		CGFloat progressTime = [self secondsFromFormatedString:[times objectAtIndex:0]];
		
		if (timeLimit)
			totalTime = [[options objectForKey:@"-t"] integerValue];
			
		NSString *percentString = [NSString stringWithFormat:@" (%.0f%@)", progressTime / (totalTime / 100), @"%"];

		[[NSNotificationCenter defaultCenter] postNotificationName:@"MCStatusByAddingPercentChanged" object:percentString];
		
		CGFloat subStart = [self secondsFromFormatedString:[times objectAtIndex:0]] / secondPerFrame;
		CGFloat subEnd = [self secondsFromFormatedString:[times objectAtIndex:1]] / secondPerFrame;
		NSInteger subDuration = subEnd - subStart;
		NSInteger emptyDuration = subStart - currentTime;
		
		ffmpeg = [[NSTask alloc] init];
		[ffmpeg setLaunchPath:[MCCommonMethods ffmpegPath]];
		[ffmpeg setArguments:[NSArray arrayWithObjects:@"-loop", @"1", @"-f", @"image2", @"-r", [NSString stringWithFormat:@"%0.2f", fps], @"-i", emptyImagePath, @"-vframes", [NSString stringWithFormat:@"%i", emptyDuration], @"-vcodec", @"copy", @"-f", @"avi", @"-", nil]];
		[ffmpeg setStandardError:[NSFileHandle fileHandleWithNullDevice]];
		[ffmpeg setStandardOutput:outHandle];
		[ffmpeg launch];
		
		currentTime = currentTime + emptyDuration;
		
		[ffmpeg waitUntilExit];
		[ffmpeg release];
		ffmpeg = nil;
		
		[outHandle seekToEndOfFile];
		
		NSString *string = [[subSentence componentsSeparatedByString:[NSString stringWithFormat:@"%@<br>", timeString]] objectAtIndex:1];

		while ([string length] > 4 && [[string substringWithRange:NSMakeRange([string length] - 4, 4)] isEqualTo:@"<br>"])
			string = [string substringWithRange:NSMakeRange(0, [string length] - 4)];
		
		NSImage *subImage = [[NSImage alloc] initWithSize:size];
		
		NSMutableDictionary *defaultSettings = [NSMutableDictionary dictionaryWithDictionary:[[MCPresetManager defaultManager] defaults]];
		[defaultSettings addEntriesFromDictionary:[convertOptions objectForKey:@"Extra Options"]];
		
		NSImage *image = [MCCommonMethods overlayImageWithObject:string withSettings:defaultSettings inputImage:subImage];
		
		[subImage release];
		subImage = nil;
		
		tiffData = [image TIFFRepresentation];
		bitmap = [NSBitmapImageRep imageRepWithData:tiffData];
		NSData *imageData = [bitmap representationUsingType:NSPNGFileType properties:nil];
		
		NSString *imagePath = [temporaryFolder stringByAppendingPathComponent:@"not-empty.png"];
		[imageData writeToFile:imagePath atomically:YES];

		ffmpeg = [[NSTask alloc] init];
		[ffmpeg setLaunchPath:[MCCommonMethods ffmpegPath]];
		[ffmpeg setArguments:[NSArray arrayWithObjects:@"-loop", @"1", @"-f", @"image2", @"-r", [NSString stringWithFormat:@"%0.2f", fps], @"-i", imagePath, @"-vframes", [NSString stringWithFormat:@"%i", subDuration], @"-vcodec", @"copy", @"-f", @"avi", @"-", nil]];
		[ffmpeg setStandardError:[NSFileHandle fileHandleWithNullDevice]];
		[ffmpeg setStandardOutput:outHandle];
		[ffmpeg launch];
		
		currentTime = currentTime + subDuration;
		
		[ffmpeg waitUntilExit];
		[ffmpeg release];
		ffmpeg = nil;
		
		[outHandle seekToEndOfFile];
		
		i = i + 1;
		
		[pool release];
	}
	
	if (!userCanceled)
	{
		//Make a last empty image
		ffmpeg = [[NSTask alloc] init];
		[ffmpeg setLaunchPath:[MCCommonMethods ffmpegPath]];
		[ffmpeg setArguments:[NSArray arrayWithObjects:@"-loop", @"1", @"-f", @"image2", @"-r", [NSString stringWithFormat:@"%0.2f", fps], @"-i", emptyImagePath, @"-vframes", @"1", @"-vcodec", @"copy", @"-f", @"avi", @"-", nil]];
		[ffmpeg setStandardError:[NSFileHandle fileHandleWithNullDevice]];
		[ffmpeg setStandardOutput:outHandle];
		[ffmpeg launch];
		[ffmpeg waitUntilExit];
		[ffmpeg release];
		ffmpeg = nil;
	}
}

- (CGFloat)secondsFromFormatedString:(NSString *)string
{
	NSArray *parts = [string componentsSeparatedByString:@":"];
	CGFloat hourSeconds = [[parts objectAtIndex:0] floatValue] * 60 * 60;
	CGFloat minuteSeconds = [[parts objectAtIndex:1] floatValue] * 60;
	CGFloat seconds = [[parts objectAtIndex:2] floatValue];
	CGFloat miliseconds = [[[[parts objectAtIndex:2] componentsSeparatedByString:@","] objectAtIndex:1] floatValue];
	
	return hourSeconds + minuteSeconds + seconds + (miliseconds / 1000);
}

//MP4 Subtitle methods

#pragma mark -
#pragma mark ••• MP4 Subtitle methods

- (BOOL)addSubtitleToMP4Movie:(NSString *)subPath outPath:(NSString *)moviePath forLanguage:(NSString *)lang firstSubtitle:(BOOL)first
{	
	NSString *disableText = @"";
	if (!first)
		disableText = @":disable";

	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"MP4Box" ofType:@""];
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-add", [NSString stringWithFormat:@"%@:lang=%@%@:group=2", subPath, lang, disableText], nil];

	if (first == YES)
		[arguments addObjectsFromArray:[NSArray arrayWithObjects:@"-new", moviePath, nil]];
	else
		[arguments addObject:moviePath];
	
	return [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil inputPipe:nil predefinedTask:nil];
}

- (BOOL)convertSubtitleFromMP4Movie:(NSString *)inPath toSubtitle:(NSString *)outPath outType:(NSString *)type fromID:(NSString *)streamID
{
	[[MCCommonMethods defaultManager] createFileAtPath:outPath contents:[NSData data] attributes:nil];
	
	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"MP4Box" ofType:@""];
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"-%@", type]];
	
	if (streamID != nil)
		[arguments addObject:streamID];
		
	[arguments addObjectsFromArray:[NSArray arrayWithObjects:inPath, @"-std", @"-quiet", @"-noprog", nil]];
	
	NSString *output;
	BOOL result = [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:YES output:&output inputPipe:nil predefinedTask:nil];
	
	if (result == YES)
	{
		//Bit ugly clean up
		NSString *subtitleString = nil;
		NSArray *components = [output componentsSeparatedByString:@"\n"];
		
		NSInteger i;
		for (i = 0; i < [components count] - 2; i ++)
		{
			NSString *currentSentence = [components objectAtIndex:i];
			
			if ([currentSentence rangeOfString:@"WARNING: "].length == 0 | [currentSentence rangeOfString:@"SRT"].length == 0)
			{
				if (!subtitleString)
					subtitleString = currentSentence;
				else
					subtitleString = [NSString stringWithFormat:@"%@\n%@", subtitleString, currentSentence];
			}
		}
		
		NSString *outString = nil;
		
		[MCCommonMethods writeString:subtitleString toFile:outPath errorString:&outString];
	}
	
	return result;
}

//Not working right now
/*- (BOOL)convertSRT:(NSString *)inPath toTTXT:(NSString *)outPath
{
	BOOL result = [self convertSubtitleFromMP4Movie:inPath toSubtitle:outPath outType:@"ttxt" fromID:nil];
	convertOptions = [NSDictionary dictionaryWithContentsOfFile:@"/Library/Application Support/Media Converter/Presets/DVD-Video (PAL).mcpreset"];
	if (result == YES)
	{
		NSDictionary *extraOptions = [convertOptions objectForKey:@"Extra Options"];
		
		NSError *error = nil;
		NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:outPath] options:NSXMLNodePreserveAll error:&error];
		result = (error == nil);
		
		if (result)
		{
			NSArray *nodes = [doc nodesForXPath:@"./TextStream/TextStreamHeader/TextSampleDescription" error:&error];
			result = (error == nil);
			
			if (result)
			{
				NSXMLElement *currentNode = [nodes objectAtIndex:0];
				
				NSNumber *horizontalAlignment = [extraOptions objectForKey:@"Subtitle Horizontal Alignment"];
				
				if (horizontalAlignment)
					[[currentNode attributeForName:@"horizontalJustification"] setObjectValue:horizontalAlignment];
					
				NSNumber *verticalAlignment = [extraOptions objectForKey:@"Subtitle Vertical Alignment"];
				
				if (verticalAlignment)
					[[currentNode attributeForName:@"verticalJustification"] setObjectValue:verticalAlignment];
					
				NSArray *boxNodes = [currentNode nodesForXPath:@"./TextBox" error:&error];
				result = (error == nil);
				
				if (result)
				{
					NSXMLElement *boxElement = [boxNodes objectAtIndex:0];
				
					NSNumber *boxTop = [extraOptions objectForKey:@"Subtitle Top Margin"];
				
					if (boxTop)
						[[boxElement attributeForName:@"top"] setObjectValue:boxTop];
				
					NSNumber *boxLeft = [extraOptions objectForKey:@"Subtitle Left Margin"];
				
					if (boxLeft)
						[[boxElement attributeForName:@"left"] setObjectValue:boxLeft];
					
					NSNumber *boxBottom = [extraOptions objectForKey:@"Subtitle Bottom Margin"];
				
					if (boxBottom)
						[[boxElement attributeForName:@"bottom"] setObjectValue:boxBottom];
					
					NSNumber *boxRight = [extraOptions objectForKey:@"Subtitle Right Margin"];
				
					if (boxRight)
						[[boxElement attributeForName:@"right"] setObjectValue:boxRight];
				}
			}
			
			NSString *outString = nil;
			result = [MCCommonMethods writeString:[doc XMLString] toFile:outPath errorString:&outString];
		}
	}
	
	return result;
}*/

- (BOOL)extractSubtitlesFromMP4Movie:(NSString *)inPath ofType:(NSString *)type toPath:(NSString *)outPath
{
	BOOL result = YES;
	NSArray *trackDictionaries = [self trackDictionariesFromMP4MovieAtPath:inPath];

	NSInteger i;
	for (i = 0; i < [trackDictionaries count]; i ++)
	{
		NSDictionary *currentTrackDictionary = [trackDictionaries objectAtIndex:i];
		NSString *language = [currentTrackDictionary objectForKey:@"Language Code"];
		NSString *idString = [currentTrackDictionary objectForKey:@"Track ID"];
			
		NSString *saveFilePath;
		if (language)
			saveFilePath = [MCCommonMethods uniquePathNameFromPath:[NSString stringWithFormat:@"%@.%@.%@", outPath, language, type] withSeperator:@"_"];
		else
			saveFilePath = [MCCommonMethods uniquePathNameFromPath:[NSString stringWithFormat:@"%@.%@", outPath, type] withSeperator:@"."];

		result = [self convertSubtitleFromMP4Movie:inPath toSubtitle:saveFilePath outType:type fromID:idString];
	}
	
	return result;
}

- (BOOL)addTracksFromMP4Movie:(NSString *)inPath toPath:(NSString *)outPath
{
	int firstSubTrack = 3;
	
	NSDictionary *streamDictionary = [self firstAudioAndVideoStreamAtPath:inPath];
	if ([streamDictionary objectForKey:@"Audio"] != nil)
		firstSubTrack = 2;

	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"MP4Box" ofType:@""];
	NSArray *arguments = [NSArray arrayWithObjects:@"-add", inPath, outPath, @"-enable", [NSString stringWithFormat:@"%i", firstSubTrack], nil];
	return [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil inputPipe:nil predefinedTask:nil];
}

- (NSArray *)trackDictionariesFromMP4MovieAtPath:(NSString *)path
{
	NSMutableArray *trackNumbers = [NSMutableArray array];
	
	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"MP4Box" ofType:@""];
	NSArray *arguments = [NSArray arrayWithObjects:@"-info", path, nil];
	
	NSString *output;
	BOOL result = [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:YES output:&output inputPipe:nil predefinedTask:nil];
	
	if (result == YES)
	{
		NSArray *tracks = [output componentsSeparatedByString:@"\n\n"];
		
		NSInteger i;
		for (i = 0; i < [tracks count]; i ++)
		{
			NSString *component = [tracks objectAtIndex:i];
			
			if ([component rangeOfString:@"TrackID"].length > 0)
			{
				if ([component rangeOfString:@"sbtl:"].length > 0 | [component rangeOfString:@"text:"].length > 0)
				{
					NSString *trackID = [[[[component componentsSeparatedByString:@"TrackID "] objectAtIndex:1] componentsSeparatedByString:@" -"] objectAtIndex:0];
					NSString *language = [[[[component componentsSeparatedByString:@"Language \""] objectAtIndex:1] componentsSeparatedByString:@"\""] objectAtIndex:0];
					NSString *languageDictPath = [[NSBundle mainBundle] pathForResource:@"Languages" ofType:@"plist"];
					NSDictionary *languageDict = [NSDictionary dictionaryWithContentsOfFile:languageDictPath];
					NSString *languageCode = [languageDict objectForKey:language];
					
					[trackNumbers addObject:[NSDictionary dictionaryWithObjectsAndKeys:trackID, @"Track ID", languageCode, @"Language Code", nil]];
				}
			}
		}
	}
	
	return trackNumbers;
}

//MKV Subtitle methods

#pragma mark -
#pragma mark ••• MKV Subtitle methods

- (BOOL)addSubtitlesToMKVMovie:(NSArray *)subtitles outPath:(NSString *)moviePath forLanguages:(NSArray *)languages
{	
	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"mkvmerge" ofType:@""];
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-o", moviePath, nil];

	NSInteger i;
	for (i = 0; i < [subtitles count]; i ++)
	{
		NSString *path = [subtitles objectAtIndex:i];
		NSString *lang = [languages objectAtIndex:i];
		
		[arguments addObject:@"--language"];
		[arguments addObject:[NSString stringWithFormat:@"0:%@", lang]];
		[arguments addObject:path];
	}

	return [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil inputPipe:nil predefinedTask:nil];
}

- (BOOL)extractSubtitlesFromMKVMovie:(NSString *)inPath ofType:(NSString *)type toPath:(NSString *)outPath
{
	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"mkvextract" ofType:@""];
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"tracks", inPath, nil];
	NSMutableArray *languages = [NSMutableArray array];
	
	NSArray *trackDictionaries = [self trackDictionariesFromMKVMovieAtPath:inPath];
		
	NSInteger i;
	for (i = 0; i < [trackDictionaries count]; i ++)
	{
		NSDictionary *currentTrackDictionary = [trackDictionaries objectAtIndex:i];
		NSString *language = [currentTrackDictionary objectForKey:@"Language Code"];
		NSString *idString = [currentTrackDictionary objectForKey:@"Track ID"];
		
		NSDictionary *languageConversions = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"LanguageConversion" ofType:@"plist"]];
		if ([[languageConversions allKeys] containsObject:language])
			language = [languageConversions objectForKey:language];
		
		NSInteger extNumber = 1;
		while ([languages containsObject:language])
		{
			language = [NSString stringWithFormat:@"%@_%i", language, extNumber];
			extNumber = extNumber + 1;
		}
		
		NSString *argument = [NSString stringWithFormat:@"%@:%@.%@.srt", idString, outPath, language];
			
		[arguments addObject:argument];
		
		[languages addObject:language];
	}
	
	return [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil inputPipe:nil predefinedTask:nil];
}

- (BOOL)addTracksFromMKVMovie:(NSArray *)inPaths toPath:(NSString *)outPath
{
	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"mkvmerge" ofType:@""];
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-o", outPath, nil];
	[arguments addObjectsFromArray:inPaths];

	return [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil inputPipe:nil predefinedTask:nil];
}

- (NSArray *)trackDictionariesFromMKVMovieAtPath:(NSString *)path
{	
	NSMutableArray *trackNumbers = [NSMutableArray array];
	
	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"mkvinfo" ofType:@""];
	NSArray *arguments = [NSArray arrayWithObject:path];
	
	NSString *output;
	BOOL result = [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:YES output:&output inputPipe:nil predefinedTask:nil];
	
	if (result == YES)
	{
		NSArray *tracks = [output componentsSeparatedByString:@"| + A track"];
		
		NSInteger i;
		for (i = 0; i < [tracks count]; i ++)
		{
			NSString *track = [tracks objectAtIndex:i];

			if ([track rangeOfString:@"S_TEXT/UTF8"].length > 0)
			{
				NSString *trackID = [[[[track componentsSeparatedByString:@"Track number: "] objectAtIndex:1] componentsSeparatedByString:@"\n"] objectAtIndex:0];
				NSString *language = @"eng";
				
				if ([track rangeOfString:@"Language: "].length > 0)
					language = [[[[track componentsSeparatedByString:@"Language: "] objectAtIndex:1] componentsSeparatedByString:@"\n"] objectAtIndex:0];
					
				if ([[oldToNewLanguageCodes allKeys] containsObject:language])
					language = [oldToNewLanguageCodes objectForKey:language];
					
				[trackNumbers addObject:[NSDictionary dictionaryWithObjectsAndKeys:trackID, @"Track ID", language, @"Language Code", nil]];
			}
		}
	}
	
	return trackNumbers;
}

//OGG (Kate) Subtitle methods

#pragma mark -
#pragma mark ••• OGG (Kate) Subtitle methods

- (BOOL)addSubtitlesToOGGMovie:(NSArray *)subtitles outPath:(NSString *)moviePath forLanguages:(NSArray *)languages
{	
	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"oggz-merge" ofType:@""];
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-o", moviePath, nil];
	NSMutableArray *newPaths = [NSMutableArray array];

	NSInteger i;
	for (i = 0; i < [subtitles count]; i ++)
	{
		NSString *path = [subtitles objectAtIndex:i];
		NSString *lang = [languages objectAtIndex:i];
		NSString *newPath = [[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"ogg"];
		[newPaths addObject:newPath];
		
		[self convertSRT:path toKateOGG:newPath forLanguage:lang];
		
		[arguments addObject:newPath];
	}

	return [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil inputPipe:nil predefinedTask:nil];
}

- (BOOL)addTracksFromOGGMovies:(NSArray *)inPaths toPath:(NSString *)outPath
{
	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"oggz-merge" ofType:@""];
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-o", outPath, nil];
	[arguments addObjectsFromArray:inPaths];
	
	return [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil inputPipe:nil predefinedTask:nil];
}

- (BOOL)convertSRT:(NSString *)inPath toKateOGG:(NSString *)outPath forLanguage:(NSString *)language
{
	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"kateenc" ofType:@""];
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-c", @"SUB", @"-t",  @"srt", @"-l", language, @"-o", outPath, inPath, nil];
	
	return [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil inputPipe:nil predefinedTask:nil];
}

- (BOOL)extractSubtitlesFromOGGMovie:(NSString *)inPath ofType:(NSString *)type toPath:(NSString *)outPath
{
	NSArray *trackDictionaries = [self trackDictionariesFromOGGMovieAtPath:inPath];
	NSMutableArray *languages = [NSMutableArray array];

	NSInteger i;
	for (i = 0; i < [trackDictionaries count]; i ++)
	{
		NSString *helperPath;
		NSArray *arguments;
		NSString *tmpOggFile;
		
		NSDictionary *currentTrackDictionary = [trackDictionaries objectAtIndex:i];
		NSString *language = [currentTrackDictionary objectForKey:@"Language Code"];
		NSString *idString = [currentTrackDictionary objectForKey:@"Track ID"];
		
		NSInteger extNumber = 1;
		while ([languages containsObject:language])
		{
			language = [NSString stringWithFormat:@"%@_%i", language, extNumber];
			extNumber = extNumber + 1;
		}
		
		[languages addObject:language];
	
		if ([trackDictionaries count] > 1)
		{
			helperPath = [[NSBundle mainBundle] pathForResource:@"oggz-rip" ofType:@""];
		
			tmpOggFile = [NSString stringWithFormat:@"%@.ogg", outPath];
			arguments = [NSArray arrayWithObjects:@"-s", idString, @"-o", tmpOggFile, inPath, nil];
			
			[MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil inputPipe:nil predefinedTask:nil];
		}
		else
		{
			tmpOggFile = inPath;
		}
		
		helperPath = [[NSBundle mainBundle] pathForResource:@"katedec" ofType:@""];
		
		NSString *outputFile = [NSString stringWithFormat:@"%@.%@.srt", outPath, language];
		outputFile = [MCCommonMethods uniquePathNameFromPath:outputFile withSeperator:@"_"];
		
		arguments = [NSArray arrayWithObjects:@"-t", @"srt", @"-o", outputFile, tmpOggFile, nil];

		[MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil inputPipe:nil predefinedTask:nil];
	}
	
	return YES;
}

- (NSArray *)trackDictionariesFromOGGMovieAtPath:(NSString *)path
{	
	NSMutableArray *trackNumbers = [NSMutableArray array];
	
	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"oggz-info" ofType:@""];
	NSArray *arguments = [NSArray arrayWithObject:path];
	
	NSString *output;
	BOOL result = [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:YES output:&output inputPipe:nil predefinedTask:nil];

	if (result == YES)
	{
		NSArray *tracks = [output componentsSeparatedByString:@"Kate: "];
		
		NSInteger i;
		for (i = 1; i < [tracks count]; i ++)
		{
			NSString *track = [tracks objectAtIndex:i];

			NSString *trackID = [[[[track componentsSeparatedByString:@"serialno "] objectAtIndex:1] componentsSeparatedByString:@"\n"] objectAtIndex:0];
			NSString *language = [[[[track componentsSeparatedByString:@"Content-Language: "] objectAtIndex:1] componentsSeparatedByString:@"\n"] objectAtIndex:0];
			
			if ([language isEqualTo:@""])
				language = @"en";
					
			[trackNumbers addObject:[NSDictionary dictionaryWithObjectsAndKeys:trackID, @"Track ID", language, @"Language Code", nil]];
		}
	}
	
	return trackNumbers;
}

//DVD Subtitle methods

#pragma mark -
#pragma mark ••• DVD Subtitle methods

- (BOOL)addDVDSubtitlesToOutputStreamFromTask:(NSTask *)task withSubtitles:(NSArray *)subtitles toPath:(NSString *)outPath
{	
	NSFileManager *defaultManager = [MCCommonMethods defaultManager];
	[defaultManager createFileAtPath:outPath contents:[NSData data] attributes:nil];

	if ([subtitles count] == 0)
	{
		[NSThread detachNewThreadSelector:@selector(writeDataOnThread:) toTarget:self withObject:outPath];
		
		return YES;
	}
	
	NSInteger i;
	NSTask *currentTask = task;
	for (i = 0; i < [subtitles count]; i ++)
	{
		NSDictionary *extraOptions = [convertOptions objectForKey:@"Extra Options"];
		NSDictionary *encoderOptions = [convertOptions objectForKey:@"Encoder Options"];

		NSString *subPath = [subtitles objectAtIndex:i];
		NSString *fontSize = [extraOptions objectForKey:@"Subtitle Font Size"];

		NSString *fontPath = [[NSUserDefaults standardUserDefaults] objectForKey:@"MCFontFolderPath"];
		NSString *language = [[subPath stringByDeletingPathExtension] pathExtension];
		language = [[language componentsSeparatedByString:@"_"] objectAtIndex:0];
		
		//Note Kudish doesn't seem to work, don't know why :-(
		NSString *font = nil;
		if ([cyrillicLanguages containsObject:language] | [language isEqualTo:@"ell"] | [language isEqualTo:@"el"])
			font = @"Helvetica";
		else if ([language isEqualTo:@"cn"] | [language isEqualTo:@"zhs"])
			font = @"Hei";
		else if ([language isEqualTo:@"ara"] | [language isEqualTo:@"ar"] | [language isEqualTo:@"som"] | [language isEqualTo:@"so"] | [language isEqualTo:@"kur"] | [language isEqualTo:@"ku"])
			font = @"AlBayan";
		else if ([language isEqualTo:@"heb"] | [language isEqualTo:@"he"] | [language isEqualTo:@"yid"] | [language isEqualTo:@"yi"])
			font = @"Raanana";
		else if ([language isEqualTo:@"jpn"] | [language isEqualTo:@"ja"])
			font = @"Osaka";
		else if ([language isEqualTo:@"tha"] | [language isEqualTo:@"th"])
			font = @"Ayuthaya";
		else if ([language isEqualTo:@"kor"] | [language isEqualTo:@"ko"])
			font = @"AppleGothic";
		else if ([language isEqualTo:@"zh"] | [language isEqualTo:@"zht"])
			font = @"儷黑 Pro";
		else if ([language isEqualTo:@"hye"] | [language isEqualTo:@"hy"])
			font = @"MshtakanRegular";

		if (font == nil | ![defaultManager fileExistsAtPath:[fontPath stringByAppendingPathComponent:[font stringByAppendingPathExtension:@"ttf"]]])
			font = [extraOptions objectForKey:@"Subtitle Font"];

		NSString *hAlign = [extraOptions objectForKey:@"Subtitle Horizontal Alignment"];
		NSString *vAlign = [extraOptions objectForKey:@"Subtitle Vertical Alignment"];
		NSString *lMargin = [extraOptions objectForKey:@"Subtitle Left Margin"];
		NSString *rMargin = [extraOptions objectForKey:@"Subtitle Right Margin"];
		NSString *tMargin = [extraOptions objectForKey:@"Subtitle Top Margin"];
		NSString *bMargin = [extraOptions objectForKey:@"Subtitle Bottom Margin"];
		
		NSString *fps = [NSString stringWithFormat:@"%f", inputFps];
		NSString *fpsString = [encoderOptions objectForKey:@"-r"];
		if (fpsString)
			fps = fpsString;
		
		NSString *movieWidth = [NSString stringWithFormat:@"%i", inputWidth];
		NSString *movieHeight = [NSString stringWithFormat:@"%i", inputHeight];
		NSString *sizeString = [encoderOptions objectForKey:@"-s"];
		if (sizeString)
		{
			NSArray *sizeParts = [sizeString componentsSeparatedByString:@"x"];
			movieWidth = [sizeParts objectAtIndex:0];
			movieHeight = [sizeParts objectAtIndex:1];
		}
		
		NSString *region = @"NTSC";
		
		if ([movieHeight isEqualTo:@"576"])
			region = @"PAL";
		
		NSString *xmlPath = [MCCommonMethods uniquePathNameFromPath:[temporaryFolder stringByAppendingPathComponent:@"sub.xml"] withSeperator:@"-"];
		NSString *xmlContent = [NSString stringWithFormat:
		@"<subpictures format=\"%@\"><stream><textsub filename=\"%@\" characterset=\"UTF-8\" fontsize=\"%@\" font=\"%@\" horizontal-alignment=\"%@\" vertical-alignment=\"%@\" left-margin=\"%@\" right-margin=\"%@\" top-margin=\"%@\" bottom-margin=\"%@\" subtitle-fps=\"%@\" movie-fps=\"%@\" movie-width=\"%@\" movie-height=\"%@\" force=\"yes\"/></stream></subpictures>"
		, region, subPath, fontSize, [font stringByAppendingPathExtension:@"ttf"], hAlign, vAlign, lMargin, rMargin, tMargin, bMargin, fps, fps, movieWidth, movieHeight];
		
		NSString *error = nil;
		[MCCommonMethods writeString:xmlContent toFile:xmlPath errorString:&error];
		
		NSTask *spumux = [[NSTask alloc] init];
		NSFileHandle *inputHandle = [(NSPipe *)[currentTask standardOutput] fileHandleForReading];
			
		if (i == [subtitles count] - 1)
		{
			currentFileHandle = [NSFileHandle fileHandleForWritingAtPath:outPath];
			[spumux setStandardOutput:currentFileHandle];
		}
		else
		{
			NSPipe *pipe = [[NSPipe alloc] init];
			[spumux setStandardOutput:pipe];
		}
		
		[spumux setStandardInput:inputHandle];
		[spumux setLaunchPath:[[NSBundle mainBundle] pathForResource:@"spumux" ofType:@""]];
		[spumux setCurrentDirectoryPath:[outPath stringByDeletingLastPathComponent]];
		[spumux setArguments:[NSArray arrayWithObjects:@"-s", [NSString stringWithFormat:@"%i", i], xmlPath, nil]];
		
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"MCDebug"] == NO)
			[spumux setStandardError:[NSFileHandle fileHandleWithNullDevice]];
		else
			NSLog(@"XMLFile: %@", xmlContent);
		
		[MCCommonMethods logCommandIfNeeded:spumux];
		
		[NSThread detachNewThreadSelector:@selector(runTaskOnThread:) toTarget:self withObject:spumux];
		
		currentTask = spumux;
	}
	
	return YES;
}

- (BOOL)testFontWithName:(NSString *)name
{
	NSString *xmlPath = [MCCommonMethods uniquePathNameFromPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"sub.xml"] withSeperator:@"-"];
	NSString *testSubtitle = [[NSBundle mainBundle] pathForResource:@"SubTest" ofType:@"srt"];
	NSString *xmlContent = [NSString stringWithFormat:@"<subpictures format=\"NTSC\"><stream><textsub filename=\"%@\" characterset=\"UTF-8\" fontsize=\"12\" font=\"%@\" horizontal-alignment=\"center\" vertical-alignment=\"bottom\" left-margin=\"60\" right-margin=\"60\" top-margin=\"20\" bottom-margin=\"30\" subtitle-fps=\"1\" movie-fps=\"1\" movie-width=\"720\" movie-height=\"480\" force=\"yes\"/></stream></subpictures>", testSubtitle, name];
		
	NSString *error = nil;
	[MCCommonMethods writeString:xmlContent toFile:xmlPath errorString:&error];
	
	NSTask *spumux = [[NSTask alloc] init];
	NSString *testMPG = [[NSBundle mainBundle] pathForResource:@"SubTest" ofType:@"mpg"];
	NSFileHandle *inputHandle = [NSFileHandle fileHandleForReadingAtPath:testMPG];
	[spumux setStandardInput:inputHandle];
	[spumux setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
	[spumux setLaunchPath:[[NSBundle mainBundle] pathForResource:@"spumux" ofType:@""]];
	[spumux setCurrentDirectoryPath:[testMPG stringByDeletingLastPathComponent]];
	[spumux setArguments:[NSArray arrayWithObjects:xmlPath, nil]];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"MCDebug"] == NO)
			[spumux setStandardError:[NSFileHandle fileHandleWithNullDevice]];
		else
			NSLog(@"XMLFile: %@", xmlContent);
		
	[MCCommonMethods logCommandIfNeeded:spumux];
	
	[spumux launch];
	[spumux waitUntilExit];
	
	NSInteger result = [spumux terminationStatus];
	
	[spumux release];
	spumux = nil;
	
	[MCCommonMethods removeItemAtPath:xmlPath];
	
	return (result == 0);
}

- (void)writeDataOnThread:(NSString *)path
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSData *data;
	NSFileHandle *handle = [(NSPipe *)[ffmpeg standardOutput] fileHandleForReading];
	NSFileHandle *outputFile = [NSFileHandle fileHandleForWritingAtPath:path];
	
	while([data = [handle availableData] length])
	{
		[outputFile writeData:data];
	}
	
	[outputFile closeFile];
	
	[pool release];
}

- (void)runTaskOnThread:(NSTask *)task
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSPipe *errorPipe = [[NSPipe alloc] init];
	[task setStandardError:errorPipe];
	
	[task launch];
	[task waitUntilExit];
	
	NSFileHandle *handle = [errorPipe fileHandleForReading];
	NSData *data;
	NSString *string = nil;
	
	while ([data = [handle availableData] length]) 
	{
		if (string)
		{
			[string release];
			string = nil;
		}
	
		string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"MCDebug"] == YES)
			NSLog(@"%@", string);
	}
	
	NSInteger result = [task terminationStatus];
	
	if (result != 0)
	{
		if (subtitleProblem == NO)
		{
			subtitleProblem = YES;

			NSArray *errorArray = [string componentsSeparatedByString:@"ERR: "];
			NSString *problemString = [[[errorArray objectAtIndex:1] componentsSeparatedByString:@"\n"] objectAtIndex:0];
			
			NSArray *timeArray = [string componentsSeparatedByString:@"STAT: "];
			NSString *timeString = [[[timeArray lastObject] componentsSeparatedByString:@"\n"] objectAtIndex:0];
			
			NSString *xmlPath = [[task arguments] objectAtIndex:2];
			NSString *xmlString = [MCCommonMethods stringWithContentsOfFile:xmlPath encoding:NSUTF8StringEncoding error:nil];
			
			NSArray *xmlArray = [xmlString componentsSeparatedByString:@"filename=\""];
			NSString *subFileName = [[[[xmlArray objectAtIndex:1] componentsSeparatedByString:@"\""] objectAtIndex:0] lastPathComponent];
			
			detailedErrorString = [[NSString stringWithFormat:@"File: %@\nTime: %@\n%@", subFileName, timeString, problemString] retain];
		}
		
		[string release];
		string = nil;
		
		[[task standardInput] closeFile];
	}
	
	[task release];
	task = nil;
	
	[pool release];
}

///////////////////////
// Framework actions //
///////////////////////

#pragma mark -
#pragma mark •• Framework actions

- (NSArray *)succesArray
{
	return convertedFiles;
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

- (NSInteger)totalTimeInSeconds:(NSString *)path
{
	NSString *string = [self ffmpegOutputForPath:path];
	NSString *durationsString = [[[[string componentsSeparatedByString:@"Duration: "] objectAtIndex:1] componentsSeparatedByString:@"."] objectAtIndex:0];
	
	return [MCCommonMethods secondsFromTimeString:durationsString];
}

- (NSString *)mediaTimeString:(NSString *)path
{
	NSString *string = [self ffmpegOutputForPath:path];
	return [[[[[[[string componentsSeparatedByString:@"Duration: "] objectAtIndex:1] componentsSeparatedByString:@","] objectAtIndex:0] componentsSeparatedByString:@":"] objectAtIndex:1] stringByAppendingString:[@":" stringByAppendingString:[[[[[[string componentsSeparatedByString:@"Duration: "] objectAtIndex:1] componentsSeparatedByString:@","] objectAtIndex:0] componentsSeparatedByString:@":"] objectAtIndex:2]]];
}

- (void)setErrorStringWithString:(NSString *)string
{
	if (errorString)
		errorString = [NSString stringWithFormat:@"%@\n%@", errorString, string];
	else
		errorString = [string retain];
}

- (NSArray *)getCodecsOfType:(NSString *)type
{
	NSMutableArray *codecs = [NSMutableArray array];

	NSArray *arguments = [NSArray arrayWithObject:@"-codecs"];
	NSString *string;
	[MCCommonMethods launchNSTaskAtPath:[MCCommonMethods ffmpegPath] withArguments:arguments outputError:NO outputString:YES output:&string inputPipe:nil predefinedTask:nil];
	NSArray *lines = [[[[[string componentsSeparatedByString:@"------\n"] objectAtIndex:1] componentsSeparatedByString:@"\n\nNote"] objectAtIndex:0] componentsSeparatedByString:@"\n"];

	NSInteger i;
	for (i = 0; i < [lines count]; i ++)
	{
		NSString *line = [lines objectAtIndex:i];
		
		if (![line isEqualTo:@""])
		{
			NSString *format = [line substringWithRange:NSMakeRange(3, 1)];
			NSString *encoding = [line substringWithRange:NSMakeRange(2, 1)];
	
			NSString *internalFormat = [[line substringWithRange:NSMakeRange(7, 21)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			NSString *name = [line substringWithRange:NSMakeRange(29, [line length] - 29)];
			NSArray *encoders = [name componentsSeparatedByString:@"(encoders: "];
			name = [encoders objectAtIndex:0];
			name = [[name componentsSeparatedByString:@"(decoders"] objectAtIndex:0];
			
		
			if ([format isEqualTo:type] && [encoding isEqualTo:@"E"])
			{
				NSLog(@"format: %@, %@", name, encoders);
			
				if ([encoders count] > 1)
				{
					NSArray	*encoderArray = [[encoders objectAtIndex:1] componentsSeparatedByString:@" )"];
					NSString *encoderString = [encoderArray objectAtIndex:0];
					encoders = [encoderString componentsSeparatedByString:@" "];
					
					NSInteger x;
					for (x = 0; x < [encoders count]; x ++)
					{
						NSString *encoder = [encoders objectAtIndex:x];
						NSString *extendedName;
						
						if ([encoders count] > 1)
							extendedName = [NSString stringWithFormat:@"%@ - %@", name, encoder];
						else
							extendedName = name;
						
						NSDictionary *codecDictionary = [NSDictionary dictionaryWithObjectsAndKeys:extendedName, @"Name", encoder, @"Format", nil];
						[codecs addObject:codecDictionary];
					}
				}
				else
				{
					if ([internalFormat isEqualTo:@"mpeg2video"])
						name = @"MPEG-2 video";
				
					NSDictionary *codecDictionary = [NSDictionary dictionaryWithObjectsAndKeys:name, @"Name", internalFormat, @"Format", nil];
					[codecs addObject:codecDictionary];
				}
			}
		}
	}
	
	NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"Name" ascending:YES];
    [codecs sortUsingDescriptors:[NSArray arrayWithObjects:descriptor, nil]];
	
	return codecs;
}

- (NSArray *)getFormats
{
	NSMutableArray *formats = [NSMutableArray array];

	NSArray *arguments = [NSArray arrayWithObject:@"-formats"];
	NSString *string;
	[MCCommonMethods launchNSTaskAtPath:[MCCommonMethods ffmpegPath] withArguments:arguments outputError:NO outputString:YES output:&string inputPipe:nil predefinedTask:nil];
	NSArray *lines = [[[string componentsSeparatedByString:@"--\n"] objectAtIndex:1] componentsSeparatedByString:@"\n"];

	NSInteger i;
	for (i = 0; i < [lines count] - 1; i ++)
	{
		NSString *line = [lines objectAtIndex:i];

		NSString *encoding = [line substringWithRange:NSMakeRange(2, 1)];
		
		NSString *internalFormat = [[line substringWithRange:NSMakeRange(4, 16)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		NSString *name = [line substringWithRange:NSMakeRange(20, [line length] - 20)];
		
		if ([encoding isEqualTo:@"E"])
		{
			NSDictionary *codecDictionary = [NSDictionary dictionaryWithObjectsAndKeys:name, @"Name", internalFormat, @"Format", nil];
			[formats addObject:codecDictionary];
		}
	}
	
	NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"Name" ascending:YES];
    [formats sortUsingDescriptors:[NSArray arrayWithObjects:descriptor, nil]];

	return formats;
}

- (void)extractImportantFontsToPath:(NSString *)path statusStart:(NSInteger)start
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	NSMutableArray *fonts = [NSMutableArray arrayWithObjects:@"/System/Library/Fonts/Helvetica.dfont", nil];
	NSMutableArray *copyFonts = [NSMutableArray arrayWithObjects:@"Helvetica.ttf", nil];
	NSMutableArray *newCopyFontNames = [NSMutableArray arrayWithObjects:@"Helvetica.ttf", nil];
	
	if ([MCCommonMethods OSVersion] < 0x1060)
	{
		[fonts addObjectsFromArray:[NSArray arrayWithObjects:@"/Library/Fonts/Hei.dfont", @"/Library/Fonts/Osaka.dfont", nil]];
		[copyFonts addObjectsFromArray:[NSArray arrayWithObjects:@"HeiRegular.ttf", @"Osaka.ttf", nil]];
		[newCopyFontNames addObjectsFromArray:[NSArray arrayWithObjects:@"Hei.ttf", @"Osaka.ttf", nil]];
	}
	#else
	NSMutableArray *fonts = [NSMutableArray arrayWithObjects:@"/System/Library/Fonts/Helvetica.dfont", nil];
	NSMutableArray *copyFonts = [NSMutableArray arrayWithObjects:@"Helvetica.ttf", nil];
	NSMutableArray *newCopyFontNames = [NSMutableArray arrayWithObjects:@"Helvetica.ttf", nil];
	
	[fonts addObject:@"/System/Library/Fonts/AppleGothic.dfont"];
	[copyFonts addObject:@"AppleGothicRegular.ttf"];
	[newCopyFontNames addObject:@"AppleGothic.ttf"];
	#endif
	
	NSString *tempFolder = [NSTemporaryDirectory() stringByAppendingPathComponent:@"MCTemp"];
	NSString *error;
	[MCCommonMethods createDirectoryAtPath:tempFolder errorString:&error];
	NSInteger i;
	for (i = 0; i < [fonts count]; i ++)
	{
		NSString *currentPath = [fonts objectAtIndex:i];
		
		if ([[MCCommonMethods defaultManager] fileExistsAtPath:currentPath])
		{
			NSString *fontName = [copyFonts objectAtIndex:i];
			NSString *newFontName = [newCopyFontNames objectAtIndex:i];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:@"MCValueChanged" object:[NSNumber numberWithDouble:start + i]];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"MCStatusChanged" object:[NSString stringWithFormat:NSLocalizedString(@"Extracting: %@", nil), newFontName]];
			
			NSString *newPath = [tempFolder stringByAppendingPathComponent:[currentPath lastPathComponent]];
			[MCCommonMethods copyItemAtPath:currentPath toPath:newPath errorString:nil];
			
			NSString *fonduPath = [[NSBundle mainBundle] pathForResource:@"fondu" ofType:@""];
			NSTask *fondu = [[NSTask alloc] init];
			[fondu setLaunchPath:fonduPath];
			[fondu setCurrentDirectoryPath:tempFolder];
			[fondu setArguments:[NSArray arrayWithObject:newPath]];
			[fondu setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
			[fondu setStandardError:[NSFileHandle fileHandleWithNullDevice]];
			[fondu launch];
			[fondu waitUntilExit];
			
			if ([fondu terminationStatus] == 0)
				[MCCommonMethods copyItemAtPath:[tempFolder stringByAppendingPathComponent:fontName] toPath:[path stringByAppendingPathComponent:newFontName] errorString:nil];
			
			[fondu release];
			fondu = nil;
		}
		
		
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MCValueChanged" object:[NSNumber numberWithDouble:start + [fonts count]]];
	
	[MCCommonMethods removeItemAtPath:tempFolder];
}

- (void)downloadYouTubeURL:(NSString *)urlString toTask:(NSTask *)inTask outPipe:(NSPipe **)pipe
{
	NSTask *youtubeDL = [[NSTask alloc] init];
	NSPipe *youtubePipe = [[NSPipe alloc] init];
	
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	[youtubeDL setLaunchPath:@"/usr/bin/python"];
	#else
	[youtubeDL setLaunchPath:@"/usr/local/bin/python"];
	#endif
	
	NSString *youtubeDLPath = [[NSBundle mainBundle] pathForResource:@"youtube-dl" ofType:@"sh"];
	[youtubeDL setArguments:[NSArray arrayWithObjects:youtubeDLPath, urlString, @"-o", @"-", nil]];
	[youtubeDL setStandardOutput:youtubePipe];
	
	if (inTask != nil)
		[inTask setStandardInput:youtubePipe];
			
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"MCDebug"] == NO)
		[youtubeDL setStandardError:[NSFileHandle fileHandleWithNullDevice]];
			
	[MCCommonMethods logCommandIfNeeded:youtubeDL];
	[youtubeDL launch];
	
	if (pipe != nil)
		*pipe = youtubePipe;
}

- (NSString *)getYouTubeName:(NSString *)urlString
{
	NSString *string;
	NSString *curlPath = @"/usr/bin/curl";
	NSArray *arguments = [NSArray arrayWithObject:urlString];
	[MCCommonMethods launchNSTaskAtPath:curlPath withArguments:arguments outputError:NO outputString:YES output:&string inputPipe:nil predefinedTask:nil];
	
	if ([string rangeOfString:@"<meta name=\"title\" content=\""].length > 0)
	{
		NSString *titleString = [[[[string componentsSeparatedByString:@"<meta name=\"title\" content=\""] objectAtIndex:1] componentsSeparatedByString:@"\""] objectAtIndex:0];
		
		return titleString;
		
		/*titleString = [titleString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		NSArray *parts = [titleString componentsSeparatedByString:@"-"];
		
		NSInteger i;
		titleString = @"";
		for (i = 1; i < [parts count]; i ++)
		{
			NSString *partString = [parts objectAtIndex:i];
			
			if (i > 1)
				titleString = [NSString stringWithFormat:@"%@-%@", titleString, partString];
			else
				titleString = [partString substringWithRange:NSMakeRange(1, [partString length] - 1)];
		}
		
		return (NSString*)CFXMLCreateStringByUnescapingEntities(kCFAllocatorDefault, (CFStringRef)titleString, NULL);*/
	}
	
	return [urlString lastPathComponent];
}

@end