//
//  MCFilter.h
//  Media Converter
//
//  Created by Maarten Foukhar on 04-07-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NSNumber_Extensions.h"


@interface MCFilter : NSObject
{
	IBOutlet id filterView;

	NSArray *filterMappings;
	NSArray *filterDefaultValues;
	NSMutableDictionary *filterOptions;
}

- (void)setOptions:(NSDictionary *)options;
- (void)setupView;
- (void)resetView;

- (NSString *)name;
+ (NSString *)localizedName;
- (NSString *)identifyer;

- (NSView *)filterView;
- (NSArray *)filterMappings;
- (NSArray *)filterDefaultValues;
- (NSDictionary *)filterOptions;
- (NSImage *)imageWithSize:(NSSize)size;

- (IBAction)setFilterOption:(id)sender;

@end
