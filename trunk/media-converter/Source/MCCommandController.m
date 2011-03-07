#import "MCCommandController.h"

@implementation MCCommandController

- (IBAction)cancelCommand:(id)sender
{
	[myWindow makeFirstResponder:searchField];
	
	[NSApp abortModal];
}

- (IBAction)chooseCommand:(id)sender
{
	if ([commandTableView selectedRow] > -1)
	{
		NSString *path = [[rows objectAtIndex:[commandTableView selectedRow]] objectForKey:@"Path"];
		[commandField setStringValue:path];
		[[NSUserDefaults standardUserDefaults] setObject:path forKey:@"MCCustomFFMPEG"];
		[myWindow makeFirstResponder:searchField];
		
		[NSApp abortModal];
	}
}

- (IBAction)browseCommand:(id)sender
{
	[NSApp abortModal];

	NSOpenPanel *oPanel = [NSOpenPanel openPanel];
	NSInteger result;
	result = [oPanel runModalForDirectory:nil file:nil types:nil];

	//User clicked OK in the open dialog
	if (result == NSOKButton)
	{
		NSString *path = [oPanel filename];
		[commandField setStringValue:path];
		[[NSUserDefaults standardUserDefaults] setObject:path forKey:@"MCCustomFFMPEG"];
	}
}

- (IBAction)popupChange:(id)sender
{
	[self reloadTable];
}

- (IBAction)searchType:(id)sender
{
	[self reloadTable];
}

- (void)reloadTable
{
	NSArray *paths = nil;
	if ([[popupButton title] isEqualTo:@"All"])
		paths = [NSArray arrayWithObjects:@"/bin/", @"/usr/bin/", @"/usr/local/bin/", @"/sw/bin/", @"/opt/bin", nil];
	else 
		paths = [NSArray arrayWithObjects:[popupButton title], nil];

	NSInteger x;
	[rows removeAllObjects];

	for(x = 0; x < [paths count]; x ++)
	{
		NSArray *itemsInPathToOpen = [[NSFileManager defaultManager] directoryContentsAtPath:[paths objectAtIndex:x]];
		NSInteger i;
		NSInteger pathcount;
		pathcount = [itemsInPathToOpen count];

		for(i = 0; i < pathcount; i++)
		{
			NSString *item = [itemsInPathToOpen objectAtIndex:i];
	
			if ([item rangeOfString:[searchField stringValue]].length > 0 | [[searchField stringValue] isEqualTo:@""])
			{
				NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
				[rowData setObject:[[item lastPathComponent] stringByDeletingPathExtension] forKey:@"Command"];
				[rowData setObject:[[paths objectAtIndex:x] stringByAppendingPathComponent:[item lastPathComponent]] forKey:@"Path"];
				[rows addObject:rowData];
			}
		}

		[commandTableView reloadData];
	}
}

- (id)init
{
	if (self = [super init])
		rows = [[NSMutableArray alloc] init];

	return self;
}

- (void)dealloc
{
	[rows release];
	rows = nil;
	
	[super dealloc];
}

//When we wake, init array, setup tableview
- (void)awakeFromNib
{	
	//Double clicking a row equals Clicking OK
	[commandTableView setDoubleAction:@selector(chooseCommand:)];
	//Needs to be set in Tiger (Took me a while to figure out since it worked since Jaguar without target)
	[commandTableView setTarget:self];
	
	[myWindow makeFirstResponder:searchField];
	
	[self reloadTable];
}

//Count the number of rows, not really needed anywhere
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [rows count];
}

//return selected row
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSDictionary *rowData = [rows objectAtIndex:row];
    return [rowData objectForKey:[tableColumn identifier]];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSMutableDictionary *rowData = [rows objectAtIndex:row];
    [rowData setObject:anObject forKey:[tableColumn identifier]];
}

//We don't want to make people change our row values
- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	return NO;
}

@end
