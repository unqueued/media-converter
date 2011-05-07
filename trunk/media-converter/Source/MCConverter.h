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
	//Some old ISO 639 codes used in mkv files as language
	NSDictionary *oldToNewLanguageCodes;
	
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
	NSString *detailedErrorString;
	NSString *convertDestination;
	NSString *convertExtension;
	NSString *temporaryFolder;
	NSFileHandle *currentFileHandle;
	
	//Encodings
	NSArray *cyrillicLanguages;
	
	BOOL useWav;
	BOOL useQuickTime;
	BOOL copyAudio;
	
	BOOL subtitleProblem;
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

/*Results:
1 = video / audio
2 = video / audio (movtoy4m && movtowav)
3 = video / audio (movtoy4m)
4 = video / audio (movtowav)
5 = no audio / video
6 = no audio / video (movtoy4m)
7 = no video / audio
8 = no video / audio (movtowav)*/

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
//Get the first audio and video streams (used for mp4 subs)
- (NSDictionary *)firstAudioAndVideoStreamAtPath:(NSString *)path;

//Framework actions
- (NSArray *)succesArray;

//Subtitle actions
//outputType: 0 = mp4, 1 = mkv, 2 = ogg (kate)
- (BOOL)createMovieWithSubtitlesAtPath:(NSString *)path inputFile:(NSString *)inFile ouputType:(NSString *)type;
- (BOOL)extractSubtitlesFromMovieAtPath:(NSString *)inPath toPath:(NSString *)outPath;
- (NSArray *)trackDictionariesFromPath:(NSString *)path withType:(NSString *)type;

//MP4 Subtitle methods
- (BOOL)addSubtitleToMP4Movie:(NSString *)subPath outPath:(NSString *)moviePath forLanguage:(NSString *)lang firstSubtitle:(BOOL)first;
- (BOOL)convertSubtitleFromMP4Movie:(NSString *)inPath toSubtitle:(NSString *)outPath outType:(NSString *)type fromID:(NSString *)streamID;
- (BOOL)extractSubtitlesFromMP4Movie:(NSString *)inPath ofType:(NSString *)type toPath:(NSString *)outPath;
- (BOOL)addTracksFromMP4Movie:(NSString *)inPath toPath:(NSString *)outPath;
- (NSArray *)trackDictionariesFromMP4MovieAtPath:(NSString *)path;

//MKV Subtitle methods
- (BOOL)addSubtitlesToMKVMovie:(NSArray *)subtitles outPath:(NSString *)moviePath forLanguages:(NSArray *)languages;
- (BOOL)extractSubtitlesFromMKVMovie:(NSString *)inPath ofType:(NSString *)type toPath:(NSString *)outPath;
- (BOOL)addTracksFromMKVMovie:(NSArray *)inPaths toPath:(NSString *)outPath;
- (NSArray *)trackDictionariesFromMKVMovieAtPath:(NSString *)path;

//OGG (Kate) Subtitle methods
- (BOOL)addSubtitlesToOGGMovie:(NSArray *)subtitles outPath:(NSString *)moviePath forLanguages:(NSArray *)languages;
- (BOOL)addTracksFromOGGMovies:(NSArray *)inPaths toPath:(NSString *)outPath;
- (BOOL)convertSRT:(NSString *)inPath toKateOGG:(NSString *)outPath forLanguage:(NSString *)language;
- (BOOL)extractSubtitlesFromOGGMovie:(NSString *)inPath ofType:(NSString *)type toPath:(NSString *)outPath;
- (NSArray *)trackDictionariesFromOGGMovieAtPath:(NSString *)path;

//DVD Subtitle methods
- (BOOL)addDVDSubtitlesToOutputStreamFromTask:(NSTask *)task withSubtitles:(NSArray *)subtitles toPath:(NSString *)outPath;
- (BOOL)testFontWithName:(NSString *)name;

//Other actions
- (NSInteger)convertToEven:(NSString *)number;
- (NSInteger)getPadSize:(CGFloat)size withAspect:(NSSize)aspect withTopBars:(BOOL)topBars;
- (NSInteger)totalTimeInSeconds:(NSString *)path;
- (NSString *)mediaTimeString:(NSString *)path;
- (void)setErrorStringWithString:(NSString *)string;

- (NSArray *)getFormats;
- (NSArray *)getVideoCodecs;
- (NSArray *)getAudioCodecs;
- (void)extractImportantFontsToPath:(NSString *)path statusStart:(NSInteger)start;
- (void)downloadYouTubeURL:(NSString *)urlString toTask:(NSTask *)inTask outPipe:(NSPipe **)pipe;
- (NSString *)getYouTubeName:(NSString *)urlString;

@end