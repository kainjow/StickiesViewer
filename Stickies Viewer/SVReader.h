//
//  Created by Kevin Wojniak on 2/3/12.
//  Copyright (c) 2013 Kevin Wojniak. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SVReader : NSObject

+ (NSArray *)notesWithContentsOfURL:(NSURL *)url;

@end

@interface SVNote : NSObject

@property (strong) NSAttributedString *attributedString;
@property (strong) NSDate *dateCreated;
@property (strong) NSDate *dateModified;
@property (strong) NSColor *color;

@end
