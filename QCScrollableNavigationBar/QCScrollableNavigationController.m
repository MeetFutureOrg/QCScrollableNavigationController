//
//  QCScrollableNavigationController.m
//  YiBanClient
//
//  Created by Qing Class on 2019/4/28.
//  Copyright © 2019 Qing Class. All rights reserved.
//

#import "QCScrollableNavigationController.h"
#import <WebKit/WebKit.h>


#pragma mark navigation bar follower
@implementation QCNavigationBarFollower

- (instancetype)init {
    if (self = [super init]) {
        _direction = QCNavigationBarFollowerCollapseDirectionScrollUp;
    }
    return self;
}

- (instancetype)initWithView:(UIView *)view direction:(QCNavigationBarFollowerCollapseDirection)direction {
    QCNavigationBarFollower *follower = [self init];
    follower.view = view;
    follower.direction = direction;
    return follower;
}

@end

#pragma mark tabBar mock
@interface _QCScrollableTabBarMock : NSObject

@property (nonatomic) BOOL isTranslucent;
@property (nonatomic) CGPoint origin;

- (instancetype)initWithOrigin:(CGPoint)origin translucent:(BOOL)translucent;

@end

@implementation _QCScrollableTabBarMock

- (instancetype)init {
    self = [super init];
    if (self) {
        _origin = CGPointZero;
        _isTranslucent = NO;
    }
    return self;
}

- (instancetype)initWithOrigin:(CGPoint)origin translucent:(BOOL)translucent {
    _QCScrollableTabBarMock *_mock = [self init];
    _mock.origin = origin;
    _mock.isTranslucent = translucent;
    return _mock;
}

@end


#pragma mark QCScrollableNavigationController
@interface QCScrollableNavigationController ()

//MARK: - 导航视图 sizing
@property (nonatomic, readonly) CGFloat fullTopBarHeight;
@property (nonatomic, readonly) CGFloat navigationBarHeight;
@property (nonatomic, readonly) CGFloat statusBarHeight;
@property (nonatomic, readonly) CGFloat extendedStatusBarDifferences;
@property (nonatomic, readonly) CGFloat tabBarOffset;
@property (nonatomic, readonly) CGPoint contentOffset;
@property (nonatomic, readonly) CGSize contentSize;
@property (nonatomic, readonly) CGFloat navigationBarFullHeight;
@property (nonatomic) _QCScrollableTabBarMock *sourceTabBar;
@property (nonatomic) UIDeviceOrientation previousOrientation;

@property (nonatomic) CGFloat delayDistance;
@property (nonatomic) CGFloat maxDelay;
@property (nullable, nonatomic) UIView *scrollableView;
@property (nonatomic) CGFloat lastContentOffset;
@property (nonatomic) CGFloat scrollSpeedFactor;
@property (nonatomic) CGFloat collapseDirectionFactor;
@property (nonatomic) QCScrollableNavigationBarState previousState;

@property (nullable, nonatomic, readwrite) UIPanGestureRecognizer *gestureRecognizer;

- (nullable UIScrollView *)scrollView;

@end

@implementation QCScrollableNavigationController

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController {
    if (self = [super initWithRootViewController:rootViewController]) {
        self.shouldScrollWhenContentFits = NO;
        self.expandOnActive = YES;
        self.scrollingEnabled = YES;
        self.followers = [NSMutableArray array];
        self.shouldUpdateContentInset = YES;
        self.shouldScrollWhenTableViewIsEditing = NO;
        self.additionalOffset = 0;
        
        self.previousOrientation = [UIDevice currentDevice].orientation;
        self.delayDistance = 0;
        self.maxDelay = 0;
        self.lastContentOffset = 0;
        self.scrollSpeedFactor = 1.0;
        self.collapseDirectionFactor = 1;
        self.previousState = QCScrollableNavigationBarStateExpanded;
    }
    return self;
}

#pragma mark - 便捷方法
- (void)followScrollView:(UIView *)scrollableView {
    [self followScrollView:scrollableView delay:0.0 scrollSpeedFactor:1.0 collapseDirection:QCNavigationBarCollapseDirectionScrollDown additionalOffset:0 followers:@[]];
}

- (void)followScrollView:(UIView *)scrollableView
        additionalOffset:(CGFloat)additionalOffset {
    [self followScrollView:scrollableView delay:0 additionalOffset:additionalOffset];
}

- (void)followScrollView:(UIView *)scrollableView
                   delay:(CGFloat)delay {
    [self followScrollView:scrollableView delay:delay additionalOffset:0];
}

- (void)followScrollView:(UIView *)scrollableView
                   delay:(CGFloat)delay
        additionalOffset:(CGFloat)additionalOffset {
    [self followScrollView:scrollableView delay:delay additionalOffset:additionalOffset followers:@[]];
}

- (void)followScrollView:(UIView *)scrollableView
               followers:(NSArray<QCNavigationBarFollower *> *)followers {
    [self followScrollView:scrollableView delay:0 followers:followers];
}

- (void)followScrollView:(UIView *)scrollableView
                   delay:(CGFloat)delay
               followers:(NSArray<QCNavigationBarFollower *> *)followers {
    [self followScrollView:scrollableView delay:delay additionalOffset:0 followers:followers];
}

- (void)followScrollView:(UIView *)scrollableView
                   delay:(CGFloat)delay
        additionalOffset:(CGFloat)additionalOffset
               followers:(NSArray<QCNavigationBarFollower *> *)followers {
    [self followScrollView:scrollableView delay:delay scrollSpeedFactor:1.0 collapseDirection:QCNavigationBarCollapseDirectionScrollDown additionalOffset:additionalOffset followers:followers];
}

#pragma mark - 入口
- (void)followScrollView:(UIView *)scrollableView
                   delay:(CGFloat)delay
       scrollSpeedFactor:(CGFloat)scrollSpeedFactor
       collapseDirection:(QCNavigationBarCollapseDirection)collapseDirection
        additionalOffset:(CGFloat)additionalOffset
               followers:(NSArray<QCNavigationBarFollower *> *)followers {
    if (self.scrollableView) {
        // 恢复之前的状态.
        // 在 view 改变的时候 UIKit 会把 navbar 存储它的整个高度
        // (e.g. 在 modal 时)
        // 一旦 UIKit 做那些工作, 我们就需要恢复它的状态
        switch (self.previousState) {
            case QCScrollableNavigationBarStateCollapsed:
                [self hideNavigationBar:NO];
                break;
            case QCScrollableNavigationBarStateExpanded:
                [self showNavigationBar:NO];
                break;
            default:
                break;
        }
        return;
    }
    
    self.scrollableView = scrollableView;
    
    self.gestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    self.gestureRecognizer.maximumNumberOfTouches = 1;
    self.gestureRecognizer.delegate = self;
    self.gestureRecognizer.cancelsTouchesInView = NO;
    [scrollableView addGestureRecognizer:self.gestureRecognizer];
    
    self.previousOrientation = [UIDevice currentDevice].orientation;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRotate:) name:UIDeviceOrientationDidChangeNotification object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeVisible:) name:UIWindowDidBecomeVisibleNotification object:nil];
    
    self.maxDelay = delay;
    self.delayDistance = delay;
    self.scrollingEnabled = YES;
    self.additionalOffset = additionalOffset;
    
    // 保存 tabbar 状态
    if (followers.count > 0) {
        NSMutableArray<UIView *> *tabs = [NSMutableArray arrayWithCapacity:followers.count];
        for (QCNavigationBarFollower *follower in followers) {
            [tabs addObject:follower.view];
        }
        
        if (tabs.firstObject) {
            if ([tabs.firstObject isKindOfClass:[UITabBar class]]) {
                UITabBar *tabbar = (UITabBar *)tabs.firstObject;
                self.sourceTabBar = [[_QCScrollableTabBarMock alloc] initWithOrigin:CGPointMake(tabbar.frame.origin.x, round(tabbar.frame.origin.y)) translucent:tabbar.isTranslucent];
            }
        }
        self.followers = [followers mutableCopy];
    }
    
    self.scrollSpeedFactor = scrollSpeedFactor > 0 ? scrollSpeedFactor : 1.0;
    self.collapseDirectionFactor = (CGFloat)collapseDirection;
}

- (void)hideNavigationBar {
    [self hideNavigationBar:YES];
}

- (void)hideNavigationBar:(BOOL)animated {
    [self hideNavigationBar:animated duration:0.1];
}

- (void)hideNavigationBar:(BOOL)animated duration:(NSTimeInterval)duration {
    if (!self.scrollableView && !self.visibleViewController) {
        return;
    }
    
    if (self.state != QCScrollableNavigationBarStateExpanded) {
        [self _updateNavigationbarAlpha];
        return;
    }
    
    self.gestureRecognizer.enabled = NO;
    
    void(^animations)(void) = ^(void) {
        [self _scrollWithDelta:self.fullTopBarHeight ignoreDelay:YES];
        [self.visibleViewController.view setNeedsLayout];
        if (self.navigationBar.isTranslucent) {
            CGPoint currentOffset = self.contentOffset;
            if ([self scrollView]) {
                [[self scrollView] setContentOffset:CGPointMake(currentOffset.x, currentOffset.y + self.navigationBarHeight)];
            }
        }
    };
    
    if (animated) {
        [UIView animateWithDuration:duration animations:animations completion:^(BOOL finished) {
            self.gestureRecognizer.enabled = YES;
        }];
    } else {
        animations();
        self.gestureRecognizer.enabled = YES;
    }
}

- (void)showNavigationBar {
    [self showNavigationBar:YES];
}

- (void)showNavigationBar:(BOOL)animated {
    [self showNavigationBar:animated duration:0.1];
}

- (void)showNavigationBar:(BOOL)animated duration:(NSTimeInterval)duration {
    if (!self.scrollableView && !self.visibleViewController) {
        return;
    }
    
    if (self.state != QCScrollableNavigationBarStateCollapsed) {
        [self _updateNavigationbarAlpha];
        return;
    }
    
    self.gestureRecognizer.enabled = NO;
    
    void(^animations)(void) = ^(void) {
        self.lastContentOffset = 0;
        [self _scrollWithDelta:-self.fullTopBarHeight ignoreDelay:YES];
        [self.visibleViewController.view setNeedsLayout];
        if (self.navigationBar.isTranslucent) {
            CGPoint currentOffset = self.contentOffset;
            if ([self scrollView]) {
                [[self scrollView] setContentOffset:CGPointMake(currentOffset.x, currentOffset.y - self.navigationBarHeight)];
            }
        }
    };
    
    if (animated) {
        [UIView animateWithDuration:duration animations:animations completion:^(BOOL finished) {
            self.gestureRecognizer.enabled = YES;
        }];
    } else {
        animations();
        self.gestureRecognizer.enabled = YES;
    }
}

- (void)stopFollowingScrollView {
    [self stopFollowingScrollView:YES];
}

- (void)stopFollowingScrollView:(BOOL)showingNavbar {
    if (showingNavbar) {
        [self showNavigationBar:YES];
    }
    
    if (self.gestureRecognizer) {
        if (self.scrollableView) {
            [self.scrollableView removeGestureRecognizer:self.gestureRecognizer];
        }
    }
    
    self.scrollableView = nil;
    self.gestureRecognizer = nil;
    self.scrollableDelegate = nil;
    self.scrollingEnabled = NO;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
}


- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if ([self.scrollableView isKindOfClass:[UITableView class]]) {
        if (!self.shouldScrollWhenTableViewIsEditing && ((UITableView *)self.scrollableView).isEditing) {
            return;
        }
    }
    
    if (self.scrollableView.superview) {
        UIView *superView = self.scrollableView.superview;
        CGPoint translation = [gesture translationInView:superView];
        CGFloat delta = (self.lastContentOffset - translation.y) / self.scrollSpeedFactor;
        
        if (![self _checkSearchController:delta]) {
            self.lastContentOffset = translation.y;
            return;
        }
        
        if (gesture.state != UIGestureRecognizerStateFailed) {
            self.lastContentOffset = translation.y;
            if ([self _shouldScrollWithDelta:delta]) {
                [self _scrollWithDelta:delta ignoreDelay:NO];
            }
        }
    }
    
    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled || gesture.state == UIGestureRecognizerStateFailed) {
        [self _checkForPartialScroll];
        self.lastContentOffset = 0;
    }
}

- (void)windowDidBecomeVisible:(NSNotification *)notification {
    [self showNavigationBar];
}

- (void)didRotate:(NSNotification *)notification {
    UIDeviceOrientation newOrientation = [UIDevice currentDevice].orientation;
    if ((self.previousOrientation == newOrientation) ||
        (UIDeviceOrientationIsPortrait(self.previousOrientation) && UIDeviceOrientationIsLandscape(newOrientation)) ||
        (UIDeviceOrientationIsLandscape(self.previousOrientation) && UIDeviceOrientationIsPortrait(newOrientation))) {
        [self showNavigationBar];
    }
    
    self.previousOrientation = newOrientation;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self showNavigationBar];
}

- (void)didBecomeActive:(NSNotification *)notification {
    if (self.expandOnActive) {
        [self showNavigationBar:false];
    } else {
        if (self.previousState == QCScrollableNavigationBarStateExpanded) {
            [self hideNavigationBar:NO];
        }
    }
}

- (void)willResignActive:(NSNotification *)notfication {
    self.previousState = self.state;
}

- (void)willChangeStatusBar {
    [self showNavigationBar:YES];
}


/// 检查是否可滚动
- (BOOL)_shouldScrollWithDelta:(CGFloat)delta {
    CGFloat scrollDelta = delta;
    if (self.contentOffset.y < (self.navigationBar.isTranslucent ? -self.fullTopBarHeight : 0) + scrollDelta) {
        return NO;
    }
    if (scrollDelta < 0) {
        if (self.scrollableView) {
            if (self.contentOffset.y + self.scrollableView.frame.size.height > self.contentSize.height && self.scrollableView.frame.size.height < self.contentSize.height) {
                // Only if the content is big enough
                return NO;
            }
        }
    }
    return YES;
}

/// 滚动导航的方法
- (void)_scrollWithDelta:(CGFloat)delta ignoreDelay:(BOOL)ignoreDelay {
    CGFloat scrollDelta = delta;
    CGRect frame = self.navigationBar.frame;
    
    // 视图向上滚动, 隐藏导航bar
    if (scrollDelta > 0) {
        
        /// 更新延迟量
        if (!ignoreDelay) {
            self.delayDistance -= scrollDelta;
            
            // 如果延迟量还没到, 那么跳过
            if (self.delayDistance > 0) {
                return;
            }
        }
        
        /// 如果内容合适, 不滚动
        if (!self.shouldScrollWhenContentFits && self.state != QCScrollableNavigationBarStateCollapsed && self.scrollableView.frame.size.height >= self.contentSize.height) {
            return;
        }
        
        // 计算导航 bar 的位置
        if (frame.origin.y - scrollDelta < -self.navigationBarFullHeight) {
            scrollDelta = frame.origin.y + self.navigationBarFullHeight;
        }
        
        // 检测导航 bar 是否完全收缩 (collapsed)
        if (frame.origin.y <= -self.navigationBarFullHeight) {
            self.delayDistance = self.maxDelay;
        }
    }
    
    /// 向下滚动视图, 伸开导航 bar
    if (scrollDelta < 0) {
        /// 更新延迟量
        if (!ignoreDelay) {
            self.delayDistance += scrollDelta;
            
            // 如果延迟量没到, 那么跳过
            if (self.delayDistance > 0 && self.maxDelay < self.contentOffset.y) {
                return;
            }
        }
        
        // 计算导航 bar 的位置
        if (frame.origin.y - scrollDelta > self.statusBarHeight) {
            scrollDelta = frame.origin.y - self.statusBarHeight;
        }
        
        // 检测导航 bar 是否完全伸开
        if (frame.origin.y >= self.statusBarHeight) {
            self.delayDistance = self.maxDelay;
        }
    }
    
    [self _updateSizing:scrollDelta];
    [self _updateNavigationbarAlpha];
    [self _restoreContentOffset:scrollDelta];
    [self _updateFollowers];
    [self _updateContentInset:scrollDelta];
    
    QCScrollableNavigationBarState newState = self.state;
    if (newState != self.previousState) {
        if ([self.scrollableDelegate respondsToSelector:@selector(scrollableNavigationController:willChangeState:)]) {
            [self.scrollableDelegate scrollableNavigationController:self willChangeState:newState];
            self.navigationBar.userInteractionEnabled = (newState == QCScrollableNavigationBarStateExpanded);
        }
    }
    
    self.previousState = newState;
}

- (void)_updateContentInset:(CGFloat)delta {
    if (self.shouldUpdateContentInset) {
        if ([self scrollView]) {
            UIEdgeInsets contentInset = [self scrollView].contentInset;
            UIEdgeInsets scrollIndicatorInsets = [self scrollView].scrollIndicatorInsets;
            [[self scrollView] setContentInset:UIEdgeInsetsMake(contentInset.top - delta, contentInset.left, contentInset.bottom, contentInset.right)];
            [[self scrollView] setScrollIndicatorInsets:UIEdgeInsetsMake(scrollIndicatorInsets.top - delta, scrollIndicatorInsets.left, scrollIndicatorInsets.bottom, scrollIndicatorInsets.right)];
            if ([self.scrollableDelegate respondsToSelector:@selector(scrollableNavigationController:didUpdateOffset:forStateChange:)]) {
                [self.scrollableDelegate scrollableNavigationController:self didUpdateOffset:contentInset.top - delta forStateChange:self.state];
            }
        }
    }
}

- (void)_updateFollowers {
    if (self.followers.count <= 0) {
        return;
    }
    
    for (QCNavigationBarFollower *follower in self.followers) {
        if (![follower.view isKindOfClass:[UITabBar class]]) {
            CGFloat height = follower.view.frame.size.height;
            CGFloat safeArea = 0;
            if (@available(iOS 11.0, *)) {
                safeArea = (follower.direction == QCNavigationBarFollowerCollapseDirectionScrollDown) ? self.topViewController.view.safeAreaInsets.bottom : 0;
            }
            
            switch (follower.direction) {
                case QCNavigationBarFollowerCollapseDirectionScrollDown:
                    follower.view.transform = CGAffineTransformMakeTranslation(0, self.percentage * (height + safeArea));
                    break;
                case QCNavigationBarFollowerCollapseDirectionScrollUp:
                    follower.view.transform = CGAffineTransformMakeTranslation(0, -(self.statusBarHeight - self.navigationBar.frame.origin.y));
                    break;
            }
            return;
        }
        
        UITabBar *tabBar = (UITabBar *)follower;
        tabBar.translucent = YES;
        tabBar.transform = CGAffineTransformMakeTranslation(0, self.percentage * tabBar.frame.size.height);
        
        // tabbar 恢复状态
        if (self.sourceTabBar && self.sourceTabBar.origin.y == round(tabBar.frame.origin.y)) {
            tabBar.translucent = self.sourceTabBar.isTranslucent;
        }
    }
}

- (void)_updateSizing:(CGFloat)delta {
    if (!self.topViewController) {
        return;
    }
    
    CGRect frame = self.navigationBar.frame;
    
    // 移动导航 bar
    frame.origin = CGPointMake(frame.origin.x, frame.origin.y - delta);
    self.navigationBar.frame = frame;
    
    if (!self.navigationBar.isTranslucent) {
        CGFloat navBarY = self.navigationBar.frame.origin.y + self.navigationBar.frame.size.height;
        frame = self.topViewController.view.frame;
        frame.origin = CGPointMake(frame.origin.x, navBarY);
        frame.size = CGSizeMake(frame.size.width, self.view.frame.size.height - (navBarY) - self.tabBarOffset);
        self.topViewController.view.frame = frame;
    }
}

- (void)_restoreContentOffset:(CGFloat)delta {
    if (self.navigationBar.isTranslucent || delta == 0) {
        return;
    }
    
    if ([self scrollView]) {
        [[self scrollView] setContentOffset:CGPointMake(self.contentOffset.x, self.contentOffset.y - delta) animated:NO];
    }
}

- (void)_checkForPartialScroll {
    CGRect frame = self.navigationBar.frame;
    NSTimeInterval duration = 0;
    CGFloat delta = 0;
    CGFloat navBarHeightWithOffset = frame.size.height + self.additionalOffset;
    
    // 滚下去
    CGFloat threshold = self.statusBarHeight - (navBarHeightWithOffset / 2);
    if (self.navigationBar.frame.origin.y >= threshold) {
        delta = frame.origin.y - self.statusBarHeight;
        CGFloat distance = delta / (navBarHeightWithOffset / 2);
        duration = (NSTimeInterval)fabs(distance * 0.2);
        if ([self.scrollableDelegate respondsToSelector:@selector(scrollableNavigationController:willChangeState:)]) {
            [self.scrollableDelegate scrollableNavigationController:self willChangeState:self.state];
        }
    } else {
        // 滚上去
        delta = frame.origin.y + self.navigationBarFullHeight;
        CGFloat distance = delta / (navBarHeightWithOffset / 2);
        duration = (NSTimeInterval)fabs(distance * 0.2);
        if ([self.scrollableDelegate respondsToSelector:@selector(scrollableNavigationController:willChangeState:)]) {
            [self.scrollableDelegate scrollableNavigationController:self willChangeState:self.state];
        }
    }
    
    self.delayDistance = self.maxDelay;
    
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        [self _updateSizing:delta];
        [self _updateFollowers];
        [self _updateNavigationbarAlpha];
        [self _updateContentInset:delta];
    } completion:^(BOOL finished) {
        self.navigationBar.userInteractionEnabled = (self.state == QCScrollableNavigationBarStateExpanded);
        if ([self.scrollableDelegate respondsToSelector:@selector(scrollableNavigationController:didChangeState:)]) {
            [self.scrollableDelegate scrollableNavigationController:self didChangeState:self.state];
        }
    }];
}

- (BOOL)_checkSearchController:(CGFloat)delta {
    if (@available(iOS 11.0, *)) {
        if (self.topViewController.navigationItem.searchController && delta > 0) {
            if (self.topViewController.navigationItem.searchController.searchBar.frame.size.height != 0) {
                return NO;
            }
        }
    }
    return YES;
}


/// 更新导航的透明度
- (void)_updateNavigationbarAlpha {
    UINavigationItem *navigationItem = self.topViewController.navigationItem;
    if (!navigationItem) {
        return;
    }
    
    CGFloat alpha = 1.0 - self.percentage;
    
    navigationItem.titleView.alpha = alpha;
    self.navigationBar.tintColor = [self.navigationBar.tintColor colorWithAlphaComponent:alpha];
    navigationItem.leftBarButtonItem.tintColor = [navigationItem.leftBarButtonItem.tintColor colorWithAlphaComponent:alpha];
    navigationItem.rightBarButtonItem.tintColor = [navigationItem.rightBarButtonItem.tintColor colorWithAlphaComponent:alpha];
    for (UIBarButtonItem *item in navigationItem.leftBarButtonItems) {
        item.tintColor = [item.tintColor colorWithAlphaComponent:alpha];
    }
    
    for (UIBarButtonItem *item in navigationItem.rightBarButtonItems) {
        item.tintColor = [item.tintColor colorWithAlphaComponent:alpha];
    }
    
    UIColor *titleColor = self.navigationBar.titleTextAttributes[NSForegroundColorAttributeName];
    if (titleColor) {
        [self.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName: [titleColor colorWithAlphaComponent:alpha]}];
    } else {
        UIColor *blackAlpha = [[UIColor blackColor] colorWithAlphaComponent:alpha];
        [self.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName: blackAlpha}];
    }
    
    NSMutableArray<UIView *> *views = [NSMutableArray array];
    for (UIView *subview in self.navigationBar.subviews) {
        if ([self _shouldHideView:subview]) {
            [views addObject:subview];
        }
    }
    
    for (UIView *v in views) {
        [self _setAlphaOfSubviews:v alpha:alpha];
    }
    
    navigationItem.leftBarButtonItem.customView.alpha = alpha;
    for (UIBarButtonItem *item in navigationItem.leftBarButtonItems) {
        item.customView.alpha = alpha;
    }
    
    navigationItem.rightBarButtonItem.customView.alpha = alpha;
    for (UIBarButtonItem *item in navigationItem.rightBarButtonItems) {
        item.customView.alpha = alpha;
    }
}

- (BOOL)_shouldHideView:(UIView *)view {
    NSString *className = [[[view classForCoder] description] stringByReplacingOccurrencesOfString:@"_" withString:@""];
    NSMutableArray<NSString *> *viewNames = [NSMutableArray arrayWithObjects:@"UINavigationButton", @"UINavigationItemView", @"UIImageView", @"UISegmentedControl", nil];
    
    if (@available(iOS 11.0, *)) {
        [viewNames addObject:self.navigationBar.prefersLargeTitles ? @"UINavigationBarLargeTitleView" : @"UINavigationBarContentView"];
    } else {
        [viewNames addObject:@"UINavigationBarContentView"];
    }
    
    return [viewNames containsObject:className];
}

- (void)_setAlphaOfSubviews:(UIView *)view alpha:(CGFloat)alpha {
    if ([view isKindOfClass:[UILabel class]]) {
        ((UILabel *)view).textColor = [((UILabel *)view).textColor colorWithAlphaComponent:alpha];
    } else if ([view isKindOfClass:[UITextField class]]) {
        ((UITextField *)view).textColor = [((UITextField *)view).textColor colorWithAlphaComponent:alpha];
    } else if ([view classForCoder] == NSClassFromString(@"_UINavigationBarContentView")) {
        // do nothing
    } else {
        view.alpha = alpha;
    }
    for (UIView *subview in view.subviews) {
        [self _setAlphaOfSubviews:subview alpha:alpha];
    }
}


- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (![gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        return YES;
    }
    UIPanGestureRecognizer *panGesture = (UIPanGestureRecognizer *)gestureRecognizer;
    CGPoint velocity = [panGesture velocityInView:panGesture.view];
    return fabs(velocity.y) > fabs(velocity.x);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return self.scrollingEnabled;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

//MARK: - 为 navigation bar 返回 QCScrollableNavigationBarState
- (QCScrollableNavigationBarState)state {
    if (self.navigationBar.frame.origin.y <= -self.navigationBarFullHeight) {
        return QCScrollableNavigationBarStateCollapsed;
    } else if (self.navigationBar.frame.origin.y >= self.statusBarHeight) {
        return QCScrollableNavigationBarStateExpanded;
    } else {
        return QCScrollableNavigationBarStateScrolling;
    }
}

- (CGFloat)percentage {
    return (self.navigationBar.frame.origin.y - self.statusBarHeight) / (-self.navigationBarFullHeight - self.statusBarHeight);
}



//MARK: - 导航视图 sizing getter 方法
- (CGFloat)fullTopBarHeight {
    return self.navigationBarHeight + self.statusBarHeight;
}

- (CGFloat)navigationBarHeight {
    return self.navigationBar.frame.size.height;
}

- (CGFloat)statusBarHeight {
    CGFloat statusBar_Height = [UIApplication sharedApplication].statusBarFrame.size.height;
    if (@available(iOS 11.0, *)) {
        statusBar_Height = MAX([UIApplication sharedApplication].statusBarFrame.size.height, [UIApplication sharedApplication].delegate.window.safeAreaInsets.top ?: 0);
    }
    return MAX(statusBar_Height - self.extendedStatusBarDifferences, 0);
}

- (CGFloat)extendedStatusBarDifferences {
    return fabs(self.view.bounds.size.height - ([UIApplication sharedApplication].delegate.window.frame.size.height ?: [UIScreen mainScreen].bounds.size.height));
}

- (CGFloat)tabBarOffset {
    if (self.tabBarController && !self.topViewController.hidesBottomBarWhenPushed) {
        return self.tabBarController.tabBar.isTranslucent ? 0 : self.tabBarController.tabBar.frame.size.height;
    }
    return 0.0;
}

- (UIScrollView *)scrollView {
    if ([self.scrollableView isKindOfClass:[UIWebView class]]) {
        return ((UIWebView *)self.scrollableView).scrollView;
    } else if ([self.scrollableView isKindOfClass:[WKWebView class]]) {
        return ((WKWebView *)self.scrollableView).scrollView;
    } else if ([self.scrollableView isKindOfClass:[UIScrollView class]]) {
        return (UIScrollView *)self.scrollableView;
    } else {
        return nil;
    }
}

- (CGPoint)contentOffset {
    return [self scrollView] ? [self scrollView].contentOffset : CGPointZero;
}

- (CGSize)contentSize {
    UIScrollView *scrollView = [self scrollView];
    if (!scrollView) {
        return CGSizeZero;
    }
    
    CGFloat verticalInset = scrollView.contentInset.top + scrollView.contentInset.bottom;
    return CGSizeMake(scrollView.contentSize.width, scrollView.contentSize.height + verticalInset);
}

- (CGFloat)navigationBarFullHeight {
    return self.navigationBarHeight - self.statusBarHeight + self.additionalOffset;
}

@end



