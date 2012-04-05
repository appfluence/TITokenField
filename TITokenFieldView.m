//
//  TITokenFieldView.m
//  TITokenFieldView
//
//  Created by Tom Irving on 16/02/2010.
//  Copyright 2010 Tom Irving. All rights reserved.
//

#import "TITokenFieldView.h"
#import <QuartzCore/QuartzCore.h>

//==========================================================
#pragma mark - TITokenFieldView -
//==========================================================

@interface TITokenFieldView (Private)
- (NSString *)displayStringForRepresentedObject:(id)object;
- (NSString *)searchResultStringForRepresentedObject:(id)object;
- (void)setSearchResultsVisible:(BOOL)visible;
- (void)resultsForSubstring:(NSString *)substring;
- (void)presentpopoverAtTokenFieldCaretAnimated:(BOOL)animated;
@end

@implementation TITokenFieldView
@dynamic delegate;
@synthesize showAlreadyTokenized;
@synthesize tokenField;
@synthesize resultsTable;
@synthesize contentView;
@synthesize separator;
@synthesize sourceArray;

#pragma mark Init
- (id)initWithFrame:(CGRect)frame {
	
    if ((self = [super initWithFrame:frame])){
		
		[self setBackgroundColor:[UIColor clearColor]];
		[self setDelaysContentTouches:YES];
		[self setMultipleTouchEnabled:NO];
		
		showAlreadyTokenized = NO;
		resultsArray = [[NSMutableArray alloc] init];
		
		tokenField = [[TITokenField alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 42)];
		[tokenField addTarget:self action:@selector(tokenFieldDidBeginEditing:) forControlEvents:UIControlEventEditingDidBegin];
		[tokenField addTarget:self action:@selector(tokenFieldDidEndEditing:) forControlEvents:UIControlEventEditingDidEnd];
		[tokenField addTarget:self action:@selector(tokenFieldTextDidChange:) forControlEvents:UIControlEventEditingChanged];
		[tokenField addTarget:self action:@selector(tokenFieldFrameWillChange:) forControlEvents:TITokenFieldControlEventFrameWillChange];
		[tokenField addTarget:self action:@selector(tokenFieldFrameDidChange:) forControlEvents:TITokenFieldControlEventFrameDidChange];
		[tokenField setDelegate:self];
		[self addSubview:tokenField];
		[tokenField release];
		
		CGFloat tokenFieldBottom = CGRectGetMaxY(tokenField.frame);
		
		separator = [[UIView alloc] initWithFrame:CGRectMake(0, tokenFieldBottom, self.bounds.size.width, 1)];
		[separator setBackgroundColor:[UIColor colorWithWhite:0.7 alpha:1]];
		[self addSubview:separator];
		[separator release];
		
		// This view is created for convenience, because it resizes and moves with the rest of the subviews.
		contentView = [[UIView alloc] initWithFrame:CGRectMake(0, tokenFieldBottom + 1, self.bounds.size.width, 
															   self.bounds.size.height - tokenFieldBottom - 1)];
		[contentView setBackgroundColor:[UIColor clearColor]];
		[self addSubview:contentView];
		[contentView release];
		
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
			
			UITableViewController * tableViewController = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
			[tableViewController.tableView setDelegate:self];
			[tableViewController.tableView setDataSource:self];
			[tableViewController setContentSizeForViewInPopover:CGSizeMake(400, 400)];
			
			resultsTable = tableViewController.tableView;
			
			popoverController = [[UIPopoverController alloc] initWithContentViewController:tableViewController];
			[tableViewController release];
		}
		else
		{
			resultsTable = [[UITableView alloc] initWithFrame:CGRectMake(0, tokenFieldBottom + 1, self.bounds.size.width, 10)];
			[resultsTable setSeparatorColor:[UIColor colorWithWhite:0.85 alpha:1]];
			[resultsTable setBackgroundColor:[UIColor colorWithRed:0.92 green:0.92 blue:0.92 alpha:1]];
			[resultsTable setDelegate:self];
			[resultsTable setDataSource:self];
			[resultsTable setHidden:YES];
			[self addSubview:resultsTable];
			[resultsTable release];
			
			popoverController = nil;
		}
		
		[self bringSubviewToFront:separator];
		[self bringSubviewToFront:tokenField];
		[self updateContentSize];
	}
	
    return self;
}

#pragma mark Property Overrides
- (void)setFrame:(CGRect)frame {
	
	[super setFrame:frame];
	
	CGFloat width = frame.size.width;
	[separator setFrame:((CGRect){separator.frame.origin, {width, separator.bounds.size.height}})];
	[resultsTable setFrame:((CGRect){resultsTable.frame.origin, {width, resultsTable.bounds.size.height}})];
	[contentView setFrame:((CGRect){contentView.frame.origin, {width, (frame.size.height - CGRectGetMaxY(tokenField.frame))}})];
	[tokenField setFrame:((CGRect){tokenField.frame.origin, {width, tokenField.bounds.size.height}})];
	
	if (popoverController.popoverVisible){
		[popoverController dismissPopoverAnimated:NO];
		[self presentpopoverAtTokenFieldCaretAnimated:NO];
	}
	
	[self updateContentSize];
	[self layoutSubviews];
}

- (void)setContentOffset:(CGPoint)offset {
	[super setContentOffset:offset];
	[self layoutSubviews];
}

- (NSArray *)tokenTitles {
	return tokenField.tokenTitles;
}

- (void)setDelegate:(id<TITokenFieldViewDelegate>)del {
	delegate = del;
	[super setDelegate:delegate];
}

#pragma mark Event Handling
- (void)layoutSubviews {
	
	[super layoutSubviews];
	
	CGFloat relativeFieldHeight = CGRectGetMaxY(tokenField.frame) - self.contentOffset.y;
	CGFloat newHeight = self.bounds.size.height - relativeFieldHeight;
	if (newHeight > -1) [resultsTable setFrame:((CGRect){resultsTable.frame.origin, {resultsTable.bounds.size.width, newHeight}})];
}

- (void)updateContentSize {
	[self setContentSize:CGSizeMake(self.bounds.size.width, CGRectGetMaxY(contentView.frame) + 1)];
}

- (BOOL)canBecomeFirstResponder {
	return YES;
}

- (BOOL)becomeFirstResponder {
	return [tokenField becomeFirstResponder];
}

- (BOOL)resignFirstResponder {
	return [tokenField resignFirstResponder];
}

#pragma mark TableView Methods
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	if ([delegate respondsToSelector:@selector(tokenField:resultsTableView:heightForRowAtIndexPath:)]){
		return [delegate tokenField:tokenField resultsTableView:tableView heightForRowAtIndexPath:indexPath];
	}
	
	return 44;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	
	if ([delegate respondsToSelector:@selector(tokenField:didFinishSearch:)]){
		[delegate tokenField:tokenField didFinishSearch:resultsArray];
	}
	
	[self setSearchResultsVisible:(resultsArray.count > 0)];
	return resultsArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	id representedObject = [resultsArray objectAtIndex:indexPath.row];
	
	if ([delegate respondsToSelector:@selector(tokenField:resultsTableView:cellForRepresentedObject:)]){
		return [delegate tokenField:tokenField resultsTableView:tableView cellForRepresentedObject:representedObject];
	}
	
    static NSString * CellIdentifier = @"ResultsCell";
    
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	[cell.textLabel setText:[self searchResultStringForRepresentedObject:representedObject]];
	
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	
	id representedObject = [resultsArray objectAtIndex:indexPath.row];
	TIToken * token = [tokenField addTokenWithTitle:[self displayStringForRepresentedObject:representedObject]];
	[token setRepresentedObject:representedObject];
	
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark TextField Methods

- (void)tokenFieldDidBeginEditing:(TITokenField *)field {
	[resultsArray removeAllObjects];
	[resultsTable reloadData];
}

- (void)tokenFieldDidEndEditing:(TITokenField *)field {
	[self setSearchResultsVisible:NO];
}

- (void)tokenFieldTextDidChange:(TITokenField *)field {
	[self resultsForSubstring:field.text];
}

- (void)tokenFieldFrameWillChange:(TITokenField *)field {
	
	CGFloat tokenFieldBottom = CGRectGetMaxY(tokenField.frame);
	[separator setFrame:((CGRect){{separator.frame.origin.x, tokenFieldBottom}, separator.bounds.size})];
	[resultsTable setFrame:((CGRect){{resultsTable.frame.origin.x, (tokenFieldBottom + 1)}, resultsTable.bounds.size})];
	[contentView setFrame:((CGRect){{contentView.frame.origin.x, (tokenFieldBottom + 1)}, contentView.bounds.size})];
}

- (void)tokenFieldFrameDidChange:(TITokenField *)field {
	[self updateContentSize];
}

#pragma mark Results Methods
- (NSString *)displayStringForRepresentedObject:(id)object {
	
	if ([delegate respondsToSelector:@selector(tokenField:displayStringForRepresentedObject:)]){
		return [delegate tokenField:tokenField displayStringForRepresentedObject:object];
	}
	
	if ([object isKindOfClass:[NSString class]]){
		return (NSString *)object;
	}
	
	return [NSString stringWithFormat:@"%@", object];
}

- (NSString *)searchResultStringForRepresentedObject:(id)object {
	
	if ([delegate respondsToSelector:@selector(tokenField:searchResultStringForRepresentedObject:)]){
		return [delegate tokenField:tokenField searchResultStringForRepresentedObject:object];
	}
	
	return [self displayStringForRepresentedObject:object];
}

- (void)setSearchResultsVisible:(BOOL)visible {
	
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
		
		if (visible) [self presentpopoverAtTokenFieldCaretAnimated:YES];
		else [popoverController dismissPopoverAnimated:YES];
	}
	else
	{
		[resultsTable setHidden:!visible];
		[tokenField setResultsModeEnabled:visible]; 
	}
}

- (void)resultsForSubstring:(NSString *)substring {
	
	// The brute force searching method.
	// Takes the input string and compares it against everything in the source array.
	// If the source is massive, this could take some time.
	// You could always subclass and override this if needed or do it on a background thread.
	// GCD would be great for that.
	
	[resultsArray removeAllObjects];
	[resultsTable reloadData];
	
	NSString * strippedString = [[substring stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
	
	NSArray * sourceCopy = [sourceArray copy];
	for (NSString * sourceObject in sourceCopy){
		
		NSString * query = [[self searchResultStringForRepresentedObject:sourceObject] lowercaseString];		
		if ([query rangeOfString:strippedString].location != NSNotFound){
			
			BOOL shouldAdd = YES;
			
			if (!showAlreadyTokenized){
				
				for (TIToken * token in tokenField.tokens){
					
					if ([token.representedObject isEqual:sourceObject]){
						shouldAdd = NO;
						break;
					}
				}
			}
			
			if (shouldAdd && ![resultsArray containsObject:sourceObject]){
				[resultsArray addObject:sourceObject];
			}
		}
	}
	
	[sourceCopy release];
	
	[resultsArray sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		return [[self searchResultStringForRepresentedObject:obj1] localizedCaseInsensitiveCompare:[self searchResultStringForRepresentedObject:obj2]];
	}];
	[resultsTable reloadData];
}

- (void)presentpopoverAtTokenFieldCaretAnimated:(BOOL)animated {
	
    UITextPosition * position = [tokenField positionFromPosition:tokenField.beginningOfDocument offset:2];
    CGRect caretRect = [tokenField caretRectForPosition:position];
	
	[popoverController presentPopoverFromRect:caretRect inView:tokenField 
					 permittedArrowDirections:UIPopoverArrowDirectionUp animated:animated];
}

#pragma mark Other
- (NSString *)description {
	return [NSString stringWithFormat:@"<TITokenFieldView %p; Token count = %d>", self, self.tokenTitles.count];
}

- (void)dealloc {
	[self setDelegate:nil];
	[resultsArray release];
	[sourceArray release];
	[popoverController release];
	[super dealloc];
}

@end

//==========================================================
#pragma mark - TITokenField -
//==========================================================
NSString * const kTextEmpty = @" "; // Just a space
NSString * const kTextHidden = @"`"; // This character isn't available on iOS (yet) so it's safe.

@interface TITokenFieldInternalDelegate ()
@property (nonatomic, assign) id <UITextFieldDelegate> delegate;
@property (nonatomic, assign) TITokenField * tokenField;
@end

@interface TITokenField ()
@property (nonatomic, readonly) UIScrollView * scrollView;
@end

@interface TITokenField (Private)
- (CGFloat)layoutTokensInternalAnimated:(BOOL)animated;
@end

@implementation TITokenField
@synthesize delegate;
@synthesize tokens;
@synthesize editable;
@synthesize resultsModeEnabled;
@synthesize removesTokensOnEndEditing;
@synthesize numberOfLines;
@synthesize selectedToken;
@synthesize tokenizingCharacters;

#pragma mark Init
- (id)initWithFrame:(CGRect)frame {
	
    if ((self = [super initWithFrame:frame])){
		[self setup];
    }
	
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	
	if ((self = [super initWithCoder:aDecoder])){
		[self setup];
	}
	
	return self;
}

- (void)setup {
	
	[self setBorderStyle:UITextBorderStyleNone];
	[self setFont:[UIFont systemFontOfSize:14]];
	[self setBackgroundColor:[UIColor whiteColor]];
	[self setAutocorrectionType:UITextAutocorrectionTypeNo];
	[self setAutocapitalizationType:UITextAutocapitalizationTypeNone];
	
	[self addTarget:self action:@selector(didBeginEditing) forControlEvents:UIControlEventEditingDidBegin];
	[self addTarget:self action:@selector(didEndEditing) forControlEvents:UIControlEventEditingDidEnd];
	[self addTarget:self action:@selector(didChangeText) forControlEvents:UIControlEventEditingChanged];
	
	[self.layer setShadowColor:[[UIColor blackColor] CGColor]];
	[self.layer setShadowOpacity:0.6];
	[self.layer setShadowRadius:12];
	
	addButton = [UIButton buttonWithType:UIButtonTypeContactAdd];
	[addButton setUserInteractionEnabled:YES];
	[addButton setHidden:YES];
	[addButton addTarget:self action:@selector(performButtonAction) forControlEvents:UIControlEventTouchUpInside];
	[self setRightView:addButton];
	[self setAddButtonAction:nil target:nil];
	
	[self setPromptText:@"To:"];
	[self setText:kTextEmpty];
	
	internalDelegate = [[TITokenFieldInternalDelegate alloc] init];
	[internalDelegate setTokenField:self];
	[super setDelegate:internalDelegate];
	
	tokens = [[NSMutableArray alloc] init];
	editable = YES;
	removesTokensOnEndEditing = YES;
	tokenizingCharacters = [[NSCharacterSet characterSetWithCharactersInString:@","] retain];
}

#pragma mark Property Overrides
- (void)setFrame:(CGRect)frame {
	[super setFrame:frame];
	[self.layer setShadowPath:[[UIBezierPath bezierPathWithRect:self.bounds] CGPath]];
	[self layoutTokensAnimated:NO];
}

- (void)setText:(NSString *)text {
	[super setText:((text.length == 0 || [text isEqualToString:@""]) ? kTextEmpty : text)];
}

- (void)setFont:(UIFont *)font {
	[super setFont:font];
	
	if ([self.leftView isKindOfClass:[UILabel class]]){
		[self setPromptText:((UILabel *)self.leftView).text];
	}
}

- (void)setDelegate:(id<TITokenFieldDelegate>)del {
	delegate = del;
	[internalDelegate setDelegate:delegate];
}

- (NSArray *)tokens {
	return [[tokens copy] autorelease];
}

- (NSArray *)tokenTitles {
	
	NSMutableArray * titles = [[NSMutableArray alloc] init];
	for (TIToken * token in tokens) [titles addObject:token.title];
	return [titles autorelease];
}

- (NSArray *)tokenObjects {
	
	NSMutableArray * objects = [[NSMutableArray alloc] init];
	for (TIToken * token in tokens) [objects addObject:(token.representedObject ? token.representedObject : token.title)];
	return [objects autorelease];
}

- (UIScrollView *)scrollView {
	return ([self.superview isKindOfClass:[UIScrollView class]] ? (UIScrollView *)self.superview : nil);
}

#pragma mark Event Handling
- (BOOL)becomeFirstResponder {
	return (editable ? [super becomeFirstResponder] : NO);
}

- (void)didBeginEditing {
	for (TIToken * token in tokens) [self addToken:token];
}

- (void)didEndEditing {
	
	[selectedToken setSelected:NO];
	selectedToken = nil;
	
	[self tokenizeText];
	
	if (removesTokensOnEndEditing){
		
		for (TIToken * token in tokens) [token removeFromSuperview];
		
		NSString * untokenized = kTextEmpty;
		
		if (tokens.count){
			
			NSMutableArray * titles = [[NSMutableArray alloc] init];
			for (TIToken * token in tokens) [titles addObject:token.title];
			
			untokenized = [self.tokenTitles componentsJoinedByString:@", "];
			CGSize untokSize = [untokenized sizeWithFont:[UIFont systemFontOfSize:14]];
			CGFloat availableWidth = self.bounds.size.width - self.leftView.bounds.size.width - self.rightView.bounds.size.width;
			
			if (tokens.count > 1 && untokSize.width > availableWidth){
				untokenized = [NSString stringWithFormat:@"%d recipients", titles.count];
			}
			
			[titles release];
		}
		
		[self setText:untokenized];
	}
	
	[self setResultsModeEnabled:NO];
}

- (void)didChangeText {
	if (self.text.length == 0) [self setText:kTextEmpty];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
	
	// Stop the cut, copy, select and selectAll appearing when the field is 'empty'.
	if (action == @selector(cut:) || action == @selector(copy:) || action == @selector(select:) || action == @selector(selectAll:))
		return ![self.text isEqualToString:kTextEmpty];
	 
	return [super canPerformAction:action withSender:sender];
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
	
	if (selectedToken && touch.view == self) [self deselectSelectedToken];
	return [super beginTrackingWithTouch:touch withEvent:event];
}

#pragma mark Token Handling
- (TIToken *)addTokenWithTitle:(NSString *)title {
	
	if (title.length){
		TIToken * token = [[TIToken alloc] initWithTitle:title representedObject:nil font:self.font];
		[self addToken:token];
		[token release];
		return token;
	}
	
	return nil;
}

- (void)addToken:(TIToken *)token {
	
	BOOL shouldAdd = YES;
	if ([delegate respondsToSelector:@selector(tokenField:willAddToken:)]){
		shouldAdd = [delegate tokenField:self willAddToken:token];
	}
	
	if (shouldAdd){
	
		[self becomeFirstResponder];
	
		[token addTarget:self action:@selector(tokenTouchDown:) forControlEvents:UIControlEventTouchDown];
		[token addTarget:self action:@selector(tokenTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
		[self addSubview:token];
	
		if (![tokens containsObject:token]) [tokens addObject:token];
		
		if ([delegate respondsToSelector:@selector(tokenField:didAddToken:)]){
			[delegate tokenField:self didAddToken:token];
		}
		
		[self setResultsModeEnabled:NO];
		[self setText:kTextEmpty];
	}
}

- (void)removeToken:(TIToken *)token {
	
	if (token == selectedToken) [self deselectSelectedToken];
	
	BOOL shouldRemove = YES;
	if ([delegate respondsToSelector:@selector(tokenField:willRemoveToken:)]){
		shouldRemove = [delegate tokenField:self willRemoveToken:token];
	}
	
	if (shouldRemove){
	
		[token removeFromSuperview];
		[tokens removeObject:token];
		
		if ([delegate respondsToSelector:@selector(tokenField:didRemoveToken:)]){
			[delegate tokenField:self didRemoveToken:token];
		}
		
		[self setResultsModeEnabled:NO];
	}
}

- (void)selectToken:(TIToken *)token {
	
	[self deselectSelectedToken];
	
	selectedToken = token;
	[selectedToken setSelected:YES];
	
	[self becomeFirstResponder];
	
	[self setText:kTextHidden];
}

- (void)deselectSelectedToken {
	
	[selectedToken setSelected:NO];
	selectedToken = nil;
	
	[self setText:kTextEmpty];
}

- (void)tokenizeText {
	
	if (![self.text isEqualToString:kTextEmpty] && ![self.text isEqualToString:kTextHidden]){
		for (NSString * component in [self.text componentsSeparatedByCharactersInSet:tokenizingCharacters]){
			[self addTokenWithTitle:[component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
		}
	}
}

- (void)tokenTouchDown:(TIToken *)token {
	
	if (selectedToken != token){
		[selectedToken setSelected:NO];
		selectedToken = nil;
	}
}

- (void)tokenTouchUpInside:(TIToken *)token {
	if (editable) [self selectToken:token];
}

- (CGFloat)layoutTokensInternalAnimated:(BOOL)animated {
	
	// Adapted from Joe Hewitt's Three20 layout method.
	CGFloat topMargin = floor(self.font.lineHeight * 4 / 7);
	CGFloat leftMargin = self.leftView ? self.leftView.bounds.size.width + 12 : 8;
	CGFloat rightMargin = 16;
	CGFloat rightMarginWithButton = addButton.hidden ? 8 : 46;
	CGFloat initialPadding = 8;
	CGFloat tokenPadding = 4;
	CGFloat lineHeightWithPadding = self.font.lineHeight + topMargin + 5;
	
	numberOfLines = 1;
	cursorLocation.x = leftMargin;
	cursorLocation.y = topMargin - 1;
	
	for (TIToken * token in tokens){
		
		[token setFont:self.font];
		
		if (token.superview){
			
			CGFloat lineWidth = cursorLocation.x + token.bounds.size.width + rightMargin;
			if (lineWidth >= self.bounds.size.width){
				
				numberOfLines++;
				cursorLocation.x = leftMargin;
				
				if (numberOfLines > 1) cursorLocation.x = initialPadding;
				cursorLocation.y += lineHeightWithPadding;
			}
			
			CGRect newFrame = (CGRect){cursorLocation, token.bounds.size};
			if (!CGRectEqualToRect(token.frame, newFrame)){
				
				[token setFrame:newFrame];
				
				if (animated){
					[token setAlpha:0.6];
					[UIView animateWithDuration:0.3 animations:^{[token setAlpha:1];}];
				}
			}
			
			cursorLocation.x += token.bounds.size.width + tokenPadding;
		}
		
		CGFloat leftoverWidth = self.bounds.size.width - (cursorLocation.x + rightMarginWithButton);
		if (leftoverWidth < 50){
			
			numberOfLines++;
			cursorLocation.x = leftMargin;
			
			if (numberOfLines > 1) cursorLocation.x = initialPadding;
			cursorLocation.y += lineHeightWithPadding;
		}
	}
	
	return cursorLocation.y + lineHeightWithPadding;
}

#pragma mark View Handlers
- (void)layoutTokensAnimated:(BOOL)animated {
	
	CGFloat newHeight = [self layoutTokensInternalAnimated:animated];
	if (self.bounds.size.height != newHeight){
		
		// Animating this seems to invoke the triple-tap-delete-key-loop-problem-thing™
		[UIView animateWithDuration:(animated ? 0.3 : 0) animations:^{
			[self setFrame:((CGRect){self.frame.origin, {self.bounds.size.width, newHeight}})];
			[self sendActionsForControlEvents:TITokenFieldControlEventFrameWillChange];
			
		} completion:^(BOOL complete){
			[self sendActionsForControlEvents:TITokenFieldControlEventFrameDidChange];
		}];
	}
}

- (void)setResultsModeEnabled:(BOOL)flag {
	[self setResultsModeEnabled:flag animated:YES];
}

- (void)setResultsModeEnabled:(BOOL)flag animated:(BOOL)animated {
	
	[self layoutTokensAnimated:animated];
	
	if (resultsModeEnabled != flag){
		
		//Hide / show the shadow
		[self.layer setMasksToBounds:!flag];
		
		UIScrollView * scrollView = self.scrollView;
		[scrollView setScrollsToTop:!flag];
		[scrollView setScrollEnabled:!flag];
		
		CGFloat offset = ((numberOfLines == 1 || !flag) ? 0 : cursorLocation.y - floor(self.font.lineHeight * 4 / 7) + 1);
		[scrollView setContentOffset:CGPointMake(0, self.frame.origin.y + offset) animated:animated];
	}
	
	resultsModeEnabled = flag;
}

#pragma mark Left / Right view stuff
- (void)setPromptText:(NSString *)text {
	
	if (text){
		
		UILabel * label = (UILabel *)self.leftView;
		if (!label || ![label isKindOfClass:[UILabel class]]){
			label = [[UILabel alloc] initWithFrame:CGRectZero];
			[label setTextColor:[UIColor colorWithWhite:0.5 alpha:1]];
			[self setLeftView:label];
			[label release];
			
			[self setLeftViewMode:UITextFieldViewModeAlways];
		}
		
		[label setText:text];
		[label setFont:[UIFont systemFontOfSize:(self.font.pointSize + 1)]];
		[label sizeToFit];
	}
	else
	{
		[self setLeftView:nil];
	}
	
	[self layoutTokensAnimated:YES];
}

- (void)setAddButtonAction:(SEL)action target:(id)sender {
	
	addButtonSelector = action;
	addButtonTarget = sender;
	
	[addButton setHidden:(!action || !sender)];
	[self setRightViewMode:(addButton.hidden ? UITextFieldViewModeNever : UITextFieldViewModeAlways)];
}

- (void)performButtonAction {
	[addButtonTarget performSelector:addButtonSelector withObject:addButton];
}

#pragma mark Layout
- (CGRect)textRectForBounds:(CGRect)bounds {
	
	if ([self.text isEqualToString:kTextHidden]) return CGRectMake(0, -20, 0, 0);
	
	CGRect frame = CGRectOffset(bounds, cursorLocation.x, cursorLocation.y + 3);
	frame.size.width -= (cursorLocation.x + 8 + (addButton.hidden ? 0 : 28));
	
	return frame;
}

- (CGRect)editingRectForBounds:(CGRect)bounds {
	return [self textRectForBounds:bounds];
}

- (CGRect)placeholderRectForBounds:(CGRect)bounds {
	return [self textRectForBounds:bounds];
}

- (CGRect)leftViewRectForBounds:(CGRect)bounds {
	return ((CGRect){{8, ceilf(self.font.lineHeight * 4 / 7)}, self.leftView.bounds.size});
}

- (CGRect)rightViewRectForBounds:(CGRect)bounds {
	return ((CGRect){{bounds.size.width - addButton.bounds.size.width - 6, 
		bounds.size.height - addButton.bounds.size.height - 6}, addButton.bounds.size});
}

#pragma mark Other
- (NSString *)description {
	return [NSString stringWithFormat:@"<TITokenField %p; prompt = \"%@\">", self, ((UILabel *)self.leftView).text];
}

- (void)dealloc {
	[self setDelegate:nil];
	[internalDelegate release];
	[tokens release];
	[tokenizingCharacters release];
    [super dealloc];
}

@end

//==========================================================
#pragma mark - TITokenFieldInternalDelegate -
//==========================================================
@implementation TITokenFieldInternalDelegate 
@synthesize delegate;
@synthesize tokenField;

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
	
	if ([delegate respondsToSelector:@selector(textFieldShouldBeginEditing:)]){
		return [delegate textFieldShouldBeginEditing:textField];
	}
	
	return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
	
	if ([delegate respondsToSelector:@selector(textFieldDidBeginEditing:)]){
		[delegate textFieldDidBeginEditing:textField];
	}
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
	
	if ([delegate respondsToSelector:@selector(textFieldShouldEndEditing:)]){
		return [delegate textFieldShouldEndEditing:textField];
	}
	
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
	
	if ([delegate respondsToSelector:@selector(textFieldDidEndEditing:)]){
		[delegate textFieldDidEndEditing:textField];
	}
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
	
	if (tokenField.tokens.count && [string isEqualToString:@""] && [tokenField.text isEqualToString:kTextEmpty]){
		[tokenField selectToken:[tokenField.tokens lastObject]];
		return NO;
	}
	
	if ([textField.text isEqualToString:kTextHidden]){
		[tokenField removeToken:tokenField.selectedToken];
		return (![string isEqualToString:@""]);
	}
	
	if ([string rangeOfCharacterFromSet:tokenField.tokenizingCharacters].location != NSNotFound){
		[tokenField tokenizeText];
		return NO;
	}
	
	if ([delegate respondsToSelector:@selector(textField:shouldChangeCharactersInRange:replacementString:)]){
		return [delegate textField:textField shouldChangeCharactersInRange:range replacementString:string];
	}
	
	return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	
	[tokenField tokenizeText];
	
	if ([delegate respondsToSelector:@selector(textFieldShouldReturn:)]){
		[delegate textFieldShouldReturn:textField];
	}
	
	return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
	
	if ([delegate respondsToSelector:@selector(textFieldShouldClear:)]){
		return [delegate textFieldShouldClear:textField];
	}
	
	return YES;
}

@end


//==========================================================
#pragma mark - TIToken -
//==========================================================

CGFloat const hTextPadding = 14;
CGFloat const vTextPadding = 8;
CGFloat const kDisclosureThickness = 2.5;
UILineBreakMode const kLineBreakMode = UILineBreakModeTailTruncation;

@interface TIToken (Private)
CGPathRef CGPathCreateTokenPath(CGFloat width, CGFloat arcValue, BOOL innerPath);
CGPathRef CGPathCreateDisclosureIndicatorPath(CGPoint arrowPointFront, CGFloat height, CGFloat thickness, CGFloat * width);
- (BOOL)getTintColorRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue alpha:(CGFloat *)alpha;
@end

@implementation TIToken
@synthesize title;
@synthesize font;
@synthesize tintColor;
@synthesize maxWidth;
@synthesize accessoryType;
@synthesize representedObject;

#pragma mark Init
- (id)initWithTitle:(NSString *)aTitle {
	return [self initWithTitle:aTitle representedObject:nil];
}

- (id)initWithTitle:(NSString *)aTitle representedObject:(id)object {
	return [self initWithTitle:aTitle representedObject:object font:[UIFont systemFontOfSize:14]];
}

- (id)initWithTitle:(NSString *)aTitle representedObject:(id)object font:(UIFont *)aFont {
	
	if ((self = [super init])){
		
		title = [aTitle copy];
		representedObject = [object retain];
		accessoryType = TITokenAccessoryTypeNone;
		
		font = [aFont retain];
		tintColor = [[UIColor colorWithRed:0.216 green:0.373 blue:0.965 alpha:1] retain];
		maxWidth = 200;
		[self sizeToFit];
		
		[self setBackgroundColor:[UIColor clearColor]];
	}
	
	return self;
}

#pragma mark Property Overrides
- (void)setHighlighted:(BOOL)flag {
	
	if (self.highlighted != flag){
		[super setHighlighted:flag];
		[self setNeedsDisplay];
	}
}

- (void)setSelected:(BOOL)flag {
	
	if (self.selected != flag){
		[super setSelected:flag];
		[self setNeedsDisplay];
	}
}

- (void)setTitle:(NSString *)newTitle {
	
	if (newTitle){
		NSString * copy = [newTitle copy];
		[title release];
		title = copy;
		
		[self sizeToFit];
	}
}

- (void)setFont:(UIFont *)newFont {
	
	if (!newFont) newFont = [UIFont systemFontOfSize:14];
	[newFont retain];
	[font release];
	font = newFont;
	
	[self sizeToFit];
}

- (void)setTintColor:(UIColor *)newTintColor {
	
	if (!newTintColor) newTintColor = [UIColor colorWithRed:0.867 green:0.906 blue:0.973 alpha:1];
	
	[newTintColor retain];
	[tintColor release];
	tintColor = newTintColor;
	
	[self setNeedsDisplay];
}

- (void)setMaxWidth:(CGFloat)width {
	
	if (maxWidth != width){
		maxWidth = width;
		[self sizeToFit];
	}
}

- (void)setAccessoryType:(TITokenAccessoryType)type {
	
	if (accessoryType != type){
		accessoryType = type;
		[self sizeToFit];
	}
}

#pragma Layout
- (void)sizeToFit {
	
	CGFloat accessoryWidth = 0;
	
	if (accessoryType == TITokenAccessoryTypeDisclosureIndicator){
		CGPathRelease(CGPathCreateDisclosureIndicatorPath(CGPointZero, font.pointSize, kDisclosureThickness, &accessoryWidth));
		accessoryWidth += floorf(hTextPadding / 2);
	}
	
	CGSize titleSize = [title sizeWithFont:font forWidth:(maxWidth - hTextPadding - accessoryWidth) lineBreakMode:kLineBreakMode];
	[self setFrame:((CGRect){self.frame.origin, {floorf(titleSize.width + hTextPadding + accessoryWidth), floorf(titleSize.height + vTextPadding)}})];
	[self setNeedsDisplay];
}

#pragma Drawing
- (void)drawRect:(CGRect)rect {
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGFloat arcValue = ((self.bounds.size.height - (vTextPadding / 2)) / 2) + 1;
	BOOL drawHighlighted = (self.selected || self.highlighted);
	
	CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
	CGPoint endPoint = CGPointMake(0, self.bounds.size.height);
	
	// Draw the outline.
	CGContextSaveGState(context);
	
	CGPathRef outlinePath = CGPathCreateTokenPath(self.bounds.size.width, arcValue, NO);
	CGContextAddPath(context, outlinePath);
	CGPathRelease(outlinePath);
	
	CGFloat red = 1;
	CGFloat green = 1;
	CGFloat blue = 1;
	CGFloat alpha = 1;
	[self getTintColorRed:&red green:&green blue:&blue alpha:&alpha];
	
	if (drawHighlighted){
		CGContextSetFillColor(context, (CGFloat[4]){red, green, blue, 1});
		CGContextFillPath(context);
	}
	else
	{
		CGContextClip(context);
		CGFloat locations[2] = {0, 0.95};
		CGFloat components[8] = {red + 0.2, green + 0.2, blue + 0.2, alpha, red, green, blue, alpha};
		CGGradientRef gradient = CGGradientCreateWithColorComponents(colorspace, components, locations, 2);
		CGContextDrawLinearGradient(context, gradient, CGPointZero, endPoint, 0);
		CGGradientRelease(gradient);
	}
	
	CGContextRestoreGState(context);
	
	CGPathRef innerPath = CGPathCreateTokenPath(self.bounds.size.width, arcValue, YES);
    
    // Draw a white background so we can use alpha to lighten the inner gradient
    CGContextSaveGState(context);
	CGContextAddPath(context, innerPath);
    CGContextSetFillColor(context, (CGFloat[4]){1, 1, 1, 1});
    CGContextFillPath(context);
    CGContextRestoreGState(context);
	
	// Draw the inner gradient.
	CGContextSaveGState(context);
	CGContextAddPath(context, innerPath);
	CGPathRelease(innerPath);
	CGContextClip(context);
	
	CGFloat locations[2] = {0, (drawHighlighted ? 0.9 : 0.6)};
    CGFloat highlightedComp[8] = {red, green, blue, 0.7, red, green, blue, 1};
    CGFloat nonHighlightedComp[8] = {red, green, blue, 0.15, red, green, blue, 0.3};
	
	CGGradientRef gradient = CGGradientCreateWithColorComponents(colorspace, (drawHighlighted ? highlightedComp : nonHighlightedComp), locations, 2);
	CGContextDrawLinearGradient(context, gradient, CGPointZero, endPoint, 0);
	CGGradientRelease(gradient);
	CGContextRestoreGState(context);
	
	CGFloat accessoryWidth = 0;
	
	if (accessoryType == TITokenAccessoryTypeDisclosureIndicator){
		CGPoint arrowPoint = CGPointMake(self.bounds.size.width - floorf(hTextPadding / 2), (self.bounds.size.height / 2) - 1);
		CGPathRef disclosurePath = CGPathCreateDisclosureIndicatorPath(arrowPoint, font.pointSize, kDisclosureThickness, &accessoryWidth);
		accessoryWidth += floorf(hTextPadding / 2);
		
		CGContextAddPath(context, disclosurePath);
		CGContextSetFillColor(context, (CGFloat[4]){1, 1, 1, 1});
		
		if (drawHighlighted){
			CGContextFillPath(context);
		}
		else
		{
			CGContextSaveGState(context);
			CGContextSetShadowWithColor(context, CGSizeMake(0, 1), 1, [[[UIColor whiteColor] colorWithAlphaComponent:0.6] CGColor]);
			CGContextFillPath(context);
			CGContextRestoreGState(context);
			
			CGContextSaveGState(context);
			CGContextAddPath(context, disclosurePath);
			CGContextClip(context);
			
			CGGradientRef disclosureGradient = CGGradientCreateWithColorComponents(colorspace, highlightedComp, NULL, 2);
			CGContextDrawLinearGradient(context, disclosureGradient, CGPointZero, endPoint, 0);
			CGGradientRelease(disclosureGradient);
			
			arrowPoint.y += 0.5;
			CGPathRef innerShadowPath = CGPathCreateDisclosureIndicatorPath(arrowPoint, font.pointSize, kDisclosureThickness, NULL);
			CGContextAddPath(context, innerShadowPath);
			CGContextSetStrokeColor(context, (CGFloat[4]){0, 0, 0, 0.3});
			CGContextStrokePath(context);
			CGContextRestoreGState(context);
		}
		
		CGPathRelease(disclosurePath);
	}
	
	CGColorSpaceRelease(colorspace);
	
	CGSize titleSize = [title sizeWithFont:font forWidth:(maxWidth - hTextPadding - accessoryWidth) lineBreakMode:kLineBreakMode];
	CGFloat vPadding = floor((self.bounds.size.height - titleSize.height) / 2);
	CGFloat titleWidth = ceilf(self.bounds.size.width - hTextPadding - accessoryWidth);
	CGRect textBounds = CGRectMake(floorf(hTextPadding / 2), vPadding - 1, titleWidth, floorf(self.bounds.size.height - (vPadding * 2)));
	
	CGContextSetFillColor(context, (drawHighlighted ? (CGFloat[4]){1, 1, 1, 1} : (CGFloat[4]){0, 0, 0, 1}));
	[title drawInRect:textBounds withFont:font lineBreakMode:kLineBreakMode];
}

CGPathRef CGPathCreateTokenPath(CGFloat width, CGFloat arcValue, BOOL innerPath) {
	
	CGMutablePathRef path = CGPathCreateMutable();
	CGFloat radius = arcValue - (innerPath ? 0.5 : 0);
	CGPathAddArc(path, NULL, arcValue, arcValue, radius, (M_PI / 2), (M_PI * 3 / 2), NO);
	CGPathAddArc(path, NULL, width - arcValue, arcValue, radius, (M_PI  * 3 / 2), (M_PI / 2), NO);
	
	return path;
}

CGPathRef CGPathCreateDisclosureIndicatorPath(CGPoint arrowPointFront, CGFloat height, CGFloat thickness, CGFloat * width) {
	
	thickness /= cosf(M_PI / 4);
	
	CGMutablePathRef path = CGPathCreateMutable();
	CGPathMoveToPoint(path, NULL, arrowPointFront.x, arrowPointFront.y);
	
	CGPoint bottomPointFront = CGPointMake(arrowPointFront.x - (height / (2 * tanf(M_PI / 4))), arrowPointFront.y - height / 2);
	CGPathAddLineToPoint(path, NULL, bottomPointFront.x, bottomPointFront.y);
	
	CGPoint bottomPointBack = CGPointMake(bottomPointFront.x - thickness * cosf(M_PI / 4),  bottomPointFront.y + thickness * sinf(M_PI / 4));
	CGPathAddLineToPoint(path, NULL, bottomPointBack.x, bottomPointBack.y);
	
	CGPoint arrowPointBack = CGPointMake(arrowPointFront.x - thickness / cosf(M_PI / 4), arrowPointFront.y);
	CGPathAddLineToPoint(path, NULL, arrowPointBack.x, arrowPointBack.y);
	
	CGPoint topPointFront = CGPointMake(bottomPointFront.x, arrowPointFront.y + height / 2);
	CGPoint topPointBack = CGPointMake(bottomPointBack.x, topPointFront.y - thickness * sinf(M_PI / 4));
	
	CGPathAddLineToPoint(path, NULL, topPointBack.x, topPointBack.y);
	CGPathAddLineToPoint(path, NULL, topPointFront.x, topPointFront.y);
	CGPathAddLineToPoint(path, NULL, arrowPointFront.x, arrowPointFront.y);
	
	if (width) *width = (arrowPointFront.x - topPointBack.x);
	return path;
}

- (BOOL)getTintColorRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue alpha:(CGFloat *)alpha {
	
	CGColorSpaceModel colorSpaceModel = CGColorSpaceGetModel(CGColorGetColorSpace(tintColor.CGColor));
	const CGFloat * components = CGColorGetComponents(tintColor.CGColor);
	
	if (colorSpaceModel == kCGColorSpaceModelMonochrome){
		
		if (red) *red = components[0];
		if (green) *green = components[0];
		if (blue) *blue = components[0];
		if (alpha) *alpha = components[1];
		return YES;
	}
	
	if (colorSpaceModel == kCGColorSpaceModelRGB){
		
		if (red) *red = components[0];
		if (green) *green = components[1];
		if (blue) *blue = components[2];
		if (alpha) *alpha = components[3];
		return YES;
	}
	
	return NO;
}

#pragma mark Other
- (NSString *)description {
	return [NSString stringWithFormat:@"<TIToken %p; title = \"%@\">", self, title];
}

- (void)dealloc {
	[title release];
	[font release];
	[tintColor release];
	[representedObject release];
    [super dealloc];
}

@end