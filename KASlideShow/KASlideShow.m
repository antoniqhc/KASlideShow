//
//  KASlideShow.m
//
// Copyright 2013 Alexis Creuzot
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "KASlideShow.h"

#define kSwipeTransitionDuration 0.25

typedef NS_ENUM(NSInteger, KASlideShowSlideMode) {
    KASlideShowSlideModeForward,
    KASlideShowSlideModeBackward
};

typedef NS_ENUM(NSInteger, KASlidePanGestureDirection) {
    KASlidePanRight,
    KASLidePanLeft
};

@interface KASlideShow()
@property (atomic) BOOL doStop;
@property (atomic) BOOL isAnimating;
@property (nonatomic) BOOL isPanGestureSlide;
@property (strong,nonatomic) UIImageView * topImageView;
@property (strong,nonatomic) UIImageView * bottomImageView;
@end

@implementation KASlideShow

@synthesize delegate;
@synthesize delay;
@synthesize transitionDuration;
@synthesize transitionType;
@synthesize images;
@synthesize repeatable;

- (void)awakeFromNib
{
    [self setDefaultValues];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setDefaultValues];
    }
    return self;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
	
	// Do not reposition the embedded imageViews.
	frame.origin.x = 0;
	frame.origin.y = 0;
	
    _topImageView.frame = frame;
    _bottomImageView.frame = frame;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (!CGRectEqualToRect(self.bounds, _topImageView.bounds)) {
        _topImageView.frame = self.bounds;
    }
    
    if (!CGRectEqualToRect(self.bounds, _bottomImageView.bounds)) {
        _bottomImageView.frame = self.bounds;
    }
}

- (void) setDefaultValues
{
    self.clipsToBounds = YES;
    self.images = [NSMutableArray array];
    _currentIndex = 0;
    delay = 3;
    
    transitionDuration = 1;
    transitionType = KASlideShowTransitionFade;
    repeatable = NO;
    
    _doStop = YES;
    _isAnimating = NO;
    
    _topImageView = [[UIImageView alloc] initWithFrame:self.bounds];
    _bottomImageView = [[UIImageView alloc] initWithFrame:self.bounds];
    _topImageView.autoresizingMask = _bottomImageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    _topImageView.clipsToBounds = YES;
    _bottomImageView.clipsToBounds = YES;
    [self setImagesContentMode:UIViewContentModeScaleAspectFit];
    
    [self addSubview:_bottomImageView];
    [self addSubview:_topImageView];
    
}

- (void) setImagesContentMode:(UIViewContentMode)mode
{
    _topImageView.contentMode = mode;
    _bottomImageView.contentMode = mode;
}

- (UIViewContentMode) imagesContentMode
{
    return _topImageView.contentMode;
}

- (void) addGesture:(KASlideShowGestureType)gestureType
{
    switch (gestureType)
    {
        case KASlideShowGestureTap:
            [self addGestureTap];
            break;
        case KASlideShowGestureSwipe:
            [self addGestureSwipe];
            break;
        case KASlideShowGesturePan:
            [self addGesturePan];
            break;
        case KASlideShowGestureAll:
            [self addGestureTap];
            [self addGestureSwipe];
            break;
        default:
            break;
    }
}

- (void) removeGestures
{
    self.gestureRecognizers = nil;
}

- (void) addImagesWithPath:(NSArray *) paths
{
    for(NSString * path in paths){
        [self addImage:[UIImage imageWithContentsOfFile:path]];
    }
}

- (void) addImagesFromResources:(NSArray *) names
{
    for(NSString * name in names){
        [self addImage:[UIImage imageNamed:name]];
    }
}

- (void) setImagesDataSource:(NSMutableArray *)array {
    self.images = array;
    
    _topImageView.image = [array firstObject];
}

- (void) addImage:(UIImage*) image
{
    [self.images addObject:image];
    
    if([self.images count] == 1){
        _topImageView.image = image;
    }else if([self.images count] == 2){
        _bottomImageView.image = image;
    }
}

- (void) emptyImages
{
    [self.images removeAllObjects];
}

- (void) emptyAndAddImagesFromResources:(NSArray *)names
{
    [self emptyImages];
    _currentIndex = 0;
    [self addImagesFromResources:names];
}

- (void) emptyAndAddImages:(NSArray *) newImages
{
    [self.images removeAllObjects];
    _currentIndex = 0;
    for (UIImage *image in newImages){
        [self addImage:image];
    }
}

- (int) getPreviousIndex
{
    if(_currentIndex == 0){
        return [self.images count] - 1;
    }else{
        return (_currentIndex-1)%[self.images count];
    }

}

- (int) getNextIndex
{
    return (_currentIndex+1)%[self.images count];
}

- (void) start
{
    _doStop = NO;
    [self next];
}

- (void) next
{

    if((repeatable || (_currentIndex < [self.images count] - 1 && !repeatable)) && ! _isAnimating && ([self.images count] >1 || self.dataSource)) {
        
        if ([self.delegate respondsToSelector:@selector(kaSlideShowWillShowNext:)]) [self.delegate kaSlideShowWillShowNext:self];
        
        // Next Image
        if (self.dataSource) {
            _topImageView.image = [self.dataSource slideShow:self imageForPosition:KASlideShowPositionTop];
            _bottomImageView.image = [self.dataSource slideShow:self imageForPosition:KASlideShowPositionBottom];
        } else {
            NSUInteger nextIndex = [self getNextIndex];
            _topImageView.image = self.images[_currentIndex];
            _bottomImageView.image = self.images[nextIndex];
            _currentIndex = nextIndex;
        }
        
        // Animate
        switch (transitionType) {
            case KASlideShowTransitionFade:
                [self animateFade];
                break;
                
            case KASlideShowTransitionSlide:
                if(_isPanGestureSlide){
                    [self animatePanSlide:KASlideShowSlideModeForward];
                } else {
                    [self animateSlide:KASlideShowSlideModeForward];
                }
                break;
        }
        
        // Call delegate
        if([delegate respondsToSelector:@selector(kaSlideShowDidShowNext:)]){
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, transitionDuration * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [delegate kaSlideShowDidShowNext:self];
            });
        }
        
        _isPanGestureSlide = NO;
    }
}

- (void) previous
{
    if((repeatable || (_currentIndex > 0 && !repeatable)) && ! _isAnimating && ([self.images count] >1 || self.dataSource)){
        
        if ([self.delegate respondsToSelector:@selector(kaSlideShowWillShowPrevious:)]) [self.delegate kaSlideShowWillShowPrevious:self];
        
        // Previous image
        if (self.dataSource) {
            _topImageView.image = [self.dataSource slideShow:self imageForPosition:KASlideShowPositionTop];
            _bottomImageView.image = [self.dataSource slideShow:self imageForPosition:KASlideShowPositionBottom];
        } else {
            NSUInteger prevIndex = [self getPreviousIndex];
            _topImageView.image = self.images[_currentIndex];
            _bottomImageView.image = self.images[prevIndex];
            _currentIndex = prevIndex;
        }
        
        // Animate
        switch (transitionType) {
            case KASlideShowTransitionFade:
                [self animateFade];
                break;
                
            case KASlideShowTransitionSlide:
                if(_isPanGestureSlide){
                    [self animatePanSlide:KASlideShowSlideModeBackward];
                } else {
                    [self animateSlide:KASlideShowSlideModeBackward];
                }
                break;
        }
        
        // Call delegate
        if([delegate respondsToSelector:@selector(kaSlideShowDidShowPrevious:)]){
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, transitionDuration * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [delegate kaSlideShowDidShowPrevious:self];
            });
        }
        
        _isPanGestureSlide = NO;
    }
    
}

- (void) animateFade
{
    _isAnimating = YES;
    
    [UIView animateWithDuration:transitionDuration
                     animations:^{
                         _topImageView.alpha = 0;
                     }
                     completion:^(BOOL finished){
                         
                         _topImageView.image = _bottomImageView.image;
                         _topImageView.alpha = 1;
                         
                         _isAnimating = NO;
                         
                         if(! _doStop){
                             [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(next) object:nil];
                             [self performSelector:@selector(next) withObject:nil afterDelay:delay];
                         }
                     }];
}


- (void) animateSlide:(KASlideShowSlideMode) mode
{
    _isAnimating = YES;
    
    if(mode == KASlideShowSlideModeBackward){
        _bottomImageView.transform = CGAffineTransformMakeTranslation(- _bottomImageView.frame.size.width, 0);
    }else if(mode == KASlideShowSlideModeForward){
        _bottomImageView.transform = CGAffineTransformMakeTranslation(_bottomImageView.frame.size.width, 0);
    }
    
    
    [UIView animateWithDuration:transitionDuration
                     animations:^{
                         
                         if(mode == KASlideShowSlideModeBackward){
                             _topImageView.transform = CGAffineTransformMakeTranslation( _topImageView.frame.size.width, 0);
                             _bottomImageView.transform = CGAffineTransformMakeTranslation(0, 0);
                         }else if(mode == KASlideShowSlideModeForward){
                             _topImageView.transform = CGAffineTransformMakeTranslation(- _topImageView.frame.size.width, 0);
                             _bottomImageView.transform = CGAffineTransformMakeTranslation(0, 0);
                         }
                     }
                     completion:^(BOOL finished){
                         
                         _topImageView.image = _bottomImageView.image;
                         _topImageView.transform = CGAffineTransformMakeTranslation(0, 0);
                         
                         _isAnimating = NO;
                         
                         if(! _doStop){
                             [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(next) object:nil];
                             [self performSelector:@selector(next) withObject:nil afterDelay:delay];
                         }
                     }];
}

-(void)animatePanSlideBack:(KASlidePanGestureDirection) mode
{
    [UIView animateWithDuration:transitionDuration/2
                     animations:^{
                         if(mode == KASLidePanLeft){
                             _topImageView.frame = CGRectMake(0, _topImageView.frame.origin.y, _topImageView.frame.size.width, _topImageView.frame.size.height);
                             _bottomImageView.frame = CGRectMake(_bottomImageView.frame.size.width, _bottomImageView.frame.origin.y, _bottomImageView.frame.size.width, _bottomImageView.frame.size.height);
                         }else if(mode == KASlidePanRight){
                             _topImageView.frame = CGRectMake(0, _topImageView.frame.origin.y, _topImageView.frame.size.width, _topImageView.frame.size.height);
                             _bottomImageView.frame = CGRectMake(-_bottomImageView.frame.size.width, _bottomImageView.frame.origin.y, _bottomImageView.frame.size.width, _bottomImageView.frame.size.height);
                         }
                         
                         
                     }
                     completion:^(BOOL finished){
                         
                         
                     }];
    
}

-(void)animatePanSlide:(KASlideShowSlideMode) mode
{
    [UIView animateWithDuration:transitionDuration
                     animations:^{
                         if(mode == KASlideShowSlideModeBackward){
                             _topImageView.frame = CGRectMake(_topImageView.frame.size.width, _topImageView.frame.origin.y, _topImageView.frame.size.width, _topImageView.frame.size.height);
                             _bottomImageView.frame = CGRectMake(0, _bottomImageView.frame.origin.y, _bottomImageView.frame.size.width, _bottomImageView.frame.size.height);
                         }else if(mode == KASlideShowSlideModeForward){
                             _topImageView.frame = CGRectMake(-_topImageView.frame.size.width, _topImageView.frame.origin.y, _topImageView.frame.size.width, _topImageView.frame.size.height);
                             _bottomImageView.frame = CGRectMake(0, _bottomImageView.frame.origin.y, _bottomImageView.frame.size.width, _bottomImageView.frame.size.height);
                         }
                         
                         
                     }
                     completion:^(BOOL finished){
            
                         _topImageView.image = _bottomImageView.image;
                         _topImageView.frame = CGRectMake(0, _topImageView.frame.origin.y, _topImageView.frame.size.width, _topImageView.frame.size.height);
                         
                     }];
    
}



- (void) stop
{
    _doStop = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(next) object:nil];
}

- (KASlideShowState)state
{
    return !_doStop;
}

#pragma mark - Gesture Recognizers initializers
- (void) addGestureTap
{
    UITapGestureRecognizer *singleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    singleTapGestureRecognizer.numberOfTapsRequired = 1;
    [self addGestureRecognizer:singleTapGestureRecognizer];
}

- (void) addGestureSwipe
{
    UISwipeGestureRecognizer* swipeLeftGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    swipeLeftGestureRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
    
    UISwipeGestureRecognizer* swipeRightGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    swipeRightGestureRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
    
    [self addGestureRecognizer:swipeLeftGestureRecognizer];
    [self addGestureRecognizer:swipeRightGestureRecognizer];
}

- (void) addGesturePan
{
    if(transitionType != KASlideShowTransitionFade){
        UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:panGestureRecognizer];
    } else {
        [self addGestureTap];
    }
}

#pragma mark - Gesture Recognizers handling
- (void)handleSingleTap:(id)sender
{
    UITapGestureRecognizer *gesture = (UITapGestureRecognizer *)sender;
    CGPoint pointTouched = [gesture locationInView:self.topImageView];
    
    if (pointTouched.x <= self.topImageView.center.x){
        [self previous];
    }else {
        [self next];
    }
}

- (void) handleSwipe:(id)sender
{
    UISwipeGestureRecognizer *gesture = (UISwipeGestureRecognizer *)sender;
    
    float oldTransitionDuration = self.transitionDuration;
    
    self.transitionDuration = kSwipeTransitionDuration;
    if (gesture.direction == UISwipeGestureRecognizerDirectionLeft)
    {
        [self next];
    }
    else if (gesture.direction == UISwipeGestureRecognizerDirectionRight)
    {
        [self previous];
    }
    
    self.transitionDuration = oldTransitionDuration;
}

-(void)handlePan:(UIPanGestureRecognizer *)sender
{
    
    _isPanGestureSlide = YES;
    KASlidePanGestureDirection panDirection = KASlidePanRight;
    CGPoint velocity = [sender velocityInView:self];
    if(velocity.x < 0){
        panDirection = KASLidePanLeft;
    }
    
    if(!(!repeatable && _currentIndex == 0 && panDirection == KASlidePanRight) && !(!repeatable && _currentIndex == images.count - 1 && panDirection == KASLidePanLeft) ){
        CGPoint translation = [sender translationInView:self.topImageView];
        if(sender.state == UIGestureRecognizerStateChanged){
            
            int startPoint = self.frame.origin.x - self.frame.size.width + translation.x;
            self.topImageView.frame = CGRectMake(translation.x, self.topImageView.frame.origin.y, self.frame.size.width, self.frame.size.height);
            if(panDirection == KASLidePanLeft){
                startPoint = self.frame.size.width + translation.x;
                self.bottomImageView.image = self.images[[self getNextIndex]];
            } else {
                self.bottomImageView.image = self.images[[self getPreviousIndex]];
            }
            self.bottomImageView.frame = CGRectMake(startPoint, self.bottomImageView.frame.origin.y, self.frame.size.width, self.frame.size.height);
            
            
        }
        if(sender.state == UIGestureRecognizerStateEnded){
            
            if(translation.x > self.center.x){
                [self previous];
            } else if(-translation.x > self.center.x){
                [self next];
            } else {
                [self animatePanSlideBack:panDirection];
            }
        }

    }
}

@end

