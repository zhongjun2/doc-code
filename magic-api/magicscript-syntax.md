# MagicScript 语法手册

MagicAPI 使用的脚本语言，语法类似 JavaScript/Groovy，但有自己的特性。
本文档基于 `/home/zj/claude/om-data/APIMagic/src/main/resources/magic-api/api/` 下的真实示例归纳。

---

## 1. 变量声明

```javascript
var a = 123
var str = "hello"
var list = [1, 2, 3]
var map = { a: 1, b: "ok" }
const id = '1'        // const 声明常量
```

---

## 2. 数据类型

| 类型 | 示例 |
|------|------|
| Integer | `var n = 123` |
| String | `var s = "abc"` 或 `var s = 'abc'` |
| Boolean | `var b = true` |
| null | `var x = null` |
| Array/List | `var list = [1,2,3]` |
| Map/Object | `var m = {a:1, b:2}` |

字符串类型转换：
```javascript
var str = "456.0"
var intVal = str::int(0)    // 转int，失败返回默认值0
var asStr = num.asString()  // 转字符串
```

---

## 3. 运算符

### 算术
```javascript
a + b   a - b   a * b   a / b   a % b
a++     a--     -a
```

### 比较
```javascript
a == b    a != b    a > b    a >= b    a < b    a <= b
a === b   a !== b   // 类型和值都相等
```

### 逻辑
```javascript
a && b    a || b
```

### 三元运算符（推荐写法）
```javascript
var result = a > 0 ? "正数" : "非正数"
sex : item.sex == 0 ? '男' : '女'
```

### Elvis 运算符（空值合并）
```javascript
// 语法上支持，但在某些情况下可能解析报错
// ⚠️ 建议改用显式三元运算符，更安全
var community = body.community ?: "openubmc"   // 可能报错
var community = body.community != null ? body.community : "openubmc"  // ✅ 推荐
```

### 空安全运算符
```javascript
map.a?.b    // map.a 不存在时不报错，返回 null，而不是抛异常
```

### 扩展运算符（展开）
```javascript
var newMap = {
    ...oldMap,     // 展开 Map
    c: 3,
    d: [...list]   // 展开 List
}
```

---

## 4. 条件语句

```javascript
if (a == 1) {
    return 1
} else if (a == 2) {
    return 2
} else {
    return 0
}
```

**简写判断（falsy 值）**：`null`、空集合、空Map、`0`、`""` 都被视为 false：
```javascript
if (name) {   // name 非空非null时执行
    ...
}
```

---

## 5. 循环

```javascript
// for...in 遍历集合
for (item in list) {
    log.info(item)
}

// 数字范围
for (i in range(0, 10)) {
    list.add(i)
}
```

---

## 6. 函数 / Lambda

```javascript
// 单参数单行（省略括号和{}）
var fn1 = e => e + 1

// 多参数
var fn2 = (a, b) => a + b

// 多行
var fn3 = (a, b) => {
    a = a + 1
    return a + b
}

// 递归
var toTree = (list, parentId) => {
    return list.filter(it => it.parent_id == parentId)
        .each(it => {
            it.children = toTree(list, it.id)
        })
}
```

---

## 7. 异常处理

```javascript
try {
    var c = 1 / 0
} catch (e) {
    return e.getMessage()
} finally {
    // 一定执行
}
```

---

## 8. 模块导入

```javascript
import response     // 内置模块：直接写名称
import request
import log

// 导入 Java 类
import 'java.util.Date' as Date
import 'java.text.SimpleDateFormat' as SimpleDateFormat
```

---

## 9. 请求参数获取

| 变量 | 说明 |
|------|------|
| `name` | Query 参数（GET 请求的 URL 参数） |
| `body.xxx` | POST 请求 Body 中的字段 |
| `header.xxx` | 请求 Header |
| `path.xxx` | URL 路径参数（如 `/user/{id}` 中的 id） |

```javascript
return {
    query_param : name,           // Query 参数直接用变量名
    request_body : body.data.id,  // POST Body
    token : header.token,         // Header
    id : path.id                  // 路径参数
}
```

---

## 10. db 模块（核心）

### 10.1 查询列表
```javascript
// 简单查询
return db.select('SELECT * FROM your_table')

// 驼峰命名列转换
return db.camel().select('SELECT user_name FROM your_table')

// 动态 SQL（三引号多行）
return db.select("""
    SELECT * FROM your_table
    <where>
        <if test="name != null and name != ''">
            AND name LIKE concat('%', #{name}, '%')
        </if>
    </where>
""")
```

### 10.2 查询单个数值
```javascript
var count = db.selectInt('SELECT count(*) FROM your_table')
var total = db.selectLong('SELECT count(*) FROM your_table')
```

### 10.3 分页查询
```javascript
// 自动取请求中的 page/size 参数
return db.page("""
    SELECT * FROM your_table
    <where>
        <if test="status != null and status != ''">
            AND status = #{status}
        </if>
    </where>
    ORDER BY created_at DESC
""")
```

### 10.4 单表链式操作
```javascript
// 查询
return db.table('your_table').select()

// 查询特定列
return db.table('your_table').columns('id', 'name').select()

// 分页
return db.table('your_table').columns('id', 'name').page()

// 计数
return db.table('your_table').count()

// 条件查询
return db.table('your_table').where().eq('status', 'active').select()

// 插入（primary 自动生成 ID）
return db.table('your_table').primary('id', () => uuid()).save({ name: 'test' })

// 更新
return db.table('your_table').primary('id').update({ id: '123', name: 'new' })

// 删除
return db.table('your_table').where().eq('id', id).delete()
```

### 10.5 SQL 更新/插入
```javascript
// 更新
db.update("UPDATE your_table SET name = #{name} WHERE id = #{id}")

// 插入（第二个参数是主键列名，返回生成的主键）
db.insert("INSERT INTO your_table(name) VALUES(#{name})", 'id')

// 删除
db.update("DELETE FROM your_table WHERE id = #{id}")
```

### 10.6 动态表名写法

> ⚠️ 动态表名不能用 `#{tableName}`（参数化查询不能用于表名），必须用字符串拼接：

```javascript
// ✅ 正确：字符串拼接
var community = body.community != null ? body.community : "openubmc"
var tableName = "fact_" + community + "_cla_user"
return db.select("SELECT * FROM " + tableName)

// ✅ 也可以：${} 插值（直接替换，有 SQL 注入风险，仅用于可信输入）
return db.select("SELECT * FROM ${tableName}")

// ❌ 错误：#{} 是参数化绑定，不能用于表名
return db.select("SELECT * FROM #{tableName}")
```

### 10.7 MyBatis 动态 SQL 标签

注意：MyBatis 标签中 `test` 属性里的变量直接用名称（不用 `body.`）：

```xml
<!-- if 条件判断 -->
<if test="name != null and name != ''">
    AND name = #{name}
</if>

<!-- if/elseif/else -->
<if test="type == 1">
    AND status = 'active'
</if>
<elseif test="type == 2">
    AND status = 'inactive'
</elseif>
<else>
    AND status IS NOT NULL
</else>

<!-- where（自动处理 AND/OR 前缀）-->
<where>
    <if test="name != null">AND name = #{name}</if>
</where>

<!-- foreach 遍历 -->
<foreach collection="ids" open="(" separator="," close=")" item="item">
    #{item}
</foreach>

<!-- set（用于 UPDATE，自动处理逗号）-->
<set>
    <if test="name != null">name = #{name},</if>
    <if test="status != null">status = #{status}</if>
</set>
```

**参数绑定区别：**
| 语法 | 用途 | SQL 注入 |
|------|------|---------|
| `#{value}` | 参数化查询（推荐） | 安全 |
| `${value}` | 直接字符串替换 | 有风险 |

### 10.8 事务
```javascript
// 自动事务（lambda 内抛异常会自动回滚）
var result = db.transaction(() => {
    db.update("DELETE FROM ...")
    return db.update("INSERT INTO ...")
})

// 手动事务
var tx = db.transaction()
try {
    db.update("...")
    tx.commit()
} catch (e) {
    tx.rollback()
}
```

### 10.9 多数据源
```javascript
// 访问名为 slave 的数据源
return db.slave.select('SELECT 1')
return db['slave'].select('SELECT 1')
```

### 10.10 缓存
```javascript
// 有效期 2000ms 的缓存
return db.cache('cache_key', 2000).select('SELECT * FROM your_table')

// 清除缓存
db.deleteCache('cache_key')
```

---

## 11. 集合常用操作

```javascript
var list = [...]

list.filter(it => it.status == 1)          // 过滤
list.map(it => { id: it.id, name: it.name }) // 转换
list.each(it => it.label = it.name)         // 遍历（修改原集合）
list.size()                                   // 长度
list.add(item)                                // 追加
list.group(it => it.type)                    // 分组成 Map
list.group(it => it.type, list => list.size()) // 分组并聚合
list.sort((k1,k2,v1,v2) => v2 - v1)          // 排序

// join 关联两个列表
list1.join(list2, (t1, t2) => t1.id == t2.userId)

// asList - 把 Map 转为 List
map.asList((key, value) => { ...value, type: key })
```

---

## 12. return / exit

```javascript
// 正常返回
return data
return { code: 1, data: rows }
return [1, 2, 3]

// 提前退出（设置响应码和消息）
exit 400, '参数有误'
exit 200, 'success', { data: rows }
```

---

## 13. 完整接口示例

### 分页列表（典型模式）
```javascript
var community = body.community != null ? body.community : "openubmc"
var tableName = "fact_" + community + "_your_table"

return db.page("""
SELECT id, name, company, status, created_at
FROM """ + tableName + """
WHERE 1=1
<if test="status != null and status != ''">
  AND status = #{status}
</if>
<if test="company != null and company != ''">
  AND company ILIKE '%' || #{company} || '%'
</if>
ORDER BY created_at DESC
""")
```

### 统计数据
```javascript
var community = body.community != null ? body.community : "openubmc"
var tableName = "fact_" + community + "_your_table"

var total = db.selectInt("SELECT count(1) FROM " + tableName)
var statsList = db.select("SELECT type, count(1) as cnt FROM " + tableName + " GROUP BY type")

var result = {}
for (item in statsList) {
    result[item.type] = item.cnt
}
result["total"] = total
return result
```

---

## 14. 注意事项

1. **动态表名**：必须用字符串拼接 `"fact_" + community + "_table"`，不能用 `#{tableName}`
2. **Elvis `?:`**：`body.community ?: "default"` 语法上支持，但在某些情况下会报解析错误，推荐改用显式三元 `body.community != null ? body.community : "default"`
3. **空安全 `?.`**：`obj?.field` 访问不存在的属性不报错
4. **字符串**：单引号和双引号都可以；三引号 `"""..."""` 用于多行 SQL
5. **SQL 注入**：列名/表名用拼接，值用 `#{value}` 绑定
6. **分页**：`db.page()` 自动读取请求中的 `page` 和 `size` 参数
7. **MyBatis test 属性**：`<if test="...">` 里直接写变量名（如 `sign_type`），对应 POST body 里的同名字段
