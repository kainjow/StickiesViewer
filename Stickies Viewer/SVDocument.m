//
//  Created by Kevin Wojniak on 2/3/12.
//  Copyright (c) 2013 Kevin Wojniak. All rights reserved.
//

#import "SVDocument.h"
#import "SVReader.h"

@implementation SVDocument

+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString* __unused)typeName { return YES; }

- (NSString *)windowNibName
{
    return @"SVDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController*)windowController
{
    [super windowControllerDidLoadNib:windowController];
    [arrayController addObserver:self forKeyPath:@"selection" options:0 context:nil];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString* __unused)typeName error:(NSError **)outError
{
    NSArray *notesTmp = [SVReader notesWithContentsOfURL:absoluteURL];
    if (notesTmp == nil) {
        *outError = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOENT userInfo:nil];
        return NO;
    }
    [self setValue:notesTmp forKey:@"notes"];
    return YES;
}

- (void)observeValueForKeyPath:(NSString * __unused)keyPath ofObject:(id __unused)object change:(NSDictionary* __unused)change context:(void* __unused)context
{
	NSArray *selectedObjs = [arrayController selectedObjects];
	if (selectedObjs != nil && [selectedObjs count] == 1) {
		[textView setBackgroundColor:((SVNote *)[selectedObjs lastObject]).color];
	} else {
		[textView setBackgroundColor:[NSColor whiteColor]];
    }
}

@end

@interface SVNoteTitleTransformer : NSValueTransformer

@end

@implementation SVNoteTitleTransformer

- (id)transformedValue:(id)value
{
    // generate a title based on the first line of the note
    SVNote *note = value;
    return [[[note.attributedString string] componentsSeparatedByString:@"\n"] objectAtIndex:0];
}

@end
