# Magic-API 接口服务 Skill

## 服务概述

MagicAPI 是基于 `magic-api` 库的可视化 API 开发平台，通过 Web 界面直接编写 MagicScript 脚本。

- **服务端口**：9999
- **Web 编辑器**：http://localhost:9999/magic/web （登录：admin / admin123）
- **实际运行路径**：`/home/zj/claude/om-data/APIMagic`
- **存储方式**：**文件系统存储**（不是数据库），文件位于 `src/main/resources/magic-api/`

---

## 启动方式

```bash
cd /home/zj/claude/om-data/APIMagic

# 后台启动（推荐）
nohup mvn spring-boot:run > logs/app.log 2>&1 &

# 查看启动日志
tail -f logs/app.log

# 启动成功标志
grep "服务启动成功" logs/app.log
```

> ⚠️ **重要**：文件变更后**不会自动热加载**，必须重启服务才能生效。
> 重启方法：`pkill -f MagicAPIExampleApplication`，等进程退出后再执行上面的启动命令。

---

## 数据库配置

配置文件：`/home/zj/claude/om-data/APIMagic/src/main/resources/application.yml`

**正确配置：**
```yaml
spring:
  datasource:
    url: jdbc:postgresql://127.0.0.1:5432/onedata
    username: postgres
    password: onedata
```

> 注意：端口是 **5432**，用户名是 **postgres**，密码是 **onedata**。

---

## 文件存储结构

API 定义以文件形式存储在：
```
/home/zj/claude/om-data/APIMagic/src/main/resources/magic-api/api/
├── {分组名}/
│   ├── group.json       # 分组定义（路径、名称）
│   └── {接口名}.ms      # 接口定义（元数据 + MagicScript）
```

### group.json 格式

```json
{
  "id": "cla_group_001",
  "name": "CLA管理",
  "type": "api",
  "parentId": "0",
  "path": "/server/cla"
}
```

> ⚠️ **关键**：`path` 字段必须以 `/server/` 开头（如 `/server/cla`），否则前端 Vite proxy 无法路由到该接口。

### .ms 文件格式

JSON 元数据与 MagicScript 之间用 `================================` 分隔：

```
{
  "id": "cla_stats_001",
  "groupId": "cla_group_001",
  "name": "CLA统计",
  "path": "/stats",
  "method": "POST",
  "parameters": [],
  "requestBody": "",
  "headers": [],
  "paths": [],
  "responseBody": null,
  "description": null,
  "requestBodyDefinition": null,
  "responseBodyDefinition": null
}
================================
var community = body.community != null ? body.community : "openubmc"
var tableName = "fact_" + community + "_cla_user"
return db.selectInt("SELECT count(1) FROM " + tableName)
```

---

## API 路径规则

```
前端请求路径：    /server/cla/stats
↓ Vite proxy（无 rewrite）
后端接收路径：    http://127.0.0.1:9999/server/cla/stats

group.json path： /server/cla
endpoint path：          /stats
完整路径 = group.path + endpoint.path = /server/cla/stats  ✓
```

---

## 新增 API 接口步骤

### 方法一：直接创建文件（推荐，可用 Claude 完成）

1. 创建分组目录：`mkdir -p .../magic-api/api/{分组名}/`
2. 创建 `group.json`（path 必须含 `/server/` 前缀）
3. 创建 `{接口名}.ms`（JSON 元数据 + `================================` + MagicScript）
4. **重启服务**加载新文件

### 方法二：通过 Web 编辑器

1. 打开 http://localhost:9999/magic/web
2. 左侧树 → 新建分组，填写名称和路径（路径要加 `/server/` 前缀）
3. 在分组下新建接口，填写名称、路径、HTTP 方法
4. 编写 MagicScript，保存立即生效（Web 编辑器修改会热加载，不需要重启）

---

## MagicScript 脚本要点

脚本详细语法见 `magicscript-syntax.md`，此处列关键注意事项：

### 获取请求参数
```javascript
body.xxx       // POST Body 字段
param.xxx      // Query 参数（GET）
header.xxx     // Header
```

### 动态表名（必须用字符串拼接）
```javascript
// ✅ 正确
var community = body.community != null ? body.community : "openubmc"
var tableName = "fact_" + community + "_cla_user"
return db.select("SELECT * FROM " + tableName)

// ❌ 错误：#{tableName} 只能用于值绑定，不能用于表名
return db.select("SELECT * FROM #{tableName}")
```

### 分页查询
```javascript
// db.page() 自动读取请求中的 page 和 size 参数
return db.page("""
SELECT * FROM """ + tableName + """
WHERE 1=1
<if test="sign_type != null and sign_type != ''">
  AND sign_type = #{sign_type}
</if>
ORDER BY created_at DESC
""")
```

### 返回格式（固定）
```json
{"code": 1, "message": "success", "data": {...}, "timestamp": 1745507651806}
```

---

## 验证接口是否生效

```bash
# 测试接口（注意路径需要完整的 /server/xxx 前缀）
curl -X POST http://localhost:9999/server/cla/stats \
  -H "Content-Type: application/json" \
  -d '{"community": "openubmc"}'

# 响应成功标志：code 为 1
```

---

## 常见问题

### 接口 404
1. 检查 group.json 的 `path` 是否以 `/server/` 开头
2. 检查 .ms 文件的 JSON 头部 `method` 是否与请求方法一致
3. 文件修改后是否**重启了服务**

### 脚本执行报错
1. 查看日志：`tail -f /home/zj/claude/om-data/APIMagic/logs/app.log`
2. 确认动态表名用了字符串拼接而不是 `${tableName}` 在 db.select 里
3. Elvis 运算符 `?:` 可能在某些情况下报错，改用显式三元 `x != null ? x : default`
