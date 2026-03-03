# 前端 UI 规范与组件复用手册

本文档基于 release 分支的实际代码归纳，新增任何页面/图表都必须遵循此规范，保持风格统一。

---

## 1. 页面整体布局

### 标准结构（参考 service 页、developer 页）

```vue
<template>
  <!-- 1. 顶部筛选栏（固定在外，不随内容滚动） -->
  <div class="content-header">
    <OLabel name="筛选项">
      <!-- el-select / el-date-picker 等 -->
    </OLabel>
    <OLabel name="时间">
      <el-date-picker
        v-model="timeRange"
        type="daterange"
        range-separator="To"
        start-placeholder="开始时间"
        end-placeholder="结束时间"
        :clearable="false"
      />
    </OLabel>
  </div>

  <!-- 2. 可滚动内容区 -->
  <el-scrollbar>
    <div class="content-body">
      <!-- 每个逻辑块用 MoreCard 包装 -->
      <MoreCard title="卡片标题">
        <template #content>
          <!-- 卡片内容 -->
        </template>
      </MoreCard>
    </div>
  </el-scrollbar>
</template>

<style scoped lang="scss">
.content-header {
  display: flex;
  gap: 24px;
  margin-bottom: var(--o-spacing-h4);  /* 24px */
}
.content-body {
  display: grid;
  row-gap: 24px;
  padding-bottom: 24px;
}
</style>
```

### 关键组件说明

| 组件 | 作用 | 用法 |
|------|------|------|
| `OLabel` | 标签+内容对 | `<OLabel name="时间"><el-date-picker /></OLabel>` |
| `MoreCard` | 带标题的内容卡片 | `<MoreCard title="xxx"><template #content>...</template></MoreCard>` |
| `el-scrollbar` | 内容区滚动容器 | 包裹 `content-body`，不要用 `overflow: auto` |

### MoreCard 的两种用法

```vue
<!-- 用法1：简单标题 -->
<MoreCard title="开发者趋势">
  <template #content>
    <YourChart />
  </template>
</MoreCard>

<!-- 用法2：标题区有额外内容（数字、按钮等） -->
<MoreCard>
  <template #title>
    <ServiceTotal :common-params="commonParams" />
  </template>
  <template #content>
    <ServiceDetail />
  </template>
</MoreCard>
```

---

## 2. 时间筛选 + 数据联动

### 标准时间筛选写法（参考 service 页）

```typescript
import { formatDate } from '@/shared/utils/dateutils';
import { OPEN_SOURCE_TIME } from '@/shared/common.const';
import { useCommonData } from '@/stores/common';

const { community } = useCommonData();

// 默认时间范围：从社区开源时间到今天
const timeRange = ref<number[]>([
  new Date(OPEN_SOURCE_TIME[community.value] || '2024-11-01').getTime(),
  Date.now(),
]);

// 社区切换时重置时间
watch(community, (val) => {
  timeRange.value = [new Date(OPEN_SOURCE_TIME[val] || '2024-11-01').getTime(), Date.now()];
});

// 禁用未来日期
const now = new Date();
const disabledDate = (date: Date) => date > now;

// 统一传给所有 API 的参数对象
const commonParams = computed(() => ({
  community: community.value,
  start_time: formatDate(new Date(timeRange.value?.[0] ?? 0)),  // 'yyyy-MM-dd'
  end_time: formatDate(new Date(timeRange.value?.[1] ?? 0)),
}));

// 时间或社区变化时重刷数据
watch(commonParams, fetchAll, { deep: true });
```

---

## 3. ECharts 图表使用

### 3.1 OChart 基础组件

```vue
<OChart
  :auto-resize="true"
  width="100%"
  height="300px"
  :option="chartOption"
/>
```

| Prop | 类型 | 说明 |
|------|------|------|
| `option` | EChartsOption | 图表配置（必填） |
| `width` | String | 宽度，通常用 `'100%'` |
| `height` | String | 高度，如 `'300px'` |
| `autoResize` | Boolean | 随容器自动调整大小，一般设 true |

> OChart 会自动合并 `ECHARTOPTION` 中的调色盘，不用手动设置 `color`。

### 3.2 调色盘（按顺序使用）

```
#002FA7 (深蓝)  → 第1系列
#FEB32A (金黄)  → 第2系列
#4AAEAD (青绿)  → 第3系列
#FC756C (红橙)  → 第4系列
#A4DAFF (浅蓝)  → 第5系列
#6236FF (紫色)  → 第6系列
```

单系列时显式指定颜色（保持语义一致）：
```typescript
// 开发者/人数类 → 深蓝
itemStyle: { color: '#002FA7' }

// 企业类 → 深蓝
itemStyle: { color: '#002FA7' }

// 个人类 → 绿
itemStyle: { color: '#67c23a' }

// 正增长/上升 → 红
color: '#EB2A0A'

// 负增长/下降 → 绿
color: '#2BEB0C'
```

### 3.3 折线图/柱状图 option 模板

```typescript
// shallowRef 用于大对象（避免深度响应性能问题）
const chartOption = shallowRef({});

function buildChartOption(data: any[]) {
  chartOption.value = {
    tooltip: { trigger: 'axis' },
    legend: { bottom: 0 },
    grid: { left: 80, right: 20, top: 20, bottom: 50 },
    toolbox: {
      feature: {
        dataView: {
          show: true,
          readOnly: true,
          lang: ['数据详情', '关闭'],
          title: '查看详情',
          optionToContent: (opt: any) => {
            // 生成自定义表格 HTML
            const dates = opt.xAxis[0].data;
            const series = opt.series;
            return `<table class="custom-data-view">
              <thead><tr>
                <th>日期</th>
                ${series.map((s: any) => `<th>${s.name}</th>`).join('')}
              </tr></thead>
              <tbody>
                ${dates.map((d: string, i: number) => `<tr>
                  <td>${d}</td>
                  ${series.map((s: any) => `<td>${s.data[i] ?? '-'}</td>`).join('')}
                </tr>`).join('')}
              </tbody>
            </table>`;
          },
        },
        magicType: {
          show: true,
          type: ['line', 'bar'],
          title: { line: '切换为折线图', bar: '切换为柱状图' },
        },
        saveAsImage: { show: true, title: '保存为图片' },
      },
    },
    calculable: true,
    xAxis: { type: 'category', data: data.map((d) => d.date) },
    yAxis: { type: 'value', name: '人数', minInterval: 1 },
    series: [
      {
        name: '企业',
        type: 'bar',
        stack: 'count',           // 同名 stack → 堆叠
        data: data.map((d) => d.enterprise),
        itemStyle: { color: '#002FA7' },
      },
      {
        name: '个人',
        type: 'bar',
        stack: 'count',
        data: data.map((d) => d.individual),
        itemStyle: { color: '#67c23a' },
      },
    ],
  };
}
```

### 3.4 Dataset 模式（多系列）

适用于数据结构复杂、需要复用字段名的场景（参考 DeveloperTrend.vue）：

```typescript
const dataset = shallowRef({
  dimensions: ['date', 'total', 'increase'],
  source: [] as any[],
});

const chartOption = shallowRef({});

function buildOption() {
  chartOption.value = {
    dataset: [dataset.value],
    tooltip: { trigger: 'axis' },
    grid: { left: 80, right: 20 },
    legend: { bottom: 10 },
    xAxis: { type: 'category' },
    yAxis: { type: 'value' },
    series: [
      {
        name: '增量',
        type: 'bar',
        encode: { x: 'date', y: 'increase' },
        datasetIndex: 0,
        itemStyle: { color: '#002FA7' },
      },
      {
        name: '总量',
        type: 'line',
        encode: { x: 'date', y: 'total' },
        datasetIndex: 0,
        itemStyle: { color: '#FEB32A' },
      },
    ],
  };
}
```

### 3.5 封装的图表组件（优先使用）

| 组件 | 适用场景 | 数据格式 |
|------|---------|---------|
| `OChartLine` | 多系列折线图，带 toolbox | `{ xAxis: string[], series: [{name, data, type?}] }` |
| `OChartBar` | 柱状图，带 toolbox | 同上，type 默认 'bar' |
| `OChartPie` | 饼图/环形图 | `[{ name, value }]` |
| `OChartFunnel` | D0/D1/D2 漏斗图 | `[{ name, value, wowratio, momratio }]` |
| `OChartTextV2` | 数值卡片（周/月环比） | `{ name, value, week_rate, month_rate }` |
| `OChartTextV3` | 同上，支持 '-' 值 | 同上，rate 可为 `'-'` |

**直接用 OChart 的场景：**
- 需要堆叠柱状图
- 需要 dataset 模式
- 需要高度自定义的图表

---

## 4. OFormRadio 间隔/指标选择器

```typescript
import { FormRadioConfig } from '@/shared/formRadio.interface';

// 配置定义
const radioConfig: FormRadioConfig[] = [
  {
    label: '间隔周期',
    id: 'interval',
    options: [
      { label: '天', value: 'daily' },
      { label: '周', value: 'week' },
      { label: '月', value: 'month' },
    ],
  },
  {
    label: '度量指标',
    id: 'metrics',
    options: [
      { label: 'D0', value: 'D0' },
      { label: 'D1', value: 'D1' },
      { label: 'D2', value: 'D2' },
    ],
  },
];

// 双向绑定的值
const radioValue = ref({ interval: 'month', metrics: 'D1' });
```

```vue
<OFormRadio v-model="radioValue" :option="radioConfig" />
```

> OFormRadio 内部用 `el-scrollbar` 包裹，选项多时自动横向滚动，不要手动加滚动。

---

## 5. 表格规范

### 标准 el-table 配置

```vue
<el-table
  :data="tableData"
  v-loading="loading"
  stripe
  style="width: 100%"
  @sort-change="handleSortChange"
  @filter-change="handleFilterChange"
>
  <!-- 普通列 -->
  <el-table-column prop="name" label="姓名" width="120" sortable="custom" />

  <!-- 溢出省略 -->
  <el-table-column prop="company" label="公司" min-width="180" show-overflow-tooltip sortable="custom" />

  <!-- 列头筛选（服务端） -->
  <el-table-column
    prop="sign_type"
    label="类型"
    width="120"
    column-key="sign_type"
    :filters="[{ text: '企业', value: '企业' }, { text: '个人', value: '个人' }]"
    :filter-multiple="false"
    :filter-method="() => true"
  >
    <template #default="{ row }">
      <el-tag :type="row.sign_type === '企业' ? 'primary' : 'success'" size="small">
        {{ row.sign_type }}
      </el-tag>
    </template>
  </el-table-column>

  <!-- 自定义内容 -->
  <el-table-column prop="created_at" label="时间" width="160" sortable="custom">
    <template #default="{ row }">
      {{ row.created_at?.slice(0, 10) ?? '-' }}
    </template>
  </el-table-column>
</el-table>
```

### 服务端排序处理

```typescript
function handleSortChange({ prop, order }: { prop: string; order: string | null }) {
  sortField.value = prop || 'created_at';
  sortOrder.value = order === 'ascending' ? 'ASC' : 'DESC';
  fetchList();
}
```

### 服务端列头筛选处理

```typescript
function handleFilterChange(filters: Record<string, string[]>) {
  const val = filters['sign_type'];
  filterValue.value = val?.length ? val[0] : '';
  currentPage.value = 1;
  fetchList();
}
```

### 分页组件

```vue
<el-pagination
  v-model:current-page="currentPage"
  v-model:page-size="pageSize"
  :total="total"
  :page-sizes="[10, 20, 50]"
  layout="total, sizes, prev, pager, next"
  @current-change="handlePageChange"
  @size-change="() => { currentPage = 1; fetchList(); }"
/>
```

---

## 6. CSS 变量速查

### 间距

```scss
--o-spacing-h4: 24px   /* 卡片间距、header 底边距 */
--o-spacing-h5: 16px   /* 组件内部间距 */
--o-spacing-h6: 12px   /* 小元素间距 */
--o-spacing-h8: 8px    /* 极小间距 */
```

### 颜色

```scss
/* 品牌色 */
--o-color-brand1           /* 主色，等同于 #002FA7 */

/* 文字 */
--o-color-text1            /* 主要文字（标题） */
--o-color-text4            /* 次要文字（标签、描述） */

/* 分割线 */
--o-color-division1        /* 用于 border-bottom 分隔 */

/* 背景 */
--o-color-bg2              /* 卡片/侧边栏背景 */
--o-color-fill2            /* 投影容器背景 */
```

### 阴影

```scss
--o-shadow-l1              /* 轻阴影，用于顶部导航 */
--o-shadow-l2              /* 中阴影，用于卡片 */
--o-shadow-l2_hover        /* 卡片悬浮阴影 */
```

---

## 7. 新增页面 Checklist

新增一个标准数据看板页面，必须完成：

**文件结构：**
- [ ] `src/views/{name}/The{Name}.vue` — 页面组件
- [ ] `src/api/api-{name}.ts` — API 函数（含 TypeScript 类型）

**路由注册（5处缺一不可）：**
- [ ] `src/routers/index.ts` — 加入 `routes` 数组
- [ ] `src/shared/common.const.ts` — PROD 和 TEST 矩阵各加一条
- [ ] `src/components/AppAside.vue` — 加 `el-menu-item`
- [ ] `src/routers/index.ts` beta 模式 — 加 `{feature}_menu_view` 权限
- [ ] （新社区）beta 模式加 `{community}_view` 权限

**布局规范：**
- [ ] 使用 `content-header` + `OLabel` + `el-date-picker` 作为顶部筛选
- [ ] 使用 `el-scrollbar` 包裹 `content-body`
- [ ] 用 `MoreCard` 包装每个逻辑块
- [ ] 统一使用 `--o-spacing-*` 和 `--o-color-*` CSS 变量

**图表规范：**
- [ ] 优先使用 `OChartLine` / `OChartBar` 封装组件
- [ ] 自定义图表用 `OChart`，option 存 `shallowRef`
- [ ] 颜色按调色盘顺序取，或按语义（蓝=企业，绿=个人）
- [ ] 标配 toolbox：dataView + magicType（line/bar）+ saveAsImage
- [ ] 设置 `minInterval: 1`（人数类整数坐标轴）
