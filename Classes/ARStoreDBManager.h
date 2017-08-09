//
//  ARStoreDBManager.h
//  AipaiReconsitution
//
//  Created by Dean.Yang on 2017/7/3.
//  Copyright © 2017年 Dean.Yang. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<FMDB/FMDB.h>)
#import <FMDB/FMDB.h>
#else
#import "FMDB.h"
#endif

@interface ARStoreDBModel : NSObject

@property (nonatomic, strong) NSString *identity;
@property (nonatomic, strong) id object;
@property (nonatomic, strong) NSDate *createdTime;

@end

@interface ARStoreDBManager : NSObject

+ (instancetype)shareStoreDBManager;

/**
 单次存储，如果本地存在相同的key则会被覆盖掉
 @param key 唯一标识
 @param object 存储的对象id, 将序列化成json，如果为nil则清空存储
 @result 成功/失败
 相同的key会被覆盖
 */
- (BOOL)storeWithKey:(NSString *)key object:(id)object;


/**
 列表存储，可以根据key作为列表名
 @param key 列表名称
 @object 存储的对象(id/NSArray/NSDictory)
 @identityKey 列表内的唯一标识key, 如果object类型为id，那么通过KVC取出对应的值作为唯一标识值，对象序列化成json
 NSArray类型遍历出所有对象，同上存储
 NSDictory类型的key作为唯一标识值，value为对象
 @result 成功/失败，集合类型的某个失败将导致中断并返回失败
 注意：如果列表内已存储在相同的唯一标识将被覆盖
 */
- (BOOL)setObjectWithKey:(NSString *)key
                  object:(id)object
             identityKey:(NSString *)identityKey;

/**
 移除key列表中的单行或多行
 @param key 列表名称
 @identits 对应单行或多行的唯一标识, 如果为空则清除当前列表
 @result 成功/失败，包括key或identities不存在
 */
- (BOOL)removeWithKey:(NSString *)key identities:(NSArray<__kindof NSString *> *)identities;

/**
 计算列表内所有记录数量
 @param key 列表名称
 @result 记录数量
 */
- (NSUInteger)objectCountWithKey:(NSString *)key;


/**
 取出本地存储对象
 @param key 列表名称
 @pageIndex 分页索引，可以结合pageSize 从第几条数据开始读取
 @pageSize 每次取出多少条数据，如果为0则全部取出
 @dateOrder 根据存储事件排序
 @result 集合
 */
- (NSArray<ARStoreDBModel *> *)objectWithKey:(NSString *)key
                                 pageIndex:(NSInteger)pageIndex
                                  pageSize:(NSInteger)pageSize
                                 dateOrder:(NSComparisonResult)dateOrder;

@end