# DataStat 全栈开发工作流 Skill

## 架构总览

```
om-dataarts (Python)          APIMagic (Java)          datastat-manage-website (Vue)
    ↓                              ↓                              ↓
采集外部数据  →  写入 PG 数据库  →  查询 PG 数据库  →  提供 API  →  前端调用展示
```

**三个服务的职责：**
- `om-dataarts`：Python 脚本，采集数据写入 PostgreSQL
- `APIMagic`：Java 服务，读 PG 数据库，通过 MagicScript 提供 REST API
- `datastat-manage-website`：Vue3 前端，调用 MagicAPI，展示数据看板

**数据库**：PostgreSQL，本地端口 **5432**，库名 `onedata`，用户 **`postgres`** / 密码 **`onedata`**

**服务端口**：
- 后端 API：http://localhost:9999
- 前端：http://localhost:8080（开发服务器）
- Web 编辑器：http://localhost:9999/magic/web（admin/admin123）

**实际代码路径**：
- 后端：`/home/zj/claude/om-data/APIMagic`
- 前端：`/home/zj/claude/om-data/datastat-manage-website`

---

## 开发前必做：检查服务状态

```bash
# 检查 MagicAPI 是否正常（用已有接口测试）
curl -s http://localhost:9999/server/community/list -X POST -H "Content-Type: application/json" -d '{}'

# 检查前端是否启动
curl -s http://localhost:8080 | grep -c "html"

# 检查数据库连接
psql -h localhost -p 5432 -U postgres -d onedata -c "SELECT 1"
```

---

## 场景一：全新需求（数据→API→前端）

适用于：数据还没有，需要从头采集并展示

### Step 1：数据服务 — 采集数据

1. **确认目标数据**：明确要采集什么数据、从哪个平台采集
2. **查看现有任务**：查看 om-dataarts 是否已有类似任务
3. **确认表结构**：
   ```sql
   SELECT column_name, data_type FROM information_schema.columns
   WHERE table_name = 'fact_{community}_{topic}';
   ```
4. **开发采集脚本**（参考 om-dataarts skill）
5. **验证数据写入**：
   ```bash
   psql -h localhost -p 5432 -U postgres -d onedata \
     -c "SELECT count(*) FROM fact_{community}_{topic}"
   ```

### Step 2：后端 API — 创建接口

1. **创建 group.json**（`path` 必须以 `/server/` 开头）：
   ```json
   {
     "id": "your_group_001",
     "name": "你的模块",
     "type": "api",
     "parentId": "0",
     "path": "/server/your-module"
   }
   ```

2. **创建 .ms 文件**（JSON 元数据 + `================================` + MagicScript）：
   ```javascript
   var community = body.community != null ? body.community : "openubmc"
   var tableName = "fact_" + community + "_your_table"

   return db.page("""
   SELECT * FROM """ + tableName + """
   WHERE 1=1
   <if test="status != null and status != ''">
     AND status = #{status}
   </if>
   ORDER BY created_at DESC
   """)
   ```

3. **重启 MagicAPI**（文件修改不会自动热加载）：
   ```bash
   pkill -f MagicAPIExampleApplication
   # 等进程退出后
   cd /home/zj/claude/om-data/APIMagic
   nohup mvn spring-boot:run > logs/app.log 2>&1 &
   ```

4. **验证接口**：
   ```bash
   curl -X POST http://localhost:9999/server/your-module/list \
     -H "Content-Type: application/json" \
     -d '{"community": "openubmc", "page": 1, "pageSize": 10}'
   ```

### Step 3：前端 — 新增页面

需要修改 **6 个地方**（缺一不可）：

1. **创建 View 组件**：`src/views/your-feature/TheYourFeature.vue`
2. **创建 API 函数**：`src/api/api-your-feature.ts`
   ```typescript
   export function fetchYourData(params: any) {
     return request.post('/server/your-module/list', params).then(res => res.data);
   }
   ```
3. **注册路由**：`src/routers/index.ts` 的 `routes` 数组
4. **社区权限矩阵**：`src/shared/common.const.ts` 的 PROD 和 TEST 两个对象里都要加
5. **侧边栏菜单**：`src/components/AppAside.vue` 添加 `el-menu-item`
6. **beta 开发权限**：`src/routers/index.ts` 的 beta 默认权限数组里加 `{your_feature}_menu_view`

---

## 场景二：数据已有，只需 API + 前端

适用于：PG 里已经有数据表，只是没有接口

先确认表有数据：
```sql
SELECT count(*) FROM fact_openubmc_your_table;
SELECT * FROM fact_openubmc_your_table LIMIT 3;
```

然后跳过 Step 1，直接从 Step 2 开始。

---

## 场景三：只调整前端

适用于：API 接口已有，只是前端展示需要调整

直接修改对应的 Vue 组件，无需动 API 和数据。

---

## 场景四：只修改 API 逻辑

**通过 Web 编辑器修改（修改立即生效，无需重启）：**
1. 打开 http://localhost:9999/magic/web
2. 找到目标接口，修改 MagicScript，保存

**通过文件修改（需要重启服务）：**
1. 编辑对应的 `.ms` 文件
2. 重启 MagicAPI

---

## 校验流程

### 数据层校验

```sql
SELECT count(*) FROM fact_openubmc_cla_user;
SELECT min(created_at), max(created_at) FROM fact_openubmc_cla_user;
SELECT * FROM fact_openubmc_cla_user LIMIT 10;
```

### API 层校验

```bash
curl -s http://localhost:9999/server/{group}/{path} \
  -X POST -H "Content-Type: application/json" \
  -d '{"page": 1, "pageSize": 5}' | python3 -m json.tool

# code 为 1 表示成功
```

### 前端层校验

1. 浏览器 Network 面板查看请求响应（200 + code:1）
2. 检查社区选择器是否有该社区（需要权限 + API + communityGroups 三个条件）
3. 检查侧边栏是否出现菜单项（需要 showItem 返回 true）

---

## 常见问题排查

### MagicAPI 接口 404

1. `group.json` 的 `path` 是否以 `/server/` 开头
2. `.ms` 文件的 `method` 是否与请求方法一致（前端用 POST 则后端也要 POST）
3. 服务是否重启加载了新文件（查看日志是否有"注册接口[接口名]"）

### 前端社区选择器没有某社区

需要同时满足三个条件：
1. `/server/community/list` 接口的返回列表里有该社区名
2. `src/routers/index.ts` beta 默认权限里有 `{community}_view`
3. `src/shared/overview.ts` 的 `communityGroups` 里有该社区

### 侧边栏菜单不显示

`showItem('route-name')` 返回 false 的可能原因：
1. `loginStore.enabledCommunities` 为空（beta 权限里缺 `{community}_view`）
2. 路由名在 `COMMUNITY_ROUTING_MATRIX` 里没有该社区的对应条目
3. `AppAside.vue` 里没有添加 `el-menu-item`

### MagicScript 报错

查看日志：
```bash
tail -f /home/zj/claude/om-data/APIMagic/logs/app.log
```

常见原因：
- 用了 `?:` Elvis 运算符但解析失败 → 改用显式三元
- 用 `${tableName}` 在 db.select 里 → 改用字符串拼接
- `#{tableName}` 用于表名 → 不支持，必须字符串拼接

### 数据库连接
```bash
psql -h localhost -p 5432 -U postgres -d onedata
# 密码：onedata
```

---

## 开发规范

1. **先确认数据**：写代码前先 SQL 查表
2. **先测 API**：用 curl 确认接口返回正确再写前端
3. **小步验证**：每完成一层立即验证
4. **不要硬编码社区名**：community 通过参数传入，默认值用 `"openubmc"`
5. **API 响应格式**：前端统一判断 `res.code === 1`（MagicAPI 返回 `{"code":1,"data":...}`）
6. **MagicAPI 路径**：group.path 必须包含 `/server/` 前缀，才能被 Vite proxy 正确路由
