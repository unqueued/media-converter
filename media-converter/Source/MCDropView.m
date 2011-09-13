//
//  MCDropView.m
//  Media Converter
//
//  Created by Maarten Foukhar on 22-01-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCDropView.h"
#import "MCMainController.h"

@implementation MCDropView

- (id)initWithFrame:(NSRect)frameRect
{
	// register for file paths and strings (urls e.g. http:xxx)
	if ((self = [super initWithFrame:frameRect]) != nil)
		[self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, NSStringPboardType, nil]];
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    [self unregisterDraggedTypes];
    [super dealloc];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    if ((NSDragOperationGeneric & [sender draggingSourceOperationMask]) == NSDragOperationGeneric)
    {
        //this means that the sender is offering the type of operation we want
        //return that we want the NSDragOperationGeneric operation that they 
            //are offering
        return NSDragOperationGeneric;
    }
    else
    {
        //since they aren't offering the type of operation we want, we have 
            //to tell them we aren't interested
        return NSDragOperationNone;
    }
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    if ((NSDragOperationGeneric & [sender draggingSourceOperationMask]) == NSDragOperationGeneric)
    {
        //this means that the sender is offering the type of operation we want
        //return that we want the NSDragOperationGeneric operation that they 
            //are offering
        return NSDragOperationGeneric;
    }
    else
    {
        //since they aren't offering the type of operation we want, we have 
            //to tell them we aren't interested
        return NSDragOperationNone;
    }
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	// Check for attached sheet, can't drag and drop then
	if (![[self window] attachedSheet])
		return YES;
		
	return NO;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    NSPasteboard *paste = [sender draggingPasteboard];
        //gets the dragging-specific pasteboard from the sender
    NSArray *types = [NSArray arrayWithObjects:NSFilenamesPboardType, NSStringPboardType, nil];
        //a list of types that we can accept
    NSString *desiredType = [paste availableTypeFromArray:types];
    NSData *carriedData = [paste dataForType:desiredType];

    if (nil == carriedData)
    {
        //the operation failed for some reason
        return NO;
    }
    else
    {
        if ([desiredType isEqualToString:NSFilenamesPboardType]) // path
        {
            //we have a list of file names in an NSData object
            NSArray *fileArray = [paste propertyListForType:@"NSFilenamesPboardType"];
			[mainController checkFiles:fileArray];
        }
		else if ([desiredType isEqualToString:NSStringPboardType]) // url string
		{
			NSString *urlString = [paste stringForType:NSStringPboardType];
			[mainController checkFiles:[NSArray arrayWithObject:urlString]];
		}
        else
        {
            //this can't happen
            return NO;
        }
    }
	
    return YES;
}

@end
