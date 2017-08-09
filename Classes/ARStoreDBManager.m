//
//  ARStoreDBManager.m
//  AipaiReconsitution
//
//  Created by Dean.Yang on 2017/7/3.
//  Copyright © 2017年 Dean.Yang. All rights reserved.
//

#import "ARStoreDBManager.h"

static NSString *const CREATE_TABLE_SQL =
@"CREATE TABLE IF NOT EXISTS %@ ( \
id TEXT UNIQUE  NOT NULL, \
json TEXT  NOT NULL, \
createdTime TEXT  NOT NULL\
)";

static NSString *const DEFAULT_TABLE = @"_DefaultTable";

static NSString *const DROP_TABLE_SQL = @"DROP TABLE %@";
static NSString *const INSERT_ITEM_SQL = @"INSERT INTO %@ (id, json, createdTime) VALUES(?, ?, ?)";

// 尝试替换如果id存在，否则插入
static NSString *const REPLACE_INTO_ITEM_SQL = @"REPLACE INTO %@ (id, json, createdTime) values (?, ?, ?)";
static NSString *const UPDATE_ITEM_SQL = @"UPDATE %@ SET json=? WHERE id=?";
static NSString *const QUERY_ITEM_SQL = @"SELECT json, createdTime FROM %@ WHERE id = ? LIMIT 1";
static NSString *const SELECT_ALL_SQL = @"SELECT * FROM %@";
static NSString *const SELECT_ALL_ORDERBY_SQL = @"SELECT * FROM %@ ORDER BY createdTime %@";
static NSString *const SELECT_PAGE_SQL = @"SELECT * FROM %@ LIMIT %@ OFFSET %@";
static NSString *const SELECT_PAGE_ORDERBY_SQL = @"SELECT * FROM %@ ORDER BY %@ LIMIT %@ OFFSET %@";
static NSString *const SELECT_ID_SQL = @"SELECT * FROM %@ WHERE id = ?";
static NSString *const COUNT_ALL_SQL = @"SELECT COUNT(*) as num FROM %@";
static NSString *const CLEAR_ALL_SQL = @"DELETE FROM %@";
static NSString *const DELETE_ITEM_SQL = @"DELETE FROM %@ WHERE id = ?";
static NSString *const DELETE_ITEMS_SQL = @"DELETE FROM %@ WHERE id in ( %@ )";

static BOOL checkTableName(NSString *tableName) {
    if (tableName == nil || tableName.length == 0 || [tableName rangeOfString:@" "].location != NSNotFound) {
        NSLog(@"ERROR, table name: %@ format error.",tableName);
        return NO;
    }
    return YES;
}

@implementation ARStoreDBModel
@end

@interface ARStoreDBManager()
@property (nonatomic, strong) FMDatabaseQueue *dbQueue;
@end

@implementation ARStoreDBManager

- (void)dealloc {
    [_dbQueue close];
    _dbQueue = nil;
}

static ARStoreDBManager *_storeDBManager;
+ (instancetype)shareStoreDBManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _storeDBManager = [[ARStoreDBManager alloc] init];
    });
    return _storeDBManager;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    if (_storeDBManager) {
        return _storeDBManager;
    }
    return [super allocWithZone:zone];
}

- (instancetype)init {
    if (self = [super init]) {
        NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:@"_database.db"];
        self.dbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
    }
    return self;
}

#pragma mark - public

- (BOOL)storeWithKey:(NSString *)key object:(id)object {
    
    if (![self isTableExists:DEFAULT_TABLE]) {
        if (![self createTableWithName:DEFAULT_TABLE]) {
            return NO;
        }
    }
    
    if (object == nil) {
        return [self deleteWithTableName:DEFAULT_TABLE identity:key];
    } else {
        return [self replaceWithTableName:DEFAULT_TABLE identitiy:key object:object];
    }
}

- (BOOL)setObjectWithKey:(NSString *)key object:(id)object identityKey:(NSString *)identityKey {
    
    if (!identityKey) {
        return NO;
    }
    
    if (![self isTableExists:key]) {
        if (![self createTableWithName:key]) {
            return NO;
        }
    }
    
    if ([object isKindOfClass:[NSArray class]]) {
        
        NSArray *array = (NSArray *)object;
        if (array.count == 0) {
            return NO;
        }
        
        NSMutableArray *identityArray = [NSMutableArray arrayWithCapacity:array.count];
        for (id object in array) {
            NSString* identity = (NSString *)[object valueForKey:identityKey];
            [identityArray addObject:identity];
        }
        
        if([self multiDeleteWithTableName:key identities:identityArray]) {
            return [self insertWithTableName:key objects:array identities:identityArray];
        }
        
        return YES;
        
    } else if([object isKindOfClass:[NSDictionary class]]) {
        
        NSDictionary *dict = (NSDictionary *)object;
        NSArray *keys = dict.allKeys;
        if (keys.count == 0) {
            return NO;
        }
        
        if([self multiDeleteWithTableName:key identities:keys]) {
            NSMutableArray *values = [NSMutableArray array];
            for (id key in keys) {
                [values addObject:dict[key]];
            }
            return [self insertWithTableName:key objects:values identities:keys];
        }
        
        return NO;
        
    } else {
        
        NSString* identity = (NSString *)[object valueForKey:identityKey];
        if(identity == nil) {
            return NO;
        }
            
        return [self replaceWithTableName:key identitiy:identity object:object];
    }
    
    return NO;
}

- (NSUInteger)objectCountWithKey:(NSString *)key {
    
    NSCAssert(checkTableName(key),@"");
    
    FMResultSet *resultSet = [self selectCountWithTableName:key];
    if ([resultSet next]) {
        NSUInteger count = [resultSet longForColumnIndex:0];
        [resultSet close];
        return count;
    }
    
    return 0;
}

- (NSArray<ARStoreDBModel *> *)objectWithKey:(NSString *)key pageIndex:(NSInteger)pageIndex pageSize:(NSInteger)pageSize dateOrder:(NSComparisonResult)dateOrder {
    
    NSCAssert(checkTableName(key),@"");
    
    FMResultSet *resultSet = nil;
    NSString *order = dateOrder == NSOrderedSame ? nil : (dateOrder == NSOrderedAscending ? @"ASC" : @"DESC");
    pageIndex = MAX(0, pageIndex);
    
    if ([self isTableExists:key]) {
        if (pageSize > 0) {
            if (order == nil) {
                resultSet = [self selectWithTableName:key size:pageSize offset:pageIndex * pageSize];
            } else {
                resultSet = [self selectWithTableName:key size:pageSize offset:pageIndex * pageSize order:order];
            }
        } else {
            if (order == nil) {
                resultSet = [self selectWithTableName:key];
            } else {
                resultSet = [self selectWithTableName:key order:order];
            }
        }
    } else {
        resultSet = [self selectWithTableName:DEFAULT_TABLE whereId:key];
    }
    
    if (resultSet) {
        NSMutableArray *array = [NSMutableArray array];
        while ([resultSet next]) {
            ARStoreDBModel *item = [[ARStoreDBModel alloc] init];
            item.identity = [resultSet stringForColumn:@"id"];
            
            NSString *json = [resultSet stringForColumn:@"json"];
            NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
            
            NSError *error = nil;
            id object = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            
            if (error) {
                item.object = json;
            } else {
                item.object = object;
            }
            
            item.createdTime = [resultSet dateForColumn:@"createdTime"];
            [array addObject:item];
        }
        
        [resultSet close];
        
        return [array copy];
    }
    
    return nil;
}

- (BOOL)removeWithKey:(NSString *)key identities:(NSArray<__kindof NSString *> *)identities {
    NSCAssert(checkTableName(key),@"");
    
    if (identities.count == 0) {
        return [self clearTable:key];
    } else {
        if (identities.count > 1) {
            return [self multiDeleteWithTableName:key identities:identities];
        } else {
            return [self deleteWithTableName:key identity:[identities firstObject]];
        }
    }
    
    return NO;
}

#pragma mark - private

- (BOOL)createTableWithName:(NSString *)tableName {
    NSCAssert(checkTableName(tableName),@"");
    
    NSString * sql = [NSString stringWithFormat:CREATE_TABLE_SQL, tableName];
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql];
    }];
    
    return result;
}

- (BOOL)isTableExists:(NSString *)tableName {
    NSCAssert(checkTableName(tableName),@"");
    
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db tableExists:tableName];
    }];

    return result;
}

- (id)generatedJsonWithObject:(id)object {
    
    if ([object isKindOfClass:[NSArray class]]) {
        NSMutableArray *jsonArray = [NSMutableArray new];
        for (id subObj in object) {
            id subJson = [self generatedJsonWithObject:subObj];
            [jsonArray addObject:subJson];
        }
        
        return [jsonArray copy];
    }
    
    return [object yy_modelToJSONString];
}

#pragma mark - insert

- (BOOL)insertWithTableName:(NSString *)tableName objects:(NSArray<id> *)objects identities:(NSArray *)identities {
    
    if (objects.count != identities.count || identities.count == 0) {
        return NO;
    }
    
    NSDate *createdTime = [NSDate date];
    NSString *sql = [NSString stringWithFormat:INSERT_ITEM_SQL, tableName];
    
    id jsonObject = [self generatedJsonWithObject:objects];

    __block BOOL result;
    [_dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if ([jsonObject isKindOfClass:[NSArray class]]) {
            NSArray *jsonArray = (NSArray *)jsonObject;
            for (int i = 0; i < jsonArray.count; i++) {
                result = [db executeUpdate:sql, identities[i], jsonArray[i], createdTime];
                if (!result) {
                    *rollback = YES;
                    return;
                }
            }
        } else {
            result = [db executeUpdate:sql, [identities firstObject], jsonObject, createdTime];
        }
    }];
    
    return result;
}

#pragma mark - delete

- (BOOL)deleteWithTableName:(NSString *)tableName identity:(NSString *)identity {
    
    NSString *sql = [NSString stringWithFormat:DELETE_ITEM_SQL, tableName];
    
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql,identity];
    }];
    
    return result;
}

- (BOOL)multiDeleteWithTableName:(NSString *)tableName identities:(NSArray<NSString *> *)identities {

    NSMutableArray *identityArray = [NSMutableArray arrayWithCapacity:identities.count];
    for (NSString *orign in identities) {
        [identityArray addObject:[NSString stringWithFormat:@"'%@'",orign]];
    }
    
    NSString *sql = [NSString stringWithFormat:DELETE_ITEMS_SQL, tableName,[identityArray componentsJoinedByString:@","]];
    
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql];
    }];
    
    return result;
}

- (BOOL)clearTable:(NSString *)tableName {
    
    NSString * sql = [NSString stringWithFormat:CLEAR_ALL_SQL, tableName];
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql];
    }];
    
    return result;
}

#pragma mark - select

- (FMResultSet *)selectWithTableName:(NSString *)tableName {
    
    NSString *sql = [NSString stringWithFormat:SELECT_ALL_SQL, tableName];
    
    __block FMResultSet *resultSet;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        resultSet = [db executeQuery:sql];
    }];
    
    return resultSet;
}

- (FMResultSet *)selectWithTableName:(NSString *)tableName order:(NSString *)order {
    
    NSString *sql = [NSString stringWithFormat:SELECT_ALL_ORDERBY_SQL, tableName, order];
    
    __block FMResultSet *resultSet;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        resultSet = [db executeQuery:sql];
    }];
    
    return resultSet;
}

- (FMResultSet *)selectWithTableName:(NSString *)tableName
                                size:(NSInteger)size
                              offset:(NSUInteger)offset {
    
    NSString *sql = [NSString stringWithFormat:SELECT_PAGE_SQL, tableName, @(size), @(offset)];
    
    __block FMResultSet *resultSet;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        resultSet = [db executeQuery:sql];
    }];
    
    return resultSet;
}

- (FMResultSet *)selectWithTableName:(NSString *)tableName
                                size:(NSInteger)size
                              offset:(NSUInteger)offset
                               order:(NSString *)order {
    
    NSString *sql = [NSString stringWithFormat:SELECT_PAGE_ORDERBY_SQL, tableName, order, @(size), @(offset)];
    
    __block FMResultSet *resultSet;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        resultSet = [db executeQuery:sql];
    }];
    
    return resultSet;
}

- (FMResultSet *)selectWithTableName:(NSString *)tableName whereId:(NSString *)whereId {
    
    NSString *sql = [NSString stringWithFormat:SELECT_ID_SQL, whereId];
    
    __block FMResultSet *resultSet;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        resultSet = [db executeQuery:sql,whereId];
    }];
    
    return resultSet;
}

- (FMResultSet *)selectCountWithTableName:(NSString *)tableName {
    
    NSString *sql = [NSString stringWithFormat:COUNT_ALL_SQL,tableName];
    
    __block FMResultSet *resultSet;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        resultSet = [db executeQuery:sql];
    }];
    
    return resultSet;
}

#pragma mark - update / insert into

- (BOOL)replaceWithTableName:(NSString *)tableName identitiy:(NSString *)identity object:(id)object {
    
    NSDate *createdTime = [NSDate date];
    NSString *sql = [NSString stringWithFormat:REPLACE_INTO_ITEM_SQL, tableName];
    
    id jsonObject = [self generatedJsonWithObject:object];
    if ([jsonObject isKindOfClass:[NSArray class]]) {
        jsonObject = [((NSArray *)jsonObject) componentsJoinedByString:@","];
    }
    
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql,identity,jsonObject,createdTime];
    }];
    
    return result;
}

@end
