//
//  MCOptionsTableView.m
//  Media Converter
//
//  Created by Maarten Foukhar on 08-03-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "MCOptionsTableView.h"
#import "MCOptionsDelegate.h"
#import "NSNumber_Extensions.h"


@implementation MCOptionsTableView

-(void)textDidEndEditing:(NSNotification *)notification
{
	NSDictionary *userInfo = [notification userInfo];
	NSInteger textMovement = [[userInfo valueForKey:@"NSTextMovement"] integerValue];
	NSInteger editedColumn = [self editedColumn];

	if (textMovement == NSTabTextMovement)
	{
		// Tab pressed!
		[super textDidEndEditing:notification];
		
		if (editedColumn == 1)
			[(MCOptionsDelegate *)[self delegate] addOption:nil];
	}
}

@end
