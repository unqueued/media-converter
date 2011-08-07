//
//  MCImageView.m
//  Media Converter
//
//  Created by Maarten Foukhar on 07-08-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCImageView.h"
#import "MCCommonMethods.h"
#import "MCWatermarkFilter.h"


@implementation MCImageView

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    if ((NSDragOperationGeneric & [sender draggingSourceOperationMask]) == NSDragOperationGeneric)
        return NSDragOperationGeneric;
    else
        return NSDragOperationNone;
}



- (void)draggingExited:(id <NSDraggingInfo>)sender
{
}


- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = [sender draggingPasteboard];
	
    if ( [[pboard types] containsObject:NSFilenamesPboardType] )
	{
		//  NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        //NSLog(@"%@", files);
        // Perform operation using the list of files
    }
	
	
    NSPasteboard *paste = [sender draggingPasteboard];
    NSArray *types = [NSArray arrayWithObjects:NSTIFFPboardType, NSFilenamesPboardType, nil];
    NSString *desiredType = [paste availableTypeFromArray:types];
    NSData *carriedData = [paste dataForType:desiredType];
	
    if (nil == carriedData)
    {
        return NO;
    }
    else
    {
        if ([desiredType isEqualToString:NSTIFFPboardType])
        {
			NSImage *newImage = [[NSImage alloc] initWithData:carriedData];
			[delegate setImage:newImage withIdentifyer:NSLocalizedString(@"Clipboard Image", nil)];
			[newImage release];    
        }
        else if ([desiredType isEqualToString:NSFilenamesPboardType])
        {
            NSArray *fileArray = [paste propertyListForType:@"NSFilenamesPboardType"];

            NSString *path = [fileArray objectAtIndex:0];
			NSString *identifyer = [[MCCommonMethods defaultManager] displayNameAtPath:path];
            NSImage *newImage = [[NSImage alloc] initWithContentsOfFile:path];
			
            if (nil == newImage)
                return NO;
            else
				[delegate setImage:newImage withIdentifyer:identifyer];
				
            [newImage release];
        }
    }
	
    return YES;
}

@end
