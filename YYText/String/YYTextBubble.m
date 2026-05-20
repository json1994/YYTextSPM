//
//  YYTextBubble.m
//  YYText
//

#import "YYTextBubble.h"
#import "YYTextRunDelegate.h"
#import "NSAttributedString+YYText.h"

NSString *const YYTextBubbleAttributeName = @"YYTextBubble";

/// Object replacement character — same token used by attachments. CoreText
/// will create one CTRun for it; combined with a clear foreground color and a
/// width-overriding CTRunDelegate, it becomes an invisible "spacer" glyph.
static NSString *const YYTextBubbleSpacerToken = @"\uFFFC";


#pragma mark - YYTextBubble

@implementation YYTextBubble

+ (instancetype)bubbleWithFillColor:(UIColor *)fillColor
                       cornerRadius:(CGFloat)cornerRadius
                            padding:(UIEdgeInsets)padding {
    YYTextBubble *b = [self new];
    b.fillColor = fillColor;
    b.cornerRadius = cornerRadius;
    b.padding = padding;
    return b;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _padding = UIEdgeInsetsZero;
        _cornerRadius = 0;
        _strokeWidth = 0;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    YYTextBubble *b = [[self.class allocWithZone:zone] init];
    b->_fillColor = _fillColor;
    b->_strokeColor = _strokeColor;
    b->_strokeWidth = _strokeWidth;
    b->_cornerRadius = _cornerRadius;
    b->_padding = _padding;
    b->_shadow = _shadow;
    return b;
}

- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:_fillColor forKey:@"fc"];
    [c encodeObject:_strokeColor forKey:@"sc"];
    [c encodeDouble:(double)_strokeWidth forKey:@"sw"];
    [c encodeDouble:(double)_cornerRadius forKey:@"cr"];
    [c encodeUIEdgeInsets:_padding forKey:@"pd"];
    [c encodeObject:_shadow forKey:@"sh"];
}

- (instancetype)initWithCoder:(NSCoder *)c {
    self = [self init];
    if (!self) return nil;
    _fillColor    = [c decodeObjectForKey:@"fc"];
    _strokeColor  = [c decodeObjectForKey:@"sc"];
    _strokeWidth  = (CGFloat)[c decodeDoubleForKey:@"sw"];
    _cornerRadius = (CGFloat)[c decodeDoubleForKey:@"cr"];
    _padding      = [c decodeUIEdgeInsetsForKey:@"pd"];
    _shadow       = [c decodeObjectForKey:@"sh"];
    return self;
}

@end


#pragma mark - NSMutableAttributedString helpers

@implementation NSMutableAttributedString (YYTextBubble)

/// Build an invisible spacer attributed string carrying a CTRunDelegate so that
/// CoreText reserves `width × (ascent+descent)` for its single glyph. The
/// glyph itself is rendered with `clearColor`, so nothing visible is drawn.
- (NSAttributedString *)_yy_bubbleSpacerWithBubble:(YYTextBubble *)bubble
                                              font:(UIFont *)font
                                             width:(CGFloat)width
                                            ascent:(CGFloat)ascent
                                           descent:(CGFloat)descent {
    NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:YYTextBubbleSpacerToken];
    NSRange r = NSMakeRange(0, s.length);

    YYTextRunDelegate *del = [YYTextRunDelegate new];
    del.width   = MAX(0, width);
    del.ascent  = MAX(0, ascent);
    del.descent = MAX(0, descent);
    CTRunDelegateRef ref = del.CTRunDelegate;
    if (ref) {
        [s yy_setRunDelegate:ref range:r];
        CFRelease(ref);
    }

    if (font) [s yy_setFont:font range:r];
    [s yy_setColor:[UIColor clearColor] range:r];
    [s addAttribute:YYTextBubbleAttributeName value:bubble range:r];
    return s;
}

- (NSRange)yy_setBubble:(YYTextBubble *)bubble range:(NSRange)range {
    if (!bubble) return NSMakeRange(NSNotFound, 0);
    if (range.length == 0) return NSMakeRange(NSNotFound, 0);
    if (range.location == NSNotFound || NSMaxRange(range) > self.length) {
        return NSMakeRange(NSNotFound, 0);
    }

    UIFont *font = [self attribute:NSFontAttributeName atIndex:range.location effectiveRange:NULL];
    if (![font isKindOfClass:[UIFont class]]) {
        font = [UIFont systemFontOfSize:17];
    }

    CGFloat fontAscent  = font.ascender;          // > 0
    CGFloat fontDescent = -font.descender;        // descender is negative → make positive

    CGFloat padTop    = MAX(0, bubble.padding.top);
    CGFloat padBottom = MAX(0, bubble.padding.bottom);
    CGFloat padLeft   = MAX(0, bubble.padding.left);
    CGFloat padRight  = MAX(0, bubble.padding.right);

    NSAttributedString *leading = [self _yy_bubbleSpacerWithBubble:bubble
                                                              font:font
                                                             width:padLeft
                                                            ascent:fontAscent + padTop
                                                           descent:fontDescent];

    NSAttributedString *trailing = [self _yy_bubbleSpacerWithBubble:bubble
                                                               font:font
                                                              width:padRight
                                                             ascent:fontAscent
                                                            descent:fontDescent + padBottom];

    // Tag the existing characters first so the run scan picks up a contiguous
    // bubble span, then splice in the spacers (trailing first to keep
    // `range.location` valid for the leading insertion).
    [self addAttribute:YYTextBubbleAttributeName value:bubble range:range];
    [self insertAttributedString:trailing atIndex:NSMaxRange(range)];
    [self insertAttributedString:leading atIndex:range.location];

    return NSMakeRange(range.location, range.length + leading.length + trailing.length);
}

- (NSArray<NSValue *> *)yy_setBubble:(YYTextBubble *)bubble withRegex:(NSRegularExpression *)regex {
    if (!bubble || !regex || self.length == 0) return @[];

    NSArray<NSTextCheckingResult *> *matches =
        [regex matchesInString:self.string options:0 range:NSMakeRange(0, self.length)];

    // Walk left-to-right tracking the cumulative offset introduced by each
    // applied bubble so each match's original range maps to the correct slot
    // in the (now grown) string.
    NSMutableArray<NSValue *> *applied = [NSMutableArray new];
    NSInteger offset = 0;
    for (NSTextCheckingResult *m in matches) {
        NSRange r = m.range;
        if (r.location == NSNotFound || r.length == 0) continue;
        r.location += offset;
        NSRange newRange = [self yy_setBubble:[bubble copy] range:r];
        if (newRange.location == NSNotFound) continue;
        offset += (NSInteger)newRange.length - (NSInteger)r.length;
        [applied addObject:[NSValue valueWithRange:newRange]];
    }
    return applied;
}

- (NSArray<NSValue *> *)yy_setBubble:(YYTextBubble *)bubble
                         withPattern:(NSString *)pattern
                             options:(NSRegularExpressionOptions)options {
    if (!pattern) return @[];
    NSError *err = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:options
                                                                             error:&err];
    if (!regex) return @[];
    return [self yy_setBubble:bubble withRegex:regex];
}

@end
