/* MCCommandController */

#import <Cocoa/Cocoa.h>
#import "MCCommonMethods.h"

@interface MCCommandController : NSObject
{
    IBOutlet id commandTableView;
    IBOutlet id myWindow;
    IBOutlet id popupButton;
    IBOutlet id searchField;
	IBOutlet id commandField;
	
	NSMutableArray *rows;
}
- (IBAction)cancelCommand:(id)sender;
- (IBAction)chooseCommand:(id)sender;
- (IBAction)popupChange:(id)sender;
- (IBAction)searchType:(id)sender;
- (IBAction)browseCommand:(id)sender;
- (void)reloadTable;
@end
