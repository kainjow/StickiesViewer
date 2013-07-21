//
//  Created by Kevin Wojniak on 2/3/12.
//  Copyright (c) 2013 Kevin Wojniak. All rights reserved.
//

#import "SVReader.h"

enum {
    Yellow = 0,
    Blue,
    Green,
    Pink,
    Purple,
    Gray,
};

static NSColor* RGB(NSUInteger r, NSUInteger g, NSUInteger b) {
    return [NSColor colorWithCalibratedRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1.0];
}

static NSColor* colorForInt(int colorValue)
{
    switch (colorValue) {
        case Yellow:  return RGB(254, 244, 156);
        case Blue:    return RGB(173, 244, 255);
        case Green:   return RGB(178, 255, 161);
        case Pink:    return RGB(255, 199, 199);
        case Purple:  return RGB(182, 202, 255);
        case Gray:    return RGB(238, 238, 238);
    }
    return nil;
}

struct _NSPoint {
    float x;
    float y;
};

struct _NSSize {
    float width;
    float height;
};

struct _NSRect {
    struct _NSPoint point;
    struct _NSSize size;
};

@interface Document : SVNote

@end

@implementation Document

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self != nil) {
		if (![coder allowsKeyedCoding]) {
			// decode RTFD data, convert to NSAttributedString
			NSData *rtfdData = [coder decodeObject];
			self.attributedString = [[NSAttributedString alloc] initWithRTFD:rtfdData documentAttributes:nil];
            
			// decode window flags. 1 for collapsed, 0 for normal. most likely holds translucent/floating states as well.
			int windowFlags;
			[coder decodeValueOfObjCType:@encode(int) at:&windowFlags];
			
            // decode window frame, which uses a fake NSRect/NSPoint/NSSize. The name of this struct
            // *must* match what's in the archive. Some versions of the archive use anonymous structs.
            struct _NSRect windowFrame;
            [coder decodeValueOfObjCType:@encode(struct _NSRect) at:&windowFrame];
            
			// decode window color, convert to a usable NSColor object
			int windowColor;
			[coder decodeValueOfObjCType:@encode(int) at:&windowColor];
			self.color = colorForInt(windowColor);
			
			// decode creation and modification dates
			self.dateCreated = [coder decodeObject];
			self.dateModified = [coder decodeObject];
		}
	}
	
	return self;
}

@end

enum { // styles from MacTypes.h
    kSVnormal    = 0,
    kSVbold      = 1,
    kSVitalic    = 2,
    kSVunderline = 4,
    kSVoutline   = 8,
    kSVshadow    = 0x10,
    kSVcondense  = 0x20,
    kSVextend    = 0x40
};

@implementation SVReader

+ (NSArray *)classicNotesAtURL:(NSURL *)url
{
    NSMutableArray *notes = nil;
    FILE *file = NULL;
    
    file = fopen([[url path] fileSystemRepresentation], "r");
    if (file == NULL) {
        goto errout;
    }
    
    // Read header (always 0x00030003?)
    uint32_t header;
    if (fread(&header, 1, sizeof(header), file) != sizeof(header)) {
        goto errout;
    }
    header = CFSwapInt32BigToHost(header);
    if (header != 0x00030003U) {
        goto errout;
    }
    
    // Read number of notes
    uint16_t count;
    if (fread(&count, 1, sizeof(count), file) != sizeof(count)) {
        goto errout;
    }
    count = CFSwapInt16BigToHost(count);
    
    notes = [NSMutableArray array];
    for (uint16_t i = 0; i < count; ++i) {
        // Read window rects (Rect from MacTypes.h)
        struct SVRect {
            uint16_t top;
            uint16_t left;
            uint16_t bottom;
            uint16_t right;
        };
        struct SVRect rect1;
        if (sizeof(rect1) != 8 || fread(&rect1, 1, sizeof(rect1), file) != sizeof(rect1)) {
            notes = nil;
            break;
        }
        // Read second window rect
        struct SVRect rect2;
        if (sizeof(rect2) != 8 || fread(&rect2, 1, sizeof(rect2), file) != sizeof(rect2)) {
            notes = nil;
            break;
        }
        // Read the date created and modified (seconds since Jan 1, 1904);
        uint32_t date1;
        uint32_t date2;
        if (fread(&date1, 1, sizeof(date1), file) != sizeof(date1)) {
            notes = nil;
            break;
        }
        if (fread(&date2, 1, sizeof(date2), file) != sizeof(date2)) {
            notes = nil;
            break;
        }
        date1 = CFSwapInt32BigToHost(date1);
        date2 = CFSwapInt32BigToHost(date2);
        CFAbsoluteTime timeCreated;
        CFAbsoluteTime timeModified;
        if (UCConvertSecondsToCFAbsoluteTime(date1, &timeCreated) != noErr || UCConvertSecondsToCFAbsoluteTime(date2, &timeModified) != noErr) {
            notes = nil;
            break;
        }
        // Skip 2 bytes (font?)
        if (fseek(file, 2L, SEEK_CUR) != 0) {
            notes = nil;
            break;
        }
        // Read font size
        uint8_t fontSize;
        if (fread(&fontSize, 1, sizeof(fontSize), file) != sizeof(fontSize)) {
            notes = nil;
            break;
        }
        // Read the font style
        uint8_t fontStyle;
        if (fread(&fontStyle, 1, sizeof(fontStyle), file) != sizeof(fontStyle)) {
            notes = nil;
            break;
        }
        // Skip 1 byte
        if (fseek(file, 1L, SEEK_CUR) != 0) {
            notes = nil;
            break;
        }
        // Read the color
        uint8_t colorValue;
        if (fread(&colorValue, 1, sizeof(colorValue), file) != sizeof(colorValue)) {
            notes = nil;
            break;
        }
        // Read text
        uint16_t textLen;
        if (fread(&textLen, 1, sizeof(textLen), file) != sizeof(textLen)) {
            notes = nil;
            break;
        }
        textLen = CFSwapInt16BigToHost(textLen);
        char *buf = calloc(textLen + 1, sizeof(char));
        if (buf == NULL) {
            notes = nil;
            break;
        }
        if (fread(buf, 1, textLen, file) != textLen) {
            notes = nil;
            free(buf);
            break;
        }
        NSString *text = [[NSString alloc] initWithCString:buf encoding:NSMacOSRomanStringEncoding];
        free(buf);
        SVNote *note = [[SVNote alloc] init];
        NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                               [NSFont systemFontOfSize:fontSize], NSFontAttributeName,
                               nil];
        note.attributedString = [[NSAttributedString alloc] initWithString:text attributes:attrs];
        note.dateCreated = [NSDate dateWithTimeIntervalSinceReferenceDate:timeCreated];
        note.dateModified = [NSDate dateWithTimeIntervalSinceReferenceDate:timeModified];
        note.color = colorForInt(colorValue);
        [notes addObject:note];
    }
    
errout:
    if (file != NULL) {
        (void)fclose(file);
    }
    
    return notes;
}

+ (NSArray *)notesWithContentsOfURL:(NSURL *)url
{
    NSArray *notes = nil;
    
    @try {
        NSData *data = [NSData dataWithContentsOfURL:url];
        NSUnarchiver *unarchiver = [[NSUnarchiver alloc] initForReadingWithData:data];
        notes = [unarchiver decodeObject];
    } @catch (NSException *exception) {
        notes = nil;
    }

    if (notes == nil) {
        notes = [[self class] classicNotesAtURL:url];
    }
    
    return notes;
}

@end

@implementation SVNote

@end

