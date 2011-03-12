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
				
				[self setErrorStringWithString:[NSString stringWithFormat:NSLocalizedString(@"%@ (Unknown error)", nil), displayName]];
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
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MCStatusChanged" object:[NSLocalizedString(@"Encoding: ", Localized) stringByAppendingString:[[NSFileManager defaultManager] displayNameAtPath:path]]];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	NSMutableArray *options = [NSMutableArray arrayWithArray:[convertOptions objectForKey:@"Encoder Options"]];
	NSDictionary *extraOptions = [convertOptions objectForKey:@"Extra Options"];
	
	// Encoder options for ffmpeg, movtoy4m
	NSString *outFileWithExtension = [MCCommonMethods uniquePathNameFromPath:[NSString stringWithFormat:@"%@/%@.%@", convertDestination, [[path lastPathComponent] stringByDeletingPathExtension], convertExtension]];
	NSString *outputFile = [outFileWithExtension stringByDeletingPathExtension];
	
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
	
	NSInteger taskStatus;
	NSMutableString *ffmpegErrorString;
	
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
			handle2=[pipe2 fileHandleForReading];
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
			[args addObject:outFileWithExtension];
		}
		else
		{
			[args addObject:outFileWithExtension];
		}

		[ffmpeg setArguments:args];
		//ffmpeg uses stderr to show the progress
		[ffmpeg setStandardError:pipe];
		handle = [pipe fileHandleForReading];
	
		ffmpegErrorString = [[NSMutableString alloc] initWithString:[MCCommonMethods logCommandIfNeeded:ffmpeg]];
		[ffmpeg launch];

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
		NSString *tempFile = [MCCommonMethods uniquePathNameFromPath:[NSString stringWithFormat:@"%@ (tmp).%@", extensionlessFile, extension]];
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
			ffmpegErrorString = @"Failed to set moov atom to the start of the file";
		}
		
		[qtfaststart release];
		qtfaststart = nil;
	}
	
	//Return if ffmpeg failed or not
	if (taskStatus == 0)
	{
		status = 0;
		encodedOutputFile = outFileWithExtension;
	
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
		
		if (*error != nil)
			*error = [NSString stringWithFormat:@"%@\n\n%@", *error, ffmpegErrorString];
		else
			*error = [NSString stringWithString:ffmpegErrorString];
			
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

	outputFile = [[MCCommonMethods uniquePathNameFromPath:[outputFile stringByAppendingPathExtension:convertExtension]] stringByDeletingPathExtension];
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
	NSString *tempFile = @"/tmp/tempkf";
	
	BOOL audioWorks = YES;
	BOOL videoWorks = YES;
	BOOL keepGoing = YES;
	
	NSArray *options = [convertOptions objectForKey:@"Encoder Options"];
	
	BOOL needsAudio = ([options objectForKey:@"-vn"] != nil);
	BOOL needsVideo = ([options objectForKey:@"-an"] != nil);

	while (keepGoing == YES)
	{
		NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-vframes", @"1", @"-i", path, nil];
		
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
			
			useWav = (code == 2 | code == 4 | code == 8);
			useQuickTime = (code == 2 | code == 3 | code == 6);
			
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
			//if ([file rangeOfString:@".iMovieProject"].length > 0)
			//{
				inputAspect = (CGFloat)16 / (CGFloat)9;
				inputWidth = 1024;
				inputHeight = 576;
			//}
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

@end