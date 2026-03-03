# 数据采集服务 om-dataarts Skill

## 服务概述

Python 数据采集服务，负责从各开源社区平台（Gitee、GitHub、CLA、下载量等）抓取数据，存入 PostgreSQL 数据库，供 MagicAPI 提供 API 接口。

- **项目路径**：`/home/zj/claude/datastat-manage/om-dataarts`
- **语言**：Python 3
- **数据库**：PostgreSQL（本地 onedata 数据库）
- **配置文件**：`config.yaml`

---

## 数据库配置

配置文件：`om-dataarts/config.yaml`

本地正确配置（需改为 onedata）：
```yaml
database:
  host: localhost
  port: 5433
  name: onedata
  user: onedata
  password: onedata
```

> 注意：默认 config.yaml 里是 `datastat/datastat123`，本地数据库是 `onedata/onedata`，运行前需确认。

---

## 项目结构

```
om-dataarts/
├── config.yaml          # 配置文件（数据库、API Token 等）
├── main.py              # 主入口
├── collect_data.py      # 数据采集入口
├── requirements.txt     # 依赖
├── om/
│   ├── api/             # 外部 API 客户端（Gitee、GitHub、CLA 等）
│   ├── collector/       # 数据采集逻辑（一个功能一个文件）
│   ├── config/
│   │   ├── config_loader.py   # 配置加载器
│   │   ├── models.py          # 配置模型（dataclass）
│   │   └── constant.py        # 常量
│   ├── db/
│   │   ├── postgres_client.py # 数据库客户端（封装 psycopg2）
│   │   └── table/             # 建表管理
│   │       ├── table_management.py  # 建表工具（支持自动建表、升级列）
│   │       └── *_table.py           # 各模块的表配置
│   └── tasks/           # 可独立运行的采集任务脚本
│       ├── cla_task.py
│       ├── cve_task.py
│       └── ...
└── tests/               # 单元测试
```

---

## 运行方式

### 安装依赖

```bash
cd /home/zj/claude/datastat-manage/om-dataarts
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install -e .    # 以开发模式安装，使 om.* 包可以 import
```

### 运行单个采集任务

```bash
cd /home/zj/claude/datastat-manage/om-dataarts
source venv/bin/activate

# 示例：运行 CLA 数据采集
python om/tasks/cla_task.py --config config.yaml --communities openubmc

# 示例：运行 CVE 数据采集
python om/tasks/cve_task.py --config config.yaml --communities openeuler
```

任务文件基本格式：
```python
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, help="Path to config file")
    parser.add_argument("--communities", required=True, help="community list")
    args = parser.parse_args()
    config = ConfigLoader.load_config(args.config)
    # ... 初始化客户端，执行采集
```

---

## 新增数据采集任务的步骤

### 第一步：设计数据表结构

确定要存入哪个表，表名规律：
- `fact_{community}_{topic}` — 事实表（如 `fact_openubmc_cla_user`）
- `dim_{topic}` — 维度表（如 `dim_day`）

### 第二步：创建建表配置（可选，如果表不存在）

在 `om/db/table/` 下找合适的文件（或新建），添加表配置：
```python
def get_your_table_config(self, table_name):
    return {
        "table_name": table_name,
        "columns": [
            {"name": "id", "type": "SERIAL PRIMARY KEY"},
            {"name": "uuid", "type": "VARCHAR(64) NOT NULL"},
            {"name": "community", "type": "VARCHAR(64)"},
            {"name": "user_login", "type": "VARCHAR(255)"},
            {"name": "created_at", "type": "TIMESTAMP DEFAULT NOW()"},
        ],
        "constraints": {
            "unique": ["uuid"]
        }
    }
```

### 第三步：创建 Collector 类

在 `om/collector/` 下新建文件：
```python
# om/collector/your_feature.py
from om.db.postgres_client import PostgresClient

class YourFeature:
    def __init__(self, community: str, db_client: PostgresClient, ...):
        self.community = community
        self.db_client = db_client
        self.table_name = f'fact_{community}_your_table'

    def run(self):
        data = self._fetch_data()
        self._write_to_db(data)

    def _fetch_data(self):
        # 调用 API 客户端或直接查询
        pass

    def _write_to_db(self, data):
        self.db_client.upsert_by_batch(
            table=self.table_name,
            data=data,
            conflict_key="uuid"
        )
```

### 第四步：创建任务入口脚本

在 `om/tasks/` 下新建：
```python
# om/tasks/your_feature_task.py
import argparse
from om.collector.your_feature import YourFeature
from om.config.config_loader import ConfigLoader
from om.db.postgres_client import PostgresClient

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--communities", required=True)
    args = parser.parse_args()

    config = ConfigLoader.load_config(args.config)
    community_list = [c.strip("'") for c in args.communities.split(",")]

    db_client = PostgresClient(
        host=config.database.host,
        port=config.database.port,
        dbname=config.database.name,
        user=config.database.user,
        password=config.database.password
    )

    for community in community_list:
        feature = YourFeature(community=community, db_client=db_client)
        feature.run()
```

---

## PostgresClient 常用方法

```python
# 查询（返回 list of dict）
rows = db_client.execute_query("SELECT * FROM your_table WHERE community = %s", (community,))

# 批量 upsert（有冲突则更新，无冲突则插入）
db_client.upsert_by_batch(
    table="fact_openubmc_cla_user",
    data=[{"uuid": "xxx", "user_login": "yyy", ...}, ...],
    conflict_key="uuid"
)

# 执行任意 SQL
db_client.execute_query("CREATE TABLE IF NOT EXISTS ...")
```

---

## 查看已有数据表

```bash
# 连接本地数据库
psql -h localhost -p 5433 -U onedata -d onedata

# 查看所有表
\dt

# 查看特定表结构
\d fact_openubmc_cla_user

# 查询数据
SELECT * FROM fact_openubmc_cla_user LIMIT 5;
```

---

## 配置文件说明

`config.yaml` 中各模块配置按需添加，ConfigLoader 会自动解析对应 Section：

```yaml
database:            # 必须
  host: localhost
  port: 5433
  name: onedata
  user: onedata
  password: onedata

cla:                 # CLA 数据采集需要
  cla_token: 'xxx'
  cla_api: 'https://cla.xxx.com/api'

api:                 # Gitee/GitHub API
  access_token: 'xxx'
  base_url: 'https://gitee.com/api/v5'
```

---

## 常用采集任务参考

| 任务文件 | 功能 | 产出表 |
|---------|------|--------|
| `cla_task.py` | CLA 签署用户 | `fact_{community}_cla_user`, `fact_{community}_cla_company` |
| `cve_task.py` | CVE 漏洞数据 | 相关 CVE 表 |
| `sig_info.py` | SIG 组信息 | SIG 相关表 |
| `commit_user_info_task.py` | commit 贡献者 | commit 相关表 |
| `health_task.py` | 社区健康度 | 健康度相关表 |
