//
//  UIView+DJRepeatClickFilter.m
//  TestClickQuickly
//
//  Created by Dokay on 2017/9/25.
//  Copyright © 2017年 dj226. All rights reserved.
//

#import "UIView+DJRepeatClickFilter.h"
#import <objc/runtime.h>

static BOOL bCanTap = NO;
static NSMutableDictionary *hookTableClassesCache;
static NSMutableDictionary *hookCollectionClassesCache;

static DJRepeatClickOtherFilter _otherFilter;


NS_INLINE void DJ_methodSwizzle_new(Class originalClass, SEL originalSelector, Class swizzledClass, SEL swizzledSelector, BOOL isInstanceMethod)
{
    Method (*class_getMethod)(Class, SEL) = &class_getInstanceMethod;
    if (!isInstanceMethod) {
        class_getMethod = &class_getClassMethod;
        originalClass = object_getClass(originalClass);
        swizzledClass = object_getClass(swizzledClass);
    }
    Method originalMethod = class_getMethod(originalClass, originalSelector);
    Method swizzledMethod = class_getMethod(swizzledClass, swizzledSelector);
    if (class_addMethod(originalClass, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
        class_replaceMethod(originalClass, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

NS_INLINE void DJ_methodSwizzle(Class aClass, SEL originalSelector, SEL swizzledSelector, BOOL isInstanceMethod)
{
    DJ_methodSwizzle_new(aClass, originalSelector, aClass, swizzledSelector, isInstanceMethod);
}

NS_INLINE BOOL DJ_addSwizzleMethod(Class aClass, SEL swizzledSelector)
{
    Method swizzledMethod = class_getInstanceMethod(aClass, swizzledSelector);
    BOOL addMethodResult = class_addMethod(aClass, swizzledSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    return addMethodResult;
}

@implementation NSObject (DJRepeatClickFilter)

+ (void)setOtherFilter:(DJRepeatClickOtherFilter)otherFilter
{
    _otherFilter = otherFilter;
}

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (DJRepeatClickFilterEnable) {
            [UIView dj_repeat_registRunloopObserver];
            DJ_methodSwizzle(UITableView.class, @selector(setDelegate:), @selector(dj_repeat_setDelegate:), YES);
            DJ_methodSwizzle(UICollectionView.class, @selector(setDelegate:), @selector(dj_repeat_setCollectionDelegate:), YES);
            DJ_methodSwizzle(UIControl.class,@selector(sendAction:to:forEvent:),@selector(dj_repeat_sendAction:to:forEvent:),YES);
            
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
            if ([NSClassFromString(@"UIGestureRecognizer") instancesRespondToSelector:@selector(_updateGestureWithEvent:buttonEvent:)]) {
                DJ_methodSwizzle(UIGestureRecognizer.class,@selector(_updateGestureWithEvent:buttonEvent:),@selector(hd_updateGestureWithEvent:buttonEvent:),YES);
            }
#pragma clang diagnostic pop

        }
    });
}

- (instancetype)dj_initWithTarget:(NSObject *)target action:(nullable SEL)action
{
    DJ_methodSwizzle(target.class,action,@selector(dj_gesture_action:),YES);
    return [self dj_initWithTarget:target action:action];
}

- (void)dj_gesture_action:(UITapGestureRecognizer *)recognizer
{
    [self dj_gesture_action:recognizer];
}

+ (void)dj_repeat_registRunloopObserver
{
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFStringRef runLoopMode = kCFRunLoopCommonModes;
    
    void (^runLoopObserverCallback)(CFRunLoopObserverRef runLoopObserver, CFRunLoopActivity activity) = ^(CFRunLoopObserverRef runLoopObserver, CFRunLoopActivity activity){
        bCanTap = YES;
    };
    
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault,
                                                                       kCFRunLoopBeforeWaiting|kCFRunLoopExit,
                                                                       true,
                                                                       INT_MAX-1,
                                                                       runLoopObserverCallback);
    CFRunLoopAddObserver(runLoop, observer, runLoopMode);
    CFRelease(observer);
    
}

+ (BOOL)dj_repeat_checkSafe
{
    if (DJRepeatClickFilterEnable) {
        BOOL otherFilterResult = _otherFilter ? _otherFilter() : YES;
        return bCanTap && otherFilterResult;
    }else{
        return YES;
    }
//    return bCanTap && [UIViewController isTransiting] == NO;
    
}

- (void)dj_repeat_setDelegate:(NSObject *)deleagte
{
    [self dj_repeat_setDelegate:deleagte];
    
    if (hookTableClassesCache == nil) {
        hookTableClassesCache = [NSMutableDictionary new];
    }
    if (deleagte != nil && [hookTableClassesCache objectForKey:NSStringFromClass(deleagte.class)] == nil) {
        BOOL addMethodResult = DJ_addSwizzleMethod(deleagte.class,@selector(dj_repeat_tableView:didSelectRowAtIndexPath:));
        NSAssert(addMethodResult, @"add method fail..");
        
        DJ_methodSwizzle(deleagte.class, @selector(tableView:didSelectRowAtIndexPath:), @selector(dj_repeat_tableView:didSelectRowAtIndexPath:), YES);
        [hookTableClassesCache setObject:@"1" forKey:NSStringFromClass(deleagte.class)];
    }
    
}

- (void)dj_repeat_setCollectionDelegate:(NSObject *)deleagte
{
    [self dj_repeat_setCollectionDelegate:deleagte];
    
    if (hookCollectionClassesCache == nil) {
        hookCollectionClassesCache = [NSMutableDictionary new];
    }
    if (deleagte != nil && [hookCollectionClassesCache objectForKey:NSStringFromClass(deleagte.class)] == nil) {
        BOOL addMethodResult = DJ_addSwizzleMethod(deleagte.class,@selector(dj_repeat_collectionView:didSelectItemAtIndexPath:));
        NSAssert(addMethodResult, @"add method fail..");
        
        DJ_methodSwizzle(deleagte.class, @selector(collectionView:didSelectItemAtIndexPath:), @selector(dj_repeat_collectionView:didSelectItemAtIndexPath:), YES);
        [hookCollectionClassesCache setObject:@"1" forKey:NSStringFromClass(deleagte.class)];
    }
    
}

- (void)dj_updateGestureWithEvent:(UIEvent *)event buttonEvent:(UIEvent *)buttonEvent
{
    UIGestureRecognizer *recognizer = (UIGestureRecognizer *)self;
    
    if ([recognizer isMemberOfClass:UITapGestureRecognizer.class] && recognizer.state == UIGestureRecognizerStateEnded){
        if ([UIView dj_repeat_checkSafe]) {
            bCanTap = NO;
            [self dj_updateGestureWithEvent:event buttonEvent:buttonEvent];
        }
        return;
    }
    
    if ([recognizer isMemberOfClass:UIScreenEdgePanGestureRecognizer.class]){
        //began,要么全过，要么一个都不要过
        static UIGestureRecognizerState oldState = UIGestureRecognizerStatePossible;
        static BOOL bLetAllBeganGo = NO;
        if (recognizer.state != UIGestureRecognizerStateBegan) {
            oldState = recognizer.state;
            [self dj_updateGestureWithEvent:event buttonEvent:buttonEvent];
        }else{
            if (oldState == UIGestureRecognizerStatePossible) {
                bLetAllBeganGo = [UIView dj_repeat_checkSafe];//possible 到began 转换的时候检查当前做导航是否安全
                oldState = UIGestureRecognizerStateBegan;
            }
            
            if (bLetAllBeganGo) {
                bCanTap = NO;
                [self dj_updateGestureWithEvent:event buttonEvent:buttonEvent];
            }
        }
        return;
    }
    
    [self dj_updateGestureWithEvent:event buttonEvent:buttonEvent];
}

//- (void)dj_repeat_sendActionWithGestureRecognizer:(UIGestureRecognizer *)recognizer
//{
//    if ([recognizer isMemberOfClass:UITapGestureRecognizer.class]
//        || ([recognizer isMemberOfClass:UIScreenEdgePanGestureRecognizer.class] && recognizer.state == UIGestureRecognizerStateBegan)) {
//        if ([UIView dj_repeat_checkSafe]) {
//            bCanTap = NO;
//            [self dj_repeat_sendActionWithGestureRecognizer:recognizer];
//        }
//    }else{
//        [self dj_repeat_sendActionWithGestureRecognizer:recognizer];
//    }
//}

- (void)dj_repeat_sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event
{
    if (event == nil) {
        //UITextInput replaceRange:withText: will call
        [self dj_repeat_sendAction:action to:target forEvent:event];
        return;
    }
    
    if ([UIView dj_repeat_checkSafe]) {
        if (![NSStringFromSelector(action) hasPrefix:@"growingHook"]) {
          bCanTap = NO;
        }
        [self dj_repeat_sendAction:action to:target forEvent:event];
    }
}

- (void)dj_repeat_tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([UIView dj_repeat_checkSafe]) {
        bCanTap = NO;
        [self dj_repeat_tableView:tableView didSelectRowAtIndexPath:indexPath];
    }
}

- (void)dj_repeat_collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if ([UIView dj_repeat_checkSafe]) {
        bCanTap = NO;
        [self dj_repeat_collectionView:collectionView didSelectItemAtIndexPath:indexPath];
    }
}


@end
