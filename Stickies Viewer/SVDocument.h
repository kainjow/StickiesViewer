//
//  Created by Kevin Wojniak on 2/3/12.
//  Copyright (c) 2013 Kevin Wojniak. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SVDocument : NSDocument
{
    IBOutlet NSArrayController *arrayController;
    IBOutlet NSTextView *textView;
    NSArray *notes;
}

@end
