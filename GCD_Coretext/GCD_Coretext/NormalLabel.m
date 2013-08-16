//
//  NormalLabel.m
//  GCD_Coretext
//
//  Created by Johnil on 13-8-16.
//  Copyright (c) 2013年 Johnil. All rights reserved.
//

#import "NormalLabel.h"

CTTextAlignment NormalCTTextAlignmentFromUITextAlignment(NSTextAlignment alignment) {
	switch (alignment) {
		case NSTextAlignmentLeft: return kCTLeftTextAlignment;
		case NSTextAlignmentCenter: return kCTCenterTextAlignment;
		case NSTextAlignmentRight: return kCTRightTextAlignment;
		default: return kCTNaturalTextAlignment;
	}
}

@implementation NormalLabel {
	CTFrameRef ctframe;
    NSRange currentRange;
	NSMutableDictionary *highlightColor;
	NSMutableArray *rangeArr;

	CFArrayRef lines;
	CGPoint* lineOrigins;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        rangeArr = [[NSMutableArray alloc] init];
        highlightColor = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                          COLOR_URL,kRegexHighlightViewTypeAccount,
                          COLOR_URL,kRegexHighlightViewTypeURL,
                          COLOR_URL,kRegexHighlightViewTypeTopic,nil];
		self.userInteractionEnabled = YES;
    }
    return self;
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect{
	if(self.text.length<=0) {
        self.text = @"";
        return;
    }
	NSLog(@"draw", nil);
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetTextMatrix(context,CGAffineTransformIdentity);
	CGContextTranslateCTM(context,0,([self bounds]).size.height);
	CGContextScaleCTM(context,1.0,-1.0);

	CGSize size = self.frame.size;

	UIColor* textColor = self.textColor;

	CGFloat minimumLineHeight = self.font.pointSize,maximumLineHeight = minimumLineHeight+10, linespace = self.lineSpace;
	CTFontRef font = CTFontCreateWithName((__bridge CFStringRef)self.font.fontName, self.font.pointSize,NULL);
	CTLineBreakMode lineBreakMode = kCTLineBreakByWordWrapping;
	CTTextAlignment alignment = NormalCTTextAlignmentFromUITextAlignment(self.textAlignment);
	CTParagraphStyleRef style = CTParagraphStyleCreate((CTParagraphStyleSetting[5]){
		{kCTParagraphStyleSpecifierAlignment, sizeof(alignment), &alignment},
		{kCTParagraphStyleSpecifierMinimumLineHeight,sizeof(minimumLineHeight),&minimumLineHeight},
		{kCTParagraphStyleSpecifierMaximumLineHeight,sizeof(maximumLineHeight),&maximumLineHeight},
		{kCTParagraphStyleSpecifierLineSpacing, sizeof(linespace), &linespace},
		{kCTParagraphStyleSpecifierLineBreakMode,sizeof(CTLineBreakMode),&lineBreakMode}
	},5);
	NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:(__bridge id)font,
								(NSString*)kCTFontAttributeName,
								(__bridge id)textColor.CGColor,
								(NSString*)kCTForegroundColorAttributeName,
								(__bridge id)style,(NSString*)kCTParagraphStyleAttributeName,nil];

	CGMutablePathRef path = CGPathCreateMutable();
	CGPathAddRect(path,NULL,CGRectMake(0, 0,(size.width),(size.height)));

	NSMutableAttributedString *attributedStr = [[NSMutableAttributedString alloc] initWithString:self.text
																					  attributes:attributes];
	CFAttributedStringRef attributedString = (__bridge CFAttributedStringRef)[self highlightText:attributedStr];

	CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attributedString);

	ctframe = CTFramesetterCreateFrame(framesetter, CFRangeMake(0,CFAttributedStringGetLength(attributedString)),path,NULL);
	CTFrameDraw(ctframe,context);

	CGPathRelease(path);
	CFRelease(style);
	CFRelease(font);
	CFRelease(framesetter);
	[[attributedStr mutableString] setString:@""];
	attributedStr = nil;
}

- (NSAttributedString *)highlightText:(NSMutableAttributedString *)coloredString{
    NSString* string = coloredString.string;
    NSRange range = NSMakeRange(0,[string length]);
    NSDictionary* definition = @{kRegexHighlightViewTypeAccount: AccountRegular,
								 kRegexHighlightViewTypeURL:URLRegular,
								 kRegexHighlightViewTypeTopic:TopicRegular};
    for(NSString* key in definition) {
        NSString* expression = [definition objectForKey:key];
        NSArray* matches = [[NSRegularExpression regularExpressionWithPattern:expression options:NSRegularExpressionDotMatchesLineSeparators error:nil] matchesInString:string options:0 range:range];
        for(NSTextCheckingResult* match in matches) {
            UIColor* textColor = nil;
            if(!highlightColor||!(textColor=([highlightColor objectForKey:key])))
                textColor = self.textColor;

            if (currentRange.location!=-1 && NSEqualRanges(currentRange, match.range)) {
                [coloredString addAttribute:(NSString*)kCTForegroundColorAttributeName value:(id)COLOR_URL_CLICK.CGColor range:match.range];
            } else {
                if ([rangeArr indexOfObject:[NSValue valueWithRange:match.range]]==NSIntegerMax) {
                    [rangeArr addObject:[NSValue valueWithRange:match.range]];
                }
                [coloredString addAttribute:(NSString*)kCTForegroundColorAttributeName value:(id)textColor.CGColor range:match.range];
            }
        }
    }
    return coloredString;
}

- (void)loadLines{
	lines = CTFrameGetLines(ctframe);
	lineOrigins = malloc(sizeof(CGPoint)*CFArrayGetCount(lines));
	CTFrameGetLineOrigins(ctframe, CFRangeMake(0,0), lineOrigins);
}

- (void)highlightWord{
	[self setNeedsDisplay];
}

- (void)backToNormal{
	currentRange = NSMakeRange(-1, -1);
	[self setNeedsDisplay];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    UITouch* touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    CGPoint reversePoint = CGPointMake(point.x, self.frame.size.height-point.y);
    currentRange = NSMakeRange(-1, -1);
	[self loadLines];
	int count = CFArrayGetCount(lines);
    for(CFIndex i = 0; i < count; i++){
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);
        CGPoint origin = lineOrigins[i];
        float wordY = origin.y;
        float currentY = reversePoint.y;
        if (currentY>=wordY&&currentY<=(wordY+self.font.pointSize)) {
            NSInteger index = CTLineGetStringIndexForPosition(line, reversePoint);
            for (NSValue *obj in rangeArr) {
                if (NSLocationInRange(index, obj.rangeValue)) {
                    NSString *temp = [self.text substringWithRange:obj.rangeValue];
                    if ([temp rangeOfString:@"@"].location!=NSNotFound ||
						[temp rangeOfString:@"#"].location!=NSNotFound ||
						[temp rangeOfString:@"http"].location!=NSNotFound) {
						currentRange = obj.rangeValue;
						[self highlightWord];
                    }
                }
            }
        }
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
	double delayInSeconds = .2;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		[self backToNormal];
	});
	return;
}

- (void)removeFromSuperview{
	if (ctframe) {
		CFRelease(ctframe);
		ctframe = NULL;
	}
	if (lines) {
		CFRelease(lines);
		lines = NULL;
	}
	if (lineOrigins) {
		free(lineOrigins);
	}
	[highlightColor removeAllObjects];
	highlightColor = nil;
	[rangeArr removeAllObjects];
	rangeArr = nil;
	[super removeFromSuperview];
}

@end
