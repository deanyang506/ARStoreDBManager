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
@property (nonatomic, strong) NSString *orderby;

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
- (BOOL)storeWithKey:(nonnull NSString *)key object:(id)object;


/**
 列表存储，可以根据key作为列表名
 @param key 列表名称
 @object 存储的对象(id/NSArray/NSDictory)
 @identityKey 列表内的唯一标识key, 如果object类型为id，那么通过KVC取出对应的值作为唯一标识值，对象序列化成json
 @orderKey 排序key(通过KVC取到对应的值)， 如果为nil按当前的创建时间
 NSArray类型遍历出所有对象，同上存储（只遍历一层）
 NSDictory类型的key作为唯一标识值，value为对象（只遍历一层）
 @result 成功/失败，集合类型的某个失败将导致中断并返回失败
 注意：如果列表内已存储在相同的唯一标识将被覆盖
 */
- (BOOL)setObjectWithKey:(nonnull NSString *)key
                  object:(id)object
             identityKey:(nonnull NSString *)identityKey
                orderKey:(nullable NSString *)orderkey;

/**
 移除key列表中的单行或多行
 @param key 列表名称
 @identits 对应单行或多行的唯一标识, 如果为空则清除当前列表
 @result 成功/失败，包括key或identities不存在
 */
- (BOOL)removeWithKey:(nonnull NSString *)key identities:(nullable NSArray<__kindof NSString *> *)identities;

/**
 计算列表内所有记录数量
 @param key 列表名称
 @result 记录数量
 */
- (NSUInteger)objectCountWithKey:(nonnull NSString *)key;


/**
 取出本地存储对象
 @param key 列表名称
 @pageIndex 分页索引，可以结合pageSize 从第几条数据开始读取, 索引从0开始
 @pageSize 每次取出多少条数据，如果为0则全部取出
 @comparison 根据存储排序Key排序
 @result 集合
 */
- (NSArray<ARStoreDBModel *> *)objectWithKey:(nonnull NSString *)key
                                   pageIndex:(NSInteger)pageIndex
                                    pageSize:(NSInteger)pageSize
                                  comparison:(NSComparisonResult)comparison;


/**
 取出本地存储对象
 @param key 列表名称
 @pageIndex 分页索引，可以结合pageSize 从第几条数据开始读取, 索引从0开始
 @pageSize 每次取出多少条数据，如果为0则全部取出
 @comparison 根据存储排序Key排序
 @condition 根据ID集条件读取数据
 @result 集合
 */
- (NSArray<ARStoreDBModel *> *)objectWithKey:(nonnull NSString *)key
                                   pageIndex:(NSInteger)pageIndex
                                    pageSize:(NSInteger)pageSize
                                  comparison:(NSComparisonResult)comparison
                                   condition:(NSArray<NSString *> *)ids;

/**
 根据标识取出本地某行数据
 
 @param key 列表名/默认表中的唯一key
 @param identity 唯一标识的值 为nil时取出最后一行
 @return 单行存储对象
 */
- (ARStoreDBModel *)objectWithKey:(nonnull NSString *)key identity:(nullable NSString *)identity;

@end

