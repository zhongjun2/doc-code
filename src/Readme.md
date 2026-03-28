## 同步配置
```
### ========== 上游数据库配置（自行修改） ==========
UPSTREAM_HOST=""       # 上游数据库 IP
UPSTREAM_PORT="5432"                 # 上游端口
UPSTREAM_USER=""             # 上游用户名
UPSTREAM_PASS=""        # 上游密码
UPSTREAM_DB=""                # 上游数据库名

### ========== 本地数据库配置 ==========
LOCAL_HOST="localhost"
LOCAL_PORT="5432"
LOCAL_USER="<db user>"
LOCAL_PASS="<password>"
LOCAL_DB="<db name>"
```



## 同步命令
```
./sync_community_tables.sh openeuler
```
