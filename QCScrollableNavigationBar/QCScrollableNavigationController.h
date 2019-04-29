//
//  QCScrollableNavigationController.h
//  YiBanClient
//
//  Created by Qing Class on 2019/4/28.
//  Copyright © 2019 Qing Class. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN


/**
 导航栏的状态

 - QCScrollableNavigationBarStateCollapsed: 收起
 - QCScrollableNavigationBarStateExpanded: 展开
 - QCScrollableNavigationBarStateScrolling: 滚动中(导航栏出于滚动中, 非下边的滚动视图)
 */
typedef NS_ENUM(NSInteger, QCScrollableNavigationBarState) {
    QCScrollableNavigationBarStateCollapsed,
    QCScrollableNavigationBarStateExpanded,
    QCScrollableNavigationBarStateScrolling,
};


/**
 导航栏收起的方向

 - QCNavigationBarCollapseDirectionScrollUp: 滚上去
 - QCNavigationBarCollapseDirectionScrollDown: 滚下来
 */
typedef NS_ENUM(NSInteger, QCNavigationBarCollapseDirection) {
    QCNavigationBarCollapseDirectionScrollUp = -1,
    QCNavigationBarCollapseDirectionScrollDown = 1,
};


/**
 导航栏追随者的收起方向
 例如: UIToolBar, UITabBar 等

 - QCNavigationBarFollowerCollapseDirectionScrollUp: 滚上去
 - QCNavigationBarFollowerCollapseDirectionScrollDown: 滚下来
 */
typedef NS_ENUM(NSInteger, QCNavigationBarFollowerCollapseDirection) {
    QCNavigationBarFollowerCollapseDirectionScrollUp = -1,
    QCNavigationBarFollowerCollapseDirectionScrollDown = 1,
};

@class QCScrollableNavigationController;


/**
 捕捉导航栏状态改变的协议
 */
@protocol QCScrollableNavigationControllerDelegate <NSObject>

@optional

/**
 将要改变状态时调用此方法

 @param controller 当前 QCScrollableNavigationController or 其子类
 @param state 当前所处的状态
 */
- (void)scrollableNavigationController:(QCScrollableNavigationController *)controller
                       willChangeState:(QCScrollableNavigationBarState)state;


/**
 已经改变完状态时调用完成方法

 @param controller 当前 QCScrollableNavigationController or 其子类
 @param state 当前所处的状态
 */
- (void)scrollableNavigationController:(QCScrollableNavigationController *)controller
                        didChangeState:(QCScrollableNavigationBarState)state;


/**
 已经更新完偏移量时会调用此方法

 @param controller 当前 QCScrollableNavigationController or 其子类
 @param offset 更新的偏移量
 @param state 当前所处的状态
 */
- (void)scrollableNavigationController:(QCScrollableNavigationController *)controller
                       didUpdateOffset:(CGFloat)offset
                        forStateChange:(QCScrollableNavigationBarState)state;

@end


/**
 滚动导航栏追随者的抽象类
 */
@interface QCNavigationBarFollower : NSObject

/**
 追随者(UIView或其子类), 可选
 */
@property (nullable, nonatomic, weak) UIView *view;

/**
 滚动收起方向, 默认: QCNavigationBarFollowerCollapseDirectionScrollUp, 向上
 */
@property (nonatomic) QCNavigationBarFollowerCollapseDirection direction;

/**
 初始化方法

 @param view 追随者
 @param direction 滚动收起方向
 @return the instance
 */
- (instancetype)initWithView:(UIView *)view direction:(QCNavigationBarFollowerCollapseDirection)direction;

@end



/**
 滚动导航控制器
 若想实现滚动的导航, 必须使用此类, 或继承此类
 必须利用 -initWithRootViewController: 方法进行初始化, -init 或其他初始化方式不生效
 */
@interface QCScrollableNavigationController : UINavigationController <UIGestureRecognizerDelegate>

/**
 导航 bar 的状态
 */
@property (nonatomic) QCScrollableNavigationBarState state;

/**
 当前可滚动的视图不是足够长时是否允许导航滚动, 默认 NO
 不足够长: contentSize <= 当前的 frame.size
 */
@property (nonatomic) BOOL shouldScrollWhenContentFits;

/**
 当 app 从后台返回时是否展开导航 bar, 默认 YES
 */
@property (nonatomic) BOOL expandOnActive;

/**
 滚动功能是否开启, 默认 YES
 */
@property (nonatomic) BOOL scrollingEnabled;

/**
 导航状态改变的通知的代理
 */
@property (nullable, nonatomic, weak) id<QCScrollableNavigationControllerDelegate> scrollableDelegate;

/**
 追随者数组
 */
@property (nonatomic) NSMutableArray<QCNavigationBarFollower *> *followers;

/**
 是否需要更新滚动视图的内容缩进, 默认 YES
 */
@property (nonatomic) BOOL shouldUpdateContentInset;

/**
 当 UITableView 处于编辑状态时是否可滚动, 默认 NO
 */
@property (nonatomic) BOOL shouldScrollWhenTableViewIsEditing;

/**
 导航栏偏移量百分比
 */
@property (nonatomic, readonly) CGFloat percentage;

/**
 额外增加的导航栏偏移量, 默认 0, 即完全收起
 正值(positive value)意味着增加收起的量(会延伸到安全区域或状态栏内)
 负值(negative value)意味着不会完整收起导航栏的高度
 */
@property (nonatomic) CGFloat additionalOffset;

/**
 在滚动视图上添加的滑动手势用于控制导航栏的滚动, 可为空
 */
@property (nullable, nonatomic, readonly) UIPanGestureRecognizer *gestureRecognizer;


/**
 便捷方法 1
 */
- (void)followScrollView:(UIView *)scrollableView;
/**
 便捷方法 2
 */
- (void)followScrollView:(UIView *)scrollableView
        additionalOffset:(CGFloat)additionalOffset;
/**
 便捷方法 3
 */
- (void)followScrollView:(UIView *)scrollableView
                   delay:(CGFloat)delay;
/**
 便捷方法 4
 */
- (void)followScrollView:(UIView *)scrollableView
                   delay:(CGFloat)delay
        additionalOffset:(CGFloat)additionalOffset;
/**
 便捷方法 5
 */
- (void)followScrollView:(UIView *)scrollableView
               followers:(NSArray<QCNavigationBarFollower *> *)followers;
/**
 便捷方法 6
 */
- (void)followScrollView:(UIView *)scrollableView
                   delay:(CGFloat)delay
               followers:(NSArray<QCNavigationBarFollower *> *)followers;;
/**
 便捷方法 7
 */
- (void)followScrollView:(UIView *)scrollableView
                   delay:(CGFloat)delay
        additionalOffset:(CGFloat)additionalOffset
               followers:(NSArray<QCNavigationBarFollower *> *)followers;
/**
 入口方法

 @param scrollableView 滚动的视图
 @param delay 延迟量, 用于滚动时不希望在滚动视图开始滚动就调整导航栏, 默认 0, 即完全跟随滚动视图的偏移量
 @param scrollSpeedFactor 滚动速度因子, 默认1.0, 若<=0, 则为默认值, 此值影响导航栏的滚动速率
 @param collapseDirection 收起方向, 默认 QCNavigationBarCollapseDirectionScrollDown, 向下
 @param additionalOffset 额外增加的导航栏偏移量, 默认 0, 即完全收起
 @param followers 追随者, 若没有可传递一个空数组
 */
- (void)followScrollView:(UIView *)scrollableView
                   delay:(CGFloat)delay
       scrollSpeedFactor:(CGFloat)scrollSpeedFactor
       collapseDirection:(QCNavigationBarCollapseDirection)collapseDirection
        additionalOffset:(CGFloat)additionalOffset
               followers:(NSArray<QCNavigationBarFollower *> *)followers;


/**
 convenience method, animated 默认 YES
 */
- (void)hideNavigationBar;
/**
 convenience method, duration 默认 0.1s
 */
- (void)hideNavigationBar:(BOOL)animated;

/**
 隐藏 navigation bar 方法

 @param animated 是否开启动画
 @param duration 动画时长
 */
- (void)hideNavigationBar:(BOOL)animated duration:(NSTimeInterval)duration;


/**
 convenience method, animated 默认 YES
 */
- (void)showNavigationBar;

/**
 convenience method, duration 默认 0.1s
 */
- (void)showNavigationBar:(BOOL)animated;

/**
 显示 navigation bar 方法

 @param animated 是否开启动画
 @param duration 动画时长
 */
- (void)showNavigationBar:(BOOL)animated duration:(NSTimeInterval)duration;


/**
 convenience method, showingNavbar 默认 YES
 */
- (void)stopFollowingScrollView;

/**
 导航栏停止跟随滚动视图滚动

 @param showingNavbar 停止时是否显示导航 bar, 默认 YES
 */
- (void)stopFollowingScrollView:(BOOL)showingNavbar;

@end



NS_ASSUME_NONNULL_END
