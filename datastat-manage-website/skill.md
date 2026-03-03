# 前端服务 datastat-manage-website Skill

## 服务概述

基于 Vue3 + Vite + TypeScript + Element Plus 的数据统计可视化前端。

- **服务端口**：8080（本地开发）
- **框架**：Vue3 + Vite + Pinia + Vue Router
- **包管理器**：pnpm
- **实际运行路径**：`/home/zj/claude/om-data/datastat-manage-website`

---

## 启动方式

```bash
cd /home/zj/claude/om-data/datastat-manage-website
pnpm dev
```

本地开发模式为 `beta`（`vite --mode beta`），启动后访问 http://localhost:8080。

---

## 登录绕过（本地开发）

路由守卫在 `src/routers/index.ts` 里，`router.beforeEach` 中有针对 `beta` 模式的处理：

```typescript
if (import.meta.env.MODE === 'beta') {
  // 动态添加所有路由
  if (!router.hasRoute('overview')) {
    routes.forEach((route) => router.addRoute(route));
    admin.forEach((route) => router.addRoute(route));
    editor.forEach((route) => router.addRoute(route));
  }
  // 设置默认社区
  if (!commonStore.community) {
    commonStore.community = 'openeuler';
  }
  // 设置默认权限
  if (!loginStore.permissions.length) {
    loginStore.permissions = [...];
    loginStore.guardAuthClient = { username: 'dev_user' };
  }
  next();
  return;
}
```

beta 模式下会自动添加路由和权限，**无需修改代码**即可绕过登录。

---

## API 代理配置

配置文件：`vite.config.ts`

**当前实际配置（已正确指向本地 9999）：**
```typescript
server: {
  proxy: {
    '/server/': {
      target: 'http://127.0.0.1:9999/',
      changeOrigin: true,
      // ⚠️ 无 rewrite：/server/cla/stats → http://127.0.0.1:9999/server/cla/stats
      // 路径原样转发，不去掉 /server/ 前缀
    },
    '/server-beta/': {
      target: 'http://127.0.0.1:9999/',
      changeOrigin: true,
    },
  },
},
```

> **关键**：`/server/` 代理**没有 rewrite**，路径原样发给后端。因此 MagicAPI 的 group.json 里 `path` 必须以 `/server/` 开头，接口才能被调到。

**前端 API 调用规则：**
```
前端请求: POST /server/cla/stats
↓ Vite proxy
后端: POST http://127.0.0.1:9999/server/cla/stats

MagicAPI group.path = /server/cla
MagicAPI endpoint.path = /stats
完整路径 = /server/cla/stats  ✓
```

---

## 目录结构

```
src/
├── api/          # API 请求函数（按模块分文件）
├── components/   # 公共组件
│   ├── AppHeader.vue   # 顶部社区选择器
│   └── AppAside.vue    # 左侧导航菜单
├── views/        # 页面视图（每个路由一个目录）
│   ├── overview/       # 总览页
│   ├── cla/            # CLA 看板
│   └── ...
├── routers/      # 路由配置
│   ├── index.ts        # 主路由 + 路由守卫 + beta 默认权限
│   └── specialRoutes.ts # admin/editor 路由
├── stores/       # Pinia 状态管理
│   ├── common.ts       # 公共状态（社区、侧边栏）
│   └── login.ts        # 登录状态、权限
└── shared/
    └── common.const.ts  # COMMUNITY_ROUTING_MATRIX、PROD_COMMUNITY 等常量
```

---

## 新增页面的完整步骤

新增一个功能页面，需要修改以下 **5 个地方**：

### 第一步：创建 View 组件

```bash
src/views/{your-feature}/The{YourFeature}.vue
```

### 第二步：创建 API 函数

```typescript
// src/api/api-your-feature.ts
import { request } from '@/shared/utils/request';

export function fetchYourData(params: any) {
  return request.post('/server/{group_path}/{endpoint_path}', params).then(res => res.data);
}
```

> 注意：URL 直接写 `/server/xxx`，不要加 `/magic-api/` 前缀。

### 第三步：注册路由

在 `src/routers/index.ts` 的 `routes` 数组中添加：
```typescript
{ path: '/your-feature', name: 'your-feature', component: () => import('@/views/your-feature/TheYourFeature.vue') },
```

### 第四步：配置社区路由权限

在 `src/shared/common.const.ts` 中，找到 `COMMUNITY_ROUTING_MATRIX_FOR_PROD` 和 `COMMUNITY_ROUTING_MATRIX_FOR_TEST`，在对应社区的数组里加入路由名：
```typescript
openubmc: [...BASE_ROUTE_LIST, 'users', 'services', 'overview', 'services-analysis', 'cla', 'your-feature'],
```

### 第五步：添加侧边栏菜单项

在 `src/components/AppAside.vue` 里加 `el-menu-item`：
```html
<el-menu-item v-if="showItem('your-feature')" index="/your-feature">
  <el-icon><OIcon><IconDefault></IconDefault></OIcon></el-icon>
  <span>你的功能</span>
</el-menu-item>
```

### 第六步：更新 beta 模式默认权限

在 `src/routers/index.ts` 的 beta 模式权限数组里添加：
```typescript
const menuPermissions = [
  // ...现有权限...
  'your_feature_menu_view',  // 控制菜单项显示
];
```

> 如果是新增社区（而不是新功能），还需要加 `{community}_view`（如 `openubmc_view`），否则该社区不会出现在顶部社区选择器中。

---

## 社区选择器逻辑

顶部社区选择器（`AppHeader.vue`）的展示逻辑：

1. **`communityList`**：从 `/server/community/list` API 获取，在非生产模式下显示全部，生产模式只显示 `PROD_COMMUNITY` 里的
2. **`enabledCommunities`**：从 `loginStore.permissions` 里提取 `xxx_view`（过滤掉 `xxx_menu_view`）形式的权限，取前缀作为社区名
3. 只有同时在 `communityList` **且** 在 `enabledCommunities` 中的社区，才会出现在选择器里
4. 社区必须在 `src/shared/overview.ts` 的 `communityGroups` 里才能被渲染

**beta 模式下让社区出现在选择器的条件：**
- `/server/community/list` 返回该社区名（`community-list.ms` 里有）
- `routers/index.ts` beta 默认权限里有 `{community}_view`
- `src/shared/overview.ts` 的 `communityGroups` 里有该社区

---

## 常见开发模式

### 表格展示 + 分页
```vue
<template>
  <el-table :data="tableData" v-loading="loading">
    <el-table-column prop="field1" label="字段1" />
  </el-table>
  <el-pagination v-model:current-page="page" :total="total" @current-change="fetchData" />
</template>

<script setup lang="ts">
const loading = ref(false);
const tableData = ref([]);
const page = ref(1);
const total = ref(0);

async function fetchData() {
  loading.value = true;
  const res = await fetchYourData({ page: page.value, pageSize: 10 });
  if (res.code === 1) {
    tableData.value = res.data.list;
    total.value = res.data.total;
  }
  loading.value = false;
}
onMounted(fetchData);
</script>
```

---

## 注意事项

1. **API URL 格式**：`/server/{group_path}/{endpoint_path}`，不含 `/magic-api/` 前缀
2. **社区权限**：新功能需在 `COMMUNITY_ROUTING_MATRIX` 的 PROD 和 TEST 两个对象里都加
3. **beta 模式**：需在 `routers/index.ts` 的默认权限数组里加 `{feature}_menu_view` 和（新社区时）`{community}_view`
4. **菜单显示**：在 `AppAside.vue` 加 `el-menu-item` 后，还需要 beta 模式权限配合，`showItem()` 才会返回 true
5. **MagicAPI 文件修改**：改了 `.ms` 或 `group.json` 后必须重启 MagicAPI 服务才能生效
