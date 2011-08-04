//
//  MCTableView.m
//  Media Converter
//
//  Created by Maarten Foukhar on 05-03-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCTableView.h"
#import "MCPreferences.h"


@implementation MCTableView

- (id)initWithCoder:(NSCoder *)decoder
{
	[super initWithCoder:decoder];

	notificationName = nil;
	
	return self;
}

- (BOOL)becomeFirstResponder 
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MCListSelected" object:self];

	return [super becomeFirstResponder];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    SEL aSelector = [invocation selector];
	id delegate = [self delegate];
 
    if ([delegate respondsToSelector:aSelector])
        [invocation invokeWithTarget:delegate];
    else
        [self doesNotRecognizeSelector:aSelector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	if ([super respondsToSelector:aSelector])
		return [super methodSignatureForSelector:aSelector];
	else
		return [[self delegate] methodSignatureForSelector:aSelector];
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
	if (([self selectedRow] == -1 | [self numberOfSelectedRows] > 1) && (aSelector == @selector(edit:) | (aSelector == @selector(saveDocumentAs:))))
		return NO;
		
	if (([self selectedRow] == -1) && (aSelector == @selector(duplicate:) | aSelector == @selector(delete:)))
		return NO;
	
	return ([super respondsToSelector:aSelector] | [[self delegate] respondsToSelector:aSelector]);
}

- (void)setReloadNotificationName:(NSString *)name
{
	notificationName = name;
}

- (void)reloadData
{
	[super reloadData];
	
	if (notificationName != nil)
		[[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:nil];
}

@end
