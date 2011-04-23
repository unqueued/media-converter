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
															@"gr", @"zht", @"zhs", @"zh_TW", @"zh_CN", @"chs", @"cht", nil];
															
	NSArray	*newLanguageCodes = [NSArray arrayWithObjects:	@"sqi", @"hye", @"eus", @"mya", @"zho", @"deu", @"fra", @"kat", @"ell", 
															@"isl", @"hrv", @"mkd", @"msa", @"nld", @"fas", @"ron", @"srp", @"slk", 
															@"bod", @"ces", @"cym", @"sq", @"hy", @"bs", @"zh", @"cs", @"da", @"ja", 
															@"el", @"zh", @"zh", @"zh", @"zh", @"zh", @"zh", nil];
															
	oldToNewLanguageCodes = [NSDictionary dictionaryWithObjects:newLanguageCodes forKeys:oldLanguageCodes];
	
	cyrillicLanguages = [NSArray arrayWithObjects:			@"abk", @"ab", @"ava", @"av", @"aze", @"az", @"bak", @"ba", @"bel", @"be",
															@"bul", @"bg", @"che", @"ce", @" chu", @"cu", @"chv", @"cv", @"kaz", @"kk",
															@"kom", @"kv", @"kur", @"ku", @"mkd", @"mk", @"mon", @"mn", @"sme", @"se",
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
	convertedFiles = nil;
	
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
	
	NSString *ffmpegOutput = nil;

	NSInteger i;
	for (i = 0; i < [files count]; i ++)
	{
		NSString *currentPath = [files objectAtIndex:i];
	
		if (userCanceled == NO)
		{
			number = i;
		
			[[NSNotificationCenter defaultCenter] postNotificationName:@"MCTaskChanged" object:[NSString stringWithFormat:NSLocalizedString(@"Encoding file %i of %i to '%@'", nil), i + 1, [files count], [options objectForKey:@"Name"]]];
		
			//Test the file on how to encode it
			NSInteger output = [self testFile:currentPath errorString:&*error];
			
			useWav = (output == 2 | output == 4 | output == 8);
			useQuickTime = (output == 2 | output == 3 | output == 6);
			
			BOOL stream = (![[NSFileManager defaultManager] fileExistsAtPath:currentPath]);
			if (stream && (useWav | useQuickTime))
			{
				NSString *streamError;
				if (useWav)
					streamError = NSLocalizedString(@"%@ (Unsupported audio)", nil);
				else
					streamError = NSLocalizedString(@"%@ (Unsupported video)", nil);
				
				NSString *displayName = [[NSFileManager defaultManager] displayNameAtPath:currentPath];
				
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
				NSString *displayName = [[NSFileManager defaultManager] displayNameAtPath:currentPath];
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
	
	// Reset our stuff
	subtitleProblem = NO;
	detailedErrorString = nil;
	
	NSMutableArray *options = [NSMutableArray arrayWithArray:[convertOptions objectForKey:@"Encoder Options"]];
	NSDictionary *extraOptions = [convertOptions objectForKey:@"Extra Options"];
	
	// Encoder options for ffmpeg, movtoy4m
	NSString *outFileWithExtension = [MCCommonMethods uniquePathNameFromPath:[NSString stringWithFormat:@"%@/%@.%@", convertDestination, [[path lastPathComponent] stringByDeletingPathExtension], convertExtension] withSeperator:@" "];
	NSString *outputFile = [outFileWithExtension stringByDeletingPathExtension];
	temporaryFolder = [[NSString alloc] initWithString:[NSTemporaryDirectory() stringByAppendingPathComponent:@"MCTemp"]];
	[MCCommonMethods createDirectoryAtPath:temporaryFolder errorString:nil];
	
	NSString *subtitleType = [extraOptions objectForKey:@"Subtitle Type"];
	
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
	
	if ([[extraOptions objectForKey:@"Auto Size"] boolValue] == YES && [options objectForKey:@"-s"])
	{
		[options setObject:nil forKey:@"-aspect"];
		
		//Must be a better way since multiple videofilters can be set
		if ([[options objectForKey:@"-vf"] rangeOfString:@"setdar"].length > 0)
			[options setObject:nil forKey:@"-vf"];
	
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
		
		NSString *heightString = [NSString stringWithFormat:@"%f", width / aspect];
		newSizeString = [NSString stringWithFormat:@"%ix%i", (NSInteger)width, [self convertToEven:heightString]];
		
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
	
	if ([[extraOptions objectForKey:@"Keep Aspect"] boolValue] == YES)
	{
		if (!aspectString)
			aspectString = [options objectForKey:@"-aspect"];
			
		NSString *sizeString = [options objectForKey:@"-s"];
		BOOL topBars;

		if (sizeString)
		{
			NSArray *sizeParts = [sizeString componentsSeparatedByString:@"x"];
			CGFloat width = [[sizeParts objectAtIndex:0] cgfloatValue];
			CGFloat height = [[sizeParts objectAtIndex:1] cgfloatValue];
			
			CGFloat aspectWidth;
			CGFloat aspectHeight;
			
			if (aspectString)
			{
				NSArray *aspectParts = [aspectString componentsSeparatedByString:@":"];
				aspectWidth = [[aspectParts objectAtIndex:0] cgfloatValue];
				aspectHeight = [[aspectParts objectAtIndex:1] cgfloatValue];
			}
			else
			{
				aspectWidth = width;
				aspectHeight = height;
			}
		
			if (inputAspect != (aspectWidth / aspectHeight))
			{
				topBars = (inputAspect > (aspectWidth / aspectHeight));
		
				CGFloat calculateSize = width;
		
				if (topBars)
					calculateSize = height;
		
				NSInteger padSize = [self getPadSize:calculateSize withAspect:NSMakeSize(aspectWidth, aspectHeight) withTopBars:topBars];

				if (topBars)
					padOptions = [NSArray arrayWithObjects:@"-vf", [NSString stringWithFormat:@"scale=%i:%i,pad=%i:%i:0:%i:black", (NSInteger)width, (NSInteger)height - (padSize * 2), (NSInteger)width, (NSInteger)height, padSize], nil];
				else
					padOptions = [NSArray arrayWithObjects:@"-vf", [NSString stringWithFormat:@"scale=%i:%i,pad=%i:%i:%i:0:black", (NSInteger)width - (padSize * 2), (NSInteger)height, (NSInteger)width, (NSInteger)height, padSize], nil];
			}
		}
	}
	
	NSInteger passes = 1;
	if ([[extraOptions objectForKey:@"Two Pass"] boolValue] == YES)
		passes = 2;
	
	if (![subtitleType isEqualTo:@"none"] && ![subtitleType isEqualTo:@"dvd"])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MCStatusChanged" object:[NSString stringWithFormat:NSLocalizedString(@"Converting subtitles: %@…", nil), [[NSFileManager defaultManager] displayNameAtPath:path]]];
		temporarySubtitleFile = [[temporaryFolder stringByAppendingPathComponent:@"tmpmovie"] stringByAppendingPathExtension:subtitleType];
		[self createMovieWithSubtitlesAtPath:temporarySubtitleFile inputFile:path ouputType:subtitleType];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MCStatusChanged" object:[NSLocalizedString(@"Encoding: ", Localized) stringByAppendingString:[[NSFileManager defaultManager] displayNameAtPath:path]]];
	
	NSInteger taskStatus;
	NSMutableString *ffmpegErrorString = nil;
	
	NSInteger pass;
	for (pass = 0; pass < passes; pass ++)
	{
		ffmpeg = [[NSTask alloc] init];
		NSPipe *pipe2;
		NSPipe *errorPipe;

		//Check if we need to use movtoy4m to decode
		if (useQuickTime == YES)
		{
			quicktimeOptions = [NSArray arrayWithObjects:@"-f", @"yuv4mpegpipe", @"-i", @"-", nil];
	
			movtoy4m = [[NSTask alloc] init];
			pipe2 = [[NSPipe alloc] init];
			NSFileHandle *handle2;
			[movtoy4m setLaunchPath:[[NSBundle mainBundle] pathForResource:@"movtoy4m" ofType:@""]];
			[movtoy4m setArguments:[NSArray arrayWithObjects:@"-w",[NSString stringWithFormat:@"%i", inputWidth],@"-h",[NSString stringWithFormat:@"%i", inputHeight],@"-F",[NSString stringWithFormat:@"%f:1", inputFps],@"-a",[NSString stringWithFormat:@"%i:%i", inputWidth, inputHeight],path, nil]];
			[movtoy4m setStandardOutput:pipe2];
		
			if ([defaults boolForKey:@"MCDebug"] == NO)
			{
				errorPipe = [[NSPipe alloc] init];
				[movtoy4m setStandardError:[NSFileHandle fileHandleWithNullDevice]];
			}
	
			[ffmpeg setStandardInput:pipe2];
			handle2 = [pipe2 fileHandleForReading];
			[MCCommonMethods logCommandIfNeeded:movtoy4m];
			[movtoy4m launch];
		}
	
		if (useWav == YES)
		{
			wavOptions = [NSArray arrayWithObjects:@"-i", [outputFile stringByAppendingString:@" (tmp).wav"], nil];
		}
	
		if (useWav == NO | useQuickTime == NO)
		{
			inputOptions = [NSArray arrayWithObjects:@"-i", path, nil];
		}

		NSPipe *pipe = [[NSPipe alloc] init];
		NSFileHandle *handle;
		NSData *data;
	
		[ffmpeg setLaunchPath:[MCCommonMethods ffmpegPath]];
	
		NSMutableArray *args = [NSMutableArray array];
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
			else
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
			[self createMovieWithSubtitlesAtPath:outFileWithExtension inputFile:path ouputType:@"dvd"];

		if (useQuickTime == YES)
			status = 3;
		else
			status = 2;

		NSString *string = nil;
	
		//Get the time we want to encode
		NSString *timeString = [options objectForKey:@"-t"];
	
		if (timeString)
			inputTotalTime = [timeString integerValue];
			
		inputTotalTime = inputTotalTime * passes;
		
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
		
			//Format the time sting ffmpeg outputs and format it to percent
			if ([string rangeOfString:@"time="].length > 0)
			{
				started = YES;
		
				NSString *currentTimeString = [[[[string componentsSeparatedByString:@"time="] objectAtIndex:1] componentsSeparatedByString:@" "] objectAtIndex:0];
				CGFloat percent = ([currentTimeString cgfloatValue] + (inputTotalTime / 2 * pass)) / inputTotalTime * 100;
				
				NSString *currentPass = @"";
						
				if (passes == 2)
					currentPass = [NSString stringWithFormat: @"pass %i - ", pass + 1];
				
				if (inputTotalTime > 0)
				{
					if (percent < 101)
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
			[[NSFileManager defaultManager] movePath:tempFile toPath:outFileWithExtension handler:nil];
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
	
	if (temporarySubtitleFile && [[NSFileManager defaultManager] fileExistsAtPath:temporarySubtitleFile])
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
				[[NSFileManager defaultManager] movePath:temporaryFile toPath:outFileWithExtension handler:nil];
			}
		}
		else if ([subtitleType isEqualTo:@"mkv"])
		{
			NSString *temporaryFile = [temporaryFolder stringByAppendingPathComponent:[outFileWithExtension lastPathComponent]];
			BOOL result = [self addTracksFromMKVMovie:[NSArray arrayWithObjects:outFileWithExtension, temporarySubtitleFile, nil] toPath:temporaryFile];
	
			if (result)
			{
				[MCCommonMethods removeItemAtPath:outFileWithExtension];
				[[NSFileManager defaultManager] movePath:temporaryFile toPath:outFileWithExtension handler:nil];
			}
		}
	}
	
	[MCCommonMethods removeItemAtPath:temporaryFolder];
	[temporaryFolder release];
	temporaryFolder = nil;
	
	//Return if ffmpeg failed or not
	if (taskStatus == 0)
	{
		status = 0;
		encodedOutputFile = outFileWithExtension;
		
		if ([subtitleType isEqualTo:@"srt"])
			[self extractSubtitlesFromMovieAtPath:path toPath:[outFileWithExtension stringByDeletingPathExtension]];
	
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
	NSFileManager *defaultFileManager = [NSFileManager defaultManager];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MCStatusChanged" object:[NSString stringWithFormat:NSLocalizedString(@"Decoding sound: %@", nil), [defaultFileManager displayNameAtPath:path]]];

	//Output file (without extension)
	NSString *outputFile = [NSString stringWithFormat:@"%@/%@", convertDestination, [[path lastPathComponent] stringByDeletingPathExtension]];

	outputFile = [[MCCommonMethods uniquePathNameFromPath:[outputFile stringByAppendingPathExtension:convertExtension] withSeperator:@" "] stringByDeletingPathExtension];
	outputFile = [NSString stringWithFormat:@"%@ (tmp)", outputFile];

	if ([defaultFileManager fileExistsAtPath:[outputFile stringByAppendingString:@".wav"]])
		[MCCommonMethods removeItemAtPath:[outputFile stringByAppendingString:@".wav"]];
	
	//movtowav encodes quicktime movie's sound to wav
	movtowav = [[NSTask alloc] init];
	[movtowav setLaunchPath:[[NSBundle mainBundle] pathForResource:@"movtowav" ofType:@""]];
	[movtowav setArguments:[NSArray arrayWithObjects:@"-o", [outputFile stringByAppendingString:@".wav"], path,nil]];
	NSInteger taskStatus;

	NSPipe *pipe=[[NSPipe alloc] init];
	NSFileHandle *handle=[pipe fileHandleForReading];
	[movtowav setStandardError:pipe];
	[MCCommonMethods logCommandIfNeeded:movtowav];
	[movtowav launch];
	NSString *string = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSUTF8StringEncoding];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"MCDebug"] == YES)
		NSLog(@"%@", string);

	status = 1;
	[movtowav waitUntilExit];
	taskStatus = [movtowav terminationStatus];
	[movtowav release];
	movtowav = nil;
	[pipe release];
	pipe = nil;
	[string release];
	string = nil;
	
	//Check if it all went OK if not remove the wave file and return NO
    if (!taskStatus == 0)
	{
		[MCCommonMethods removeItemAtPath:[outputFile stringByAppendingString:@".wav"]];
	
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
	NSString *displayName = [[NSFileManager defaultManager] displayNameAtPath:path];
	NSString *tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tmpkf"];
	
	BOOL audioWorks = YES;
	BOOL videoWorks = YES;
	BOOL keepGoing = YES;
	
	NSArray *options = [convertOptions objectForKey:@"Encoder Options"];
	
	BOOL needsAudio = ([options objectForKey:@"-vn"] != nil);
	BOOL needsVideo = ([options objectForKey:@"-an"] != nil);

	while (keepGoing == YES)
	{
		NSMutableArray *arguments  = [NSMutableArray arrayWithObjects:@"-t", @"1", @"-vframes", @"1", @"-i", path, nil];
		
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
		 
		  // = [NSMutableArray arrayWithObjects:@"-vframes", @"1", @"-i", path, @"-target", @"pal-vcd", nil];
			
		if (videoWorks == NO)
			[arguments addObject:@"-vn"];
		else if (audioWorks == NO)
			[arguments addObject:@"-an"];
				
		[arguments addObjectsFromArray:[NSArray arrayWithObjects:@"-ac",@"2",@"-r",@"25",@"-y", tempFile,nil]];
		
		NSString *string;
		BOOL result = [MCCommonMethods launchNSTaskAtPath:[MCCommonMethods ffmpegPath] withArguments:arguments outputError:YES outputString:YES output:&string];
		
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
	NSString *one = [[[[[[output componentsSeparatedByString:@"Output #0"] objectAtIndex:0] componentsSeparatedByString:@"Stream #0.0"] objectAtIndex:1] componentsSeparatedByString:@": "] objectAtIndex:1];
	NSString *two = @"";
	
	if ([output rangeOfString:@"Stream #0.1"].length > 0)
		two = [[[[[[output componentsSeparatedByString:@"Output #0"] objectAtIndex:0] componentsSeparatedByString:@"Stream #0.1"] objectAtIndex:1] componentsSeparatedByString:@": "] objectAtIndex:1];

	//Is stream 0.0 audio or video
	if ([output rangeOfString:@"for input stream #0.0"].length > 0 | [output rangeOfString:@"Error while decoding stream #0.0"].length > 0)
	{
		if ([one isEqualTo:kind])
		{
			return NO;
		}
	}
			
	//Is stream 0.1 audio or video
	if ([output rangeOfString:@"for input stream #0.1"].length > 0| [output rangeOfString:@"Error while decoding stream #0.1"].length > 0)
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
	NSString *inputString = [[output componentsSeparatedByString:@"Input"] objectAtIndex:1];

	inputWidth = 0;
	inputHeight = 0;
	inputFps = 0;
	inputTotalTime = 0;
	inputAspect = 0;
	inputFormat = 0;

	//Calculate the aspect ratio width / height	
	if ([[[inputString componentsSeparatedByString:@"Output"] objectAtIndex:0] rangeOfString:@"Video:"].length > 0)
	{
		NSArray *resolutionArray = [[[[[[[inputString componentsSeparatedByString:@"Output"] objectAtIndex:0] componentsSeparatedByString:@"Video:"] objectAtIndex:1] componentsSeparatedByString:@"\n"] objectAtIndex:0] componentsSeparatedByString:@"x"];
		NSArray *fpsArray = [[[[[inputString componentsSeparatedByString:@"Output"] objectAtIndex:0] componentsSeparatedByString:@" tbc"] objectAtIndex:0] componentsSeparatedByString:@","];
		
		NSArray *beforeX = [[resolutionArray objectAtIndex:0] componentsSeparatedByString:@" "];
		NSArray *afterX = [[resolutionArray objectAtIndex:1] componentsSeparatedByString:@" "];
		
		inputWidth = [[beforeX objectAtIndex:[beforeX count] - 1] integerValue];
		inputHeight = [[afterX objectAtIndex:0] integerValue];
		inputFps = [[fpsArray objectAtIndex:[fpsArray count] - 1] integerValue];
	
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
			
				if ([[NSFileManager defaultManager] fileExistsAtPath:projectSettings])
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
		inputTotalTime = 0;
	
		if (![inputString rangeOfString:@"Duration: N/A,"].length > 0)
		{
			NSString *time = [[[[inputString componentsSeparatedByString:@"Duration: "] objectAtIndex:1] componentsSeparatedByString:@","] objectAtIndex:0];
			double hour = [[[time componentsSeparatedByString:@":"] objectAtIndex:0] doubleValue];
			double minute = [[[time componentsSeparatedByString:@":"] objectAtIndex:1] doubleValue];
			double second = [[[time componentsSeparatedByString:@":"] objectAtIndex:2] doubleValue];
			
			inputTotalTime  = (hour * 60 * 60) + (minute * 60) + second;
		}
	}
	
	BOOL hasOutput = YES;
		
	if (hasOutput)
	{
		return YES;
	}
	else
	{
		[self setErrorStringWithString:[NSString stringWithFormat:NSLocalizedString(@"%@ (Couldn't get attributes)", nil), [[NSFileManager defaultManager] displayNameAtPath:file]]];
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
	NSArray *arguments = [NSArray arrayWithObjects:@"-i", path, nil];
	[MCCommonMethods launchNSTaskAtPath:[MCCommonMethods ffmpegPath] withArguments:arguments outputError:YES outputString:YES output:&string];
	
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
- (BOOL)createMovieWithSubtitlesAtPath:(NSString *)path inputFile:(NSString *)inFile ouputType:(NSString *)type
{
	BOOL result;
	BOOL firstSubtitle = YES;

	//Extract subtitles from input mp4 / mkv / ogg, when possible
	NSString *subPath = [temporaryFolder stringByAppendingPathComponent:@"Subtitles"];
	[self extractSubtitlesFromMovieAtPath:inFile toPath:subPath];
	
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
			[self addSubtitlesToMKVMovie:subtitlePaths outPath:path forLanguages:languages];
		else if ([type isEqualTo:@"kate"])
			[self addSubtitlesToOGGMovie:subtitlePaths outPath:path forLanguages:languages];
	}
	
	if ([type isEqualTo:@"dvd"])
		[self addDVDSubtitlesToOutputStreamFromTask:ffmpeg withSubtitles:subtitlePaths toPath:path];
	
	return YES;
}

- (BOOL)extractSubtitlesFromMovieAtPath:(NSString *)inPath toPath:(NSString *)outPath
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
	
	NSInteger i;
	for (i = 0; i < [folderContents count]; i ++)
	{
		NSString *currentPath = [folderContents objectAtIndex:i];
		NSString *extensionlessPath = [[[currentPath stringByDeletingPathExtension] stringByDeletingPathExtension] lastPathComponent];
		result = YES;

		if ([extensionlessPath isEqualTo:fileName])
		{
			NSString *fileExtension = [[currentPath pathExtension] lowercaseString];
			
			if ([supportedFileTypes containsObject:fileExtension])
			{
				NSString *newPath = currentPath;
				NSString *language = [[currentPath stringByDeletingPathExtension] pathExtension];

				if ([fileExtension isEqualTo:@"srt"])
				{
					//Don't copy a srt file when using the same input folder as the output folder
					if ([beforeFolderContents containsObject:currentPath])
					{
						//NSString *originalString = [NSString stringWithContentsOfFile:currentPath];
						
						NSString *originalString = [MCCommonMethods stringWithContentsOfFile:currentPath encoding:NSUTF8StringEncoding error:nil];
						NSString *language = [[currentPath stringByDeletingPathExtension] pathExtension];

						if (!originalString)
						{
							NSStringEncoding encoding = 0x0000000C;
							
							if ([cyrillicLanguages containsObject:language])
								encoding = 0x0000000B;
							else if ([language isEqualTo:@"zho"] | [language isEqualTo:@"zh"] | [language isEqualTo:@"zht"] | [language isEqualTo:@"zh_TW"] | [language isEqualTo:@"cht"])
								encoding = 0x80000632;
							else if ([language isEqualTo:@"cn"] | [language isEqualTo:@"zhs"] | [language isEqualTo:@"zh_CN"] | [language isEqualTo:@"chs"])
								encoding = 0x80000421;
							else if ([language isEqualTo:@"ara"] | [language isEqualTo:@"ar"] | [language isEqualTo:@"som"] | [language isEqualTo:@"so"])
								encoding = 0x80000506;
							else if ([language isEqualTo:@"ell"] | [language isEqualTo:@"el"] | [language isEqualTo:@"gr"])
								encoding = 0x0000000D;
							else if ([language isEqualTo:@"heb"] | [language isEqualTo:@"he"] | [language isEqualTo:@"yid"] | [language isEqualTo:@"yi"])
								encoding = 0x80000505;
							else if ([language isEqualTo:@"jpn"] | [language isEqualTo:@"ja"] | [language isEqualTo:@"jp"])
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
						
						NSDictionary *languageDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Languages" ofType:@"plist"]];
						if ([[languageDict allKeysForObject:language] count] == 0)
						{
							if ([[oldToNewLanguageCodes allKeys] containsObject:language])
								language = [oldToNewLanguageCodes objectForKey:language];
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
	
	return [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil];
}

- (BOOL)convertSubtitleFromMP4Movie:(NSString *)inPath toSubtitle:(NSString *)outPath outType:(NSString *)type fromID:(NSString *)streamID
{
	[[NSFileManager defaultManager] createFileAtPath:outPath contents:[NSData data] attributes:nil];
	
	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"MP4Box" ofType:@""];
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"-%@", type]];
	
	if (streamID != nil)
		[arguments addObject:streamID];
		
	[arguments addObjectsFromArray:[NSArray arrayWithObjects:inPath, @"-std", @"-quiet", @"-noprog", nil]];
	
	NSString *output;
	BOOL result = [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:YES output:&output];
	
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
	return [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil];
}

- (NSArray *)trackDictionariesFromMP4MovieAtPath:(NSString *)path
{
	NSMutableArray *trackNumbers = [NSMutableArray array];
	
	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"MP4Box" ofType:@""];
	NSArray *arguments = [NSArray arrayWithObjects:@"-info", path, nil];
	
	NSString *output;
	BOOL result = [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:YES output:&output];
	
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

	return [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil];
}

- (BOOL)extractSubtitlesFromMKVMovie:(NSString *)inPath ofType:(NSString *)type toPath:(NSString *)outPath
{
	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"mkvextract" ofType:@""];
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"tracks", inPath, nil];
	
	NSArray *trackDictionaries = [self trackDictionariesFromMKVMovieAtPath:inPath];
		
	NSInteger i;
	for (i = 0; i < [trackDictionaries count]; i ++)
	{
		NSDictionary *currentTrackDictionary = [trackDictionaries objectAtIndex:i];
		NSString *language = [currentTrackDictionary objectForKey:@"Language Code"];
		NSString *idString = [currentTrackDictionary objectForKey:@"Track ID"];
			
		[arguments addObject:[NSString stringWithFormat:@"%@:%@.%@.srt", idString, outPath, language]];
	}
	
	return [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil];
}

- (BOOL)addTracksFromMKVMovie:(NSArray *)inPaths toPath:(NSString *)outPath
{
	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"mkvmerge" ofType:@""];
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-o", outPath, nil];
	[arguments addObjectsFromArray:inPaths];

	return [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil];
}

- (NSArray *)trackDictionariesFromMKVMovieAtPath:(NSString *)path
{	
	NSMutableArray *trackNumbers = [NSMutableArray array];
	
	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"mkvinfo" ofType:@""];
	NSArray *arguments = [NSArray arrayWithObject:path];
	
	NSString *output;
	BOOL result = [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:YES output:&output];
	
	if (result == YES)
	{
		NSArray *tracks = [output componentsSeparatedByString:@"| + A track"];
		
		NSInteger i;
		for (i = 0; i < [tracks count]; i ++)
		{
			NSString *track = [tracks objectAtIndex:i];
			NSLog(@"Track: %@", track);
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

	return [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil];
}

- (BOOL)addTracksFromOGGMovies:(NSArray *)inPaths toPath:(NSString *)outPath
{
	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"oggz-merge" ofType:@""];
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-o", outPath, nil];
	[arguments addObjectsFromArray:inPaths];
	
	return [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil];
}

- (BOOL)convertSRT:(NSString *)inPath toKateOGG:(NSString *)outPath forLanguage:(NSString *)language
{
	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"kateenc" ofType:@""];
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-c", @"SUB", @"-t",  @"srt", @"-l", language, @"-o", outPath, inPath, nil];
	
	return [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil];
}

- (BOOL)extractSubtitlesFromOGGMovie:(NSString *)inPath ofType:(NSString *)type toPath:(NSString *)outPath
{
	NSArray *trackDictionaries = [self trackDictionariesFromOGGMovieAtPath:inPath];

	NSInteger i;
	for (i = 0; i < [trackDictionaries count]; i ++)
	{
		NSString *helperPath;
		NSArray *arguments;
		NSString *tmpOggFile;
		
		NSDictionary *currentTrackDictionary = [trackDictionaries objectAtIndex:i];
		NSString *language = [currentTrackDictionary objectForKey:@"Language Code"];
		NSString *idString = [currentTrackDictionary objectForKey:@"Track ID"];
	
		if ([trackDictionaries count] > 1)
		{
			helperPath = [[NSBundle mainBundle] pathForResource:@"oggz-rip" ofType:@""];
		
			tmpOggFile = [NSString stringWithFormat:@"%@.ogg", outPath];
			arguments = [NSArray arrayWithObjects:@"-s", idString, @"-o", tmpOggFile, inPath, nil];
			
			[MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil];
		}
		else
		{
			tmpOggFile = inPath;
		}
		
		helperPath = [[NSBundle mainBundle] pathForResource:@"katedec" ofType:@""];
		
		NSString *outputFile = [NSString stringWithFormat:@"%@.%@.srt", outPath, language];
		outputFile = [MCCommonMethods uniquePathNameFromPath:outputFile withSeperator:@"_"];
		
		arguments = [NSArray arrayWithObjects:@"-t", @"srt", @"-o", outputFile, tmpOggFile, nil];
		NSLog(@"Arguments: %@", arguments);
		[MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:NO output:nil];
	}
	
	return YES;
}

- (NSArray *)trackDictionariesFromOGGMovieAtPath:(NSString *)path
{	
	NSMutableArray *trackNumbers = [NSMutableArray array];
	
	NSString *helperPath = [[NSBundle mainBundle] pathForResource:@"oggz-info" ofType:@""];
	NSArray *arguments = [NSArray arrayWithObject:path];
	
	NSString *output;
	BOOL result = [MCCommonMethods launchNSTaskAtPath:helperPath withArguments:arguments outputError:NO outputString:YES output:&output];
	NSLog(@"Output: %@", output);
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
	NSFileManager *defaultManager = [NSFileManager defaultManager];
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
		
		NSString *spumuxPath = [NSHomeDirectory() stringByAppendingPathComponent:@".spumux"];
		NSString *language = [[subPath stringByDeletingPathExtension] pathExtension];
		
		NSString *font = nil;
		if ([cyrillicLanguages containsObject:language])
			font = @"HelveticaCYPlain";
		else if ([language isEqualTo:@"zho"] | [language isEqualTo:@"zh"] | [language isEqualTo:@"chs"])
			font = @"Hei";
		else if ([language isEqualTo:@"ara"] | [language isEqualTo:@"ar"] | [language isEqualTo:@"som"] | [language isEqualTo:@"so"])
			font = @"AlBayan";
		else if ([language isEqualTo:@"ell"] | [language isEqualTo:@"el"])
			font = @"Lucida Sans Unicode";
		else if ([language isEqualTo:@"heb"] | [language isEqualTo:@"he"] | [language isEqualTo:@"yid"] | [language isEqualTo:@"yi"])
			font = @"Raanana";
		else if ([language isEqualTo:@"jpn"] | [language isEqualTo:@"ja"])
			font = @"Osaka";
		else if ([language isEqualTo:@"tha"] | [language isEqualTo:@"th"])
			font = @"Ayuthaya";
		else if ([language isEqualTo:@"kor"] | [language isEqualTo:@"ko"])
			font = @"AppleGothic";
		else if ([language isEqualTo:@"cht"] | [language isEqualTo:@"zht"])
			font = @"LiHei Pro";
		else if ([language isEqualTo:@"hye"] | [language isEqualTo:@"hy"])
			font = @"MshtakanRegular";
		
		if (font == nil | ![[NSFileManager defaultManager] fileExistsAtPath:[spumuxPath stringByAppendingPathComponent:[font stringByAppendingPathExtension:@"ttf"]]])
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
		
		NSString *xmlPath = [MCCommonMethods uniquePathNameFromPath:[temporaryFolder stringByAppendingPathComponent:@"sub.xml"] withSeperator:@"-"];
		NSString *xmlContent = [NSString stringWithFormat:
		@"<subpictures><stream><textsub filename=\"%@\" characterset=\"UTF-8\" fontsize=\"%@\" font=\"%@\" horizontal-alignment=\"%@\" vertical-alignment=\"%@\" left-margin=\"%@\" right-margin=\"%@\" top-margin=\"%@\" bottom-margin=\"%@\" subtitle-fps=\"%@\" movie-fps=\"%@\" movie-width=\"%@\" movie-height=\"%@\" force=\"yes\"/></stream></subpictures>"
		, subPath, fontSize, [font stringByAppendingPathExtension:@"ttf"], hAlign, vAlign, lMargin, rMargin, tMargin, bMargin, fps, fps, movieWidth, movieHeight];
		
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
		//[spumux setStandardError:[NSFileHandle fileHandleWithNullDevice]];
		
		[NSThread detachNewThreadSelector:@selector(runTaskOnThread:) toTarget:self withObject:spumux];
		
		currentTask = spumux;
	}
	
	return YES;
}

- (BOOL)testFontWithName:(NSString *)name
{
	NSString *xmlPath = [MCCommonMethods uniquePathNameFromPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"sub.xml"] withSeperator:@"-"];
	NSString *testSubtitle = [[NSBundle mainBundle] pathForResource:@"SubTest" ofType:@"srt"];
	NSString *xmlContent = [NSString stringWithFormat:@"<subpictures><stream><textsub filename=\"%@\" characterset=\"UTF-8\" fontsize=\"12\" font=\"%@\" horizontal-alignment=\"center\" vertical-alignment=\"bottom\" left-margin=\"60\" right-margin=\"60\" top-margin=\"20\" bottom-margin=\"30\" subtitle-fps=\"1\" movie-fps=\"1\" movie-width=\"720\" movie-height=\"480\" force=\"yes\"/></stream></subpictures>", testSubtitle, name];
		
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
	
	[spumux launch];
	[spumux waitUntilExit];
	
	NSInteger result = [spumux terminationStatus];
	
	[spumux release];
	spumux = nil;
	
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
	
	while([data = [handle availableData] length]) 
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
	
	//NSFileHandle *handle = [(NSPipe *)[ffmpeg standardOutput] fileHandleForReading];
	//[handle closeFile];
	
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

- (NSInteger)convertToEven:(NSString *)numberAsString
{
	NSString *convertedNumber = [[NSNumber numberWithInteger:[numberAsString integerValue]] stringValue];

	unichar ch = [convertedNumber characterAtIndex:[convertedNumber length] -1];
	NSString *lastCharacter = [NSString stringWithFormat:@"%C", ch];

	if ([lastCharacter isEqualTo:@"1"] | [lastCharacter isEqualTo:@"3"] | [lastCharacter isEqualTo:@"5"] | [lastCharacter isEqualTo:@"7"] | [lastCharacter isEqualTo:@"9"])
		return [[NSNumber numberWithInteger:[convertedNumber integerValue] + 1] integerValue];
	else
		return [convertedNumber integerValue];
}

- (NSInteger)getPadSize:(CGFloat)size withAspect:(NSSize)aspect withTopBars:(BOOL)topBars
{	
	if (topBars)
		return [self convertToEven:[[NSNumber numberWithCGFloat:(size - (size * aspect.width / aspect.height) / ((CGFloat)inputWidth / (CGFloat)inputHeight)) / 2] stringValue]];
	else
		return [self convertToEven:[[NSNumber numberWithCGFloat:((size * aspect.width / aspect.height) / ((CGFloat)inputWidth / (CGFloat)inputHeight) - size) / 2] stringValue]];
}

- (NSInteger)totalTimeInSeconds:(NSString *)path
{
	NSString *string = [self ffmpegOutputForPath:path];
	NSString *durationsString = [[[[string componentsSeparatedByString:@"Duration: "] objectAtIndex:1] componentsSeparatedByString:@"."] objectAtIndex:0];

	NSInteger hours = [[[durationsString componentsSeparatedByString:@":"] objectAtIndex:0] integerValue];
	NSInteger minutes = [[[durationsString componentsSeparatedByString:@":"] objectAtIndex:1] integerValue];
	NSInteger seconds = [[[durationsString componentsSeparatedByString:@":"] objectAtIndex:2] integerValue];

	return seconds + (minutes * 60) + (hours * 60 * 60);
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

- (NSArray *)getAudioCodecs
{
	NSMutableArray *audioCodecs = [NSMutableArray array];

	NSArray *arguments = [NSArray arrayWithObject:@"-codecs"];
	NSString *string;
	[MCCommonMethods launchNSTaskAtPath:[MCCommonMethods ffmpegPath] withArguments:arguments outputError:NO outputString:YES output:&string];
	NSArray *lines = [[[[[string componentsSeparatedByString:@"------\n"] objectAtIndex:1] componentsSeparatedByString:@"\n\nNote"] objectAtIndex:0] componentsSeparatedByString:@"\n"];

	NSInteger i;
	for (i = 0; i < [lines count]; i ++)
	{
		NSString *line = [lines objectAtIndex:i];
		NSString *format = [line substringWithRange:NSMakeRange(3, 1)];
		NSString *encoding = [line substringWithRange:NSMakeRange(2, 1)];
		
		NSString *internalFormat = [[line substringWithRange:NSMakeRange(8, 16)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		NSString *name = [line substringWithRange:NSMakeRange(24, [line length] - 24)];
		
		if ([format isEqualTo:@"A"] && [encoding isEqualTo:@"E"])
		{
			NSDictionary *codecDictionary = [NSDictionary dictionaryWithObjectsAndKeys:name, @"Name", internalFormat, @"Format", nil];
			[audioCodecs addObject:codecDictionary];
		}
	}
	
	return audioCodecs;
}

- (NSArray *)getVideoCodecs
{
	NSMutableArray *videoCodecs = [NSMutableArray array];

	NSArray *arguments = [NSArray arrayWithObject:@"-codecs"];
	NSString *string;
	[MCCommonMethods launchNSTaskAtPath:[MCCommonMethods ffmpegPath] withArguments:arguments outputError:NO outputString:YES output:&string];
	NSArray *lines = [[[[[string componentsSeparatedByString:@"------\n"] objectAtIndex:1] componentsSeparatedByString:@"\n\nNote"] objectAtIndex:0] componentsSeparatedByString:@"\n"];

	NSInteger i;
	for (i = 0; i < [lines count]; i ++)
	{
		NSString *line = [lines objectAtIndex:i];
		NSString *format = [line substringWithRange:NSMakeRange(3, 1)];
		NSString *encoding = [line substringWithRange:NSMakeRange(2, 1)];
		
		NSString *internalFormat = [[line substringWithRange:NSMakeRange(8, 16)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		NSString *name = [line substringWithRange:NSMakeRange(24, [line length] - 24)];
		
		if ([format isEqualTo:@"V"] && [encoding isEqualTo:@"E"])
		{
			NSDictionary *codecDictionary = [NSDictionary dictionaryWithObjectsAndKeys:name, @"Name", internalFormat, @"Format", nil];
			[videoCodecs addObject:codecDictionary];
		}
	}
	
	return videoCodecs;
}

- (NSArray *)getFormats
{
	NSMutableArray *formats = [NSMutableArray array];

	NSArray *arguments = [NSArray arrayWithObject:@"-formats"];
	NSString *string;
	[MCCommonMethods launchNSTaskAtPath:[MCCommonMethods ffmpegPath] withArguments:arguments outputError:NO outputString:YES output:&string];
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

	return formats;
}

- (void)extractImportantFontsToPath:(NSString *)path
{
	#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
	NSArray *fonts = [NSArray arrayWithObjects:@"/Library/Fonts/Hei.dfont", @"/Library/Fonts/Osaka.dfont", @"/Library/Fonts/HelveticaCY.dfont", nil];
	NSArray *copyFonts = [NSArray arrayWithObjects:@"HeiRegular.ttf", @"Osaka.ttf", @"HelveticaCYPlain.ttf", nil];
	NSArray *newCopyFontNames = [NSArray arrayWithObjects:@"Hei.ttf", @"Osaka.ttf", @"HelveticaCYPlain.ttf", nil];
	#else
	NSArray *fonts;
	NSArray *copyFonts;
	NSArray *newCopyFontNames;
	
	if ([MCCommonMethods OSVersion] < 0x1050)
	{
		fonts = [NSArray arrayWithObjects:@"/System/Library/Fonts/AppleGothic.dfont", @"/System/Library/Fonts/Hei.dfont", @"/System/Library/Fonts/Osaka.dfont", @"/Library/Fonts/HelveticaCY.dfont", nil];
		copyFonts = [NSArray arrayWithObjects:@"HeiRegular.ttf", @"Osaka.ttf", @"HelveticaCYPlain.ttf", nil];
		newCopyFontNames = [NSArray arrayWithObjects:@"Hei.ttf", @"Osaka.ttf", @"HelveticaCYPlain.ttf", nil];
	}
	else
	{
		fonts = [NSArray arrayWithObjects:@"/System/Library/Fonts/AppleGothic.dfont", @"/Library/Fonts/Hei.dfont", @"/Library/Fonts/Osaka.dfont", @"/Library/Fonts/HelveticaCY.dfont", nil];
		copyFonts = [NSArray arrayWithObjects:@"AppleGothicRegular.ttf", @"HeiRegular.ttf", @"Osaka.ttf", @"HelveticaCYPlain.ttf", nil];
		newCopyFontNames = [NSArray arrayWithObjects:@"AppleGothic.ttf", @"Hei.ttf", @"Osaka.ttf", @"HelveticaCYPlain.ttf", nil];
	}
	#endif
	
	
	
	NSString *tempFolder = [NSTemporaryDirectory() stringByAppendingPathComponent:@"MCTemp"];
	NSString *error;
	[MCCommonMethods createDirectoryAtPath:tempFolder errorString:&error];
	NSInteger i;
	for (i = 0; i < [fonts count]; i ++)
	{
		NSString *currentPath = [fonts objectAtIndex:i];
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:currentPath])
		{
			NSString *fontName = [copyFonts objectAtIndex:i];
			NSString *newFontName = [newCopyFontNames objectAtIndex:i];
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
	
	[MCCommonMethods removeItemAtPath:tempFolder];
}

@end