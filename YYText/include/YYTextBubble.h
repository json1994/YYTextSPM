//
//  YYTextBubble.h
//  YYText
//
//  Bubble that wraps a range of text. Unlike `YYTextBackgroundBorder`, the
//  bubble participates in layout: it pushes text before/after horizontally and
//  pushes the lines above/below vertically (via run-delegate spacers inserted
//  at the start/end of the bubbled range).
//
//  When the bubbled text wraps across several lines and consecutive lines have
//  any horizontal overlap, those lines are visually fused into a single shape
//  (the inter-line spacing is wrapped inside the bubble). Lines without
//  horizontal overlap are drawn as separate bubbles.
//
//  Only horizontal text layout is supported.
//

#import <UIKit/UIKit.h>

#if __has_include(<YYText/YYText.h>)
#import <YYText/YYTextAttribute.h>
#else
#import "YYTextAttribute.h"
#endif

NS_ASSUME_NONNULL_BEGIN

/// Attribute name. Value is a `YYTextBubble` object.
UIKIT_EXTERN NSString *const YYTextBubbleAttributeName;


/**
 A bubble appearance descriptor. Two ranges share the same visual bubble only
 when they share the *same* `YYTextBubble` instance (compared via `isEqual:`,
 which by default falls back to pointer equality). The `NSMutableAttributedString
 (YYTextBubble)` category creates a fresh copy for every range/regex match so
 unrelated matches never accidentally fuse.
 */
@interface YYTextBubble : NSObject <NSCoding, NSCopying>

/// Fill color of the bubble. nil means no fill.
@property (nullable, nonatomic, strong) UIColor *fillColor;

/// Stroke (border) color. nil means no stroke.
@property (nullable, nonatomic, strong) UIColor *strokeColor;

/// Stroke (border) width. Default is 0.
@property (nonatomic) CGFloat strokeWidth;

/// Corner radius of the bubble. Default is 0.
@property (nonatomic) CGFloat cornerRadius;

/// Distance from the wrapped text to the bubble's edge, on each side.
/// `padding.left/right` push surrounding text horizontally.
/// `padding.top` extends the first bubble line upward (pushing the previous
/// line up). `padding.bottom` extends the last bubble line downward.
@property (nonatomic) UIEdgeInsets padding;

/// Optional drop shadow drawn beneath the bubble.
@property (nullable, nonatomic, strong) YYTextShadow *shadow;

/// Convenience constructor.
+ (instancetype)bubbleWithFillColor:(nullable UIColor *)fillColor
                       cornerRadius:(CGFloat)cornerRadius
                            padding:(UIEdgeInsets)padding;

@end


/**
 Helpers for applying a `YYTextBubble` to an attributed string. Each call
 inserts two invisible spacer characters (one before, one after the range) so
 that the bubble's padding actually shifts surrounding glyphs during CoreText
 layout.

 The original `range` you pass in refers to positions in the *current* string;
 after the call the string has grown by 2 characters per applied bubble.
 */
@interface NSMutableAttributedString (YYTextBubble)

/**
 Apply a bubble to `range`. Inserts a spacer at `range.location` and another at
 `NSMaxRange(range)` to provide horizontal/vertical padding via CoreText layout.

 @return The new range (including both spacers) in the *updated* string. Returns
         `{NSNotFound, 0}` when arguments are invalid.
 */
- (NSRange)yy_setBubble:(YYTextBubble *)bubble range:(NSRange)range;

/**
 Apply a bubble to every match of `regex`. Each match receives an independent
 copy of the bubble so adjacent matches don't visually fuse together.

 @return Ranges (in the updated string) of every applied bubble, in document
         order, including the spacer characters. Empty matches are skipped.
 */
- (NSArray<NSValue *> *)yy_setBubble:(YYTextBubble *)bubble withRegex:(NSRegularExpression *)regex;

/**
 Convenience overload that compiles `pattern` with `options`.
 */
- (NSArray<NSValue *> *)yy_setBubble:(YYTextBubble *)bubble
                         withPattern:(NSString *)pattern
                             options:(NSRegularExpressionOptions)options;

@end

NS_ASSUME_NONNULL_END
