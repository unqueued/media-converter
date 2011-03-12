//
//  MCConverter.h
//  Media Converter
//
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MCCommonMethods.h"

@interface MCConverter : NSObject
{
	//ffmpeg the main encoder
	NSTask *ffmpeg;
	//movtoy4m, passes the decoded quicktime movie to FFmpeg
	NSTask *movtoy4m;
	//movtowav, encodes the movie to wav, after that FFmpeg can encode it
	NSTask *movtowav;
	//qt-faststart, place moov atom at start of movie
	NSTask *qtfaststart;
	//Status: 0=idle, 1=encoding audio, 2=encoding video
	NSInteger status;
	//Number of file encoding
	NSInteger number;
	//aspect ratio for current movie
	NSInteger aspectValue;
	//Last encoded file
	NSString *encodedOutputFile;
	//Needed for the one who speaks to the class
	NSMutableArray *convertedFiles;
	//To differ if it must be reported to be a problem (when canceling)
	BOOL userCanceled;
	
	//Input file values
	NSInteger inputWidth;
	NSInteger inputHeight;
	CGFloat inputFps;
	NSInteger inputTotalTime;
	CGFloat inputAspect;
	//inputFormat: 0 = normal; 1 = dv; 2 = mpeg2
	NSInteger inputFormat;

	NSDictionary *convertOptions;
	NSString *errorString;
	NSString *convertDestination;
	NSString *convertExtension;
	
	BOOL useWav;
	BOOL useQuickTime;
	BOOL copyAudio;
}

//Encode actions

//Convert a bunch of files with ffmpeg/movtoyuv/QuickTime
- (NSInteger)batchConvert:(NSArray *)files toDestination:(NSString *)destination withOptions:(NSDictionary *)options errorString:(NSString **)error;
//Encode the file, use wav file if quicktime created it, use pipe (from movtoy4m)
- (NSInteger)encodeFileAtPath:(NSString *)path errorString:(NSString **)error;
//Encode sound to wav
- (NSInteger)encodeAudioAtPath:(NSString *)path errorString:(NSString **)error;
//Stop encoding (stop ffmpeg, movtowav and movtoy4m if they're running
- (void)cancelEncoding;

//Test actions

//Test if FFmpeg can encode, sound and/or video, and if it does have any sound
- (NSInteger)testFile:(NSString *)path errorString:(NSString **)error;
//Test methods used in (NSInteger)testFile....
- (BOOL)streamWorksOfKind:(NSString *)kind inOutput:(NSString *)output;
- (BOOL)isReferenceMovie:(NSString *)output;
- (BOOL)setTimeAndAspectFromOutputString:(NSString *)output fromFile:(NSString *)file;

//Compilant actions
//Generic command to get info on the input file
- (NSString *)ffmpegOutputForPath:(NSString *)path;
//Check if the file is a valid media file (return YES if it is valid)
- (BOOL)isMediaFile:(NSString *)path;
//Check for ac3 audio
- (BOOL)containsAC3:(NSString *)path;

//Framework actions
- (NSArray *)succesArray;

//Other actions
- (NSInteger)convertToEven:(NSString *)number;
- (NSInteger)getPadSize:(CGFloat)size withAspect:(NSSize)aspect withTopBars:(BOOL)topBars;
- (NSInteger)totalTimeInSeconds:(NSString *)path;
- (NSString *)mediaTimeString:(NSString *)path;
- (void)setErrorStringWithString:(NSString *)string;

- (NSArray *)getFormats;
- (NSArray *)getVideoCodecs;
- (NSArray *)getAudioCodecs;

@end