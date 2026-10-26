# TPDiary 一期 Redis 键设计与一致性方案

**阶段**：P05 · Redis 键设计  
**版本**：v1.0  
**状态**：一期 Redis 使用基线  
**上游基线**：`P02-技术选型评审与ADR.md`、`P03-模块划分与依赖治理.md`、`P04-数据库设计.md`

## 一、结论

1. MySQL 中的额度批次、额度流水和额度发放计数是唯一业务真相；Redis 只缓存、索引和协调并发。
2. 余额展示可以读 Redis 快照；开启躺平、消费额度、专注结算和节点奖励必须进入数据库事务。
3. Redis 丢失或重启不改变已发放额度，也不能扩大日/周上限。
4. Redis 键统一使用 `tpdiary:v1:` 前缀，不存放手机号、密码、明文 Token 或视频数据。
5. 服务端业务时区统一为 `Asia/Shanghai`；日界为自然日 00:00，周界为周一 00:00。
6. 专注结算的业务时间取首次被服务端接受的 `t_focus_session.end_time`，不取数据库提交时间。

## 二、键命名规范

```text
tpdiary:v1:<domain>:<object>:{identifier}[:<period>]
```

- `tpdiary`：应用固定前缀。
- `v1`：键结构版本；不兼容变更时升级版本。
- `domain`：`quota`、`focus`、`lock`、`jwt`、`post`。
- `object`：业务对象，如 `bal`、`expire`、`grant`。
- `identifier`：使用内部用户 ID、会话 ID、批次 ID 或 JWT `jti`，禁止使用手机号。
- `period`：日键使用 `yyyyMMdd`，周键使用 ISO 周 `YYYYWww`，周从周一开始。
- 整数秒在 Redis 中保存为十进制字符串，不使用浮点数或带单位文本。

示例：

```text
tpdiary:v1:quota:bal:1001
tpdiary:v1:quota:grant:day:1001:20261023
tpdiary:v1:quota:grant:week:1001:2026W43
tpdiary:v1:post:unlock:1001:20261023
```

## 三、Redis 键设计表

| Key 模式 | 类型 | Value 结构 | TTL | 写入时机 | 读取场景 |
|---|---|---|---|---|---|
| `tpdiary:v1:quota:bal:{userId}` | Hash | `total_remain_seconds`：有效余额秒数；`active_batch_count`：有效批次数；`next_expire_at_ms`：最近到期时间；`batch:{batchId}:remain_seconds`：批次余额；`batch:{batchId}:expire_at_ms`：批次到期时间；`refreshed_at_ms`：快照刷新时间 | 固定 300 秒；读取不续期 | 额度发放、消费、过期提交后重建；缓存未命中时从 DB 重建 | 首页余额、额度明细摘要和下次到期展示；**不用于最终消费判定** |
| `tpdiary:v1:quota:expire:{userId}` | ZSet | member=`batchId`，score=`expireAt` 的 Unix 毫秒时间戳 | 最近一次写入后 8 天 | 额度批次创建、重建索引时 `ZADD`；消费完或过期完成后 `ZREM` | 查最近到期批次、筛选即将到期批次、为提醒扫描提供候选 |
| `tpdiary:v1:quota:grant:day:{userId}:{yyyyMMdd}` | String | 当日已发放额度秒数，十进制整数 | 在业务日结束后 10 分钟过期 | 每日发放提交后重建或 `INCRBY 实得秒数`；重试以 DB 为准重建 | 快速展示当日获得量；结算预检；不替代 DB 计数 |
| `tpdiary:v1:quota:grant:week:{userId}:{YYYYWww}` | String | 当周已发放额度秒数，十进制整数 | 在业务周结束后 10 分钟过期 | 每周发放提交后重建或 `INCRBY 实得秒数`；重试以 DB 为准重建 | 快速展示当周获得量；结算预检；不替代 DB 计数 |
| `tpdiary:v1:focus:current:{userId}` | Hash | `sessionId`；`status`；`startTimeMs`；`lastHeartbeatAtMs`；`pausedTotalSeconds`；`invalidSeconds`；`serverVersion` | 最近心跳后 600 秒；每次有效心跳重置 | 开始、暂停、恢复、心跳、结束时更新；结束后删除 | 当前会话快速恢复和客户端状态展示 |
| `tpdiary:v1:lock:quota:{userId}` | String | 随机 UUID owner token | 10 秒 | 进入额度结算、扣减或过期处理事务前使用 `SET NX PX` 获取 | 额度写入互斥；释放时用 Lua 比较 owner 后删除 |
| `tpdiary:v1:jwt:black:{jti}` | String | 固定值 `"1"` | `max(0, token.exp - 当前服务端时间)`；Token 到期后自动删除 | 退出登录、密码重置、账号禁用等令牌撤销事件 | 每次 Token 鉴权时执行 `EXISTS`，已撤销则拒绝 |
| `tpdiary:v1:post:unlock:{userId}:{yyyyMMdd}` | String | 固定值 `"1"` | 在业务日结束后 5 分钟过期 | 当日累计有效专注首次达到 1800 秒并提交 DB 后写入 | 发帖前快速判断；缺失时回源 `t_daily_stat.post_unlocked` |
| `tpdiary:v1:lock:job:{jobName}:{periodId}` | String | 随机 UUID owner token | 任务最长预计执行时间加 30 秒 | 定时任务启动时使用 `SET NX PX` 获取；任务结束比较 owner 后释放 | 防止任务重入；一期单实例不是必需，多实例时必须 |

### 3.1 余额快照字段约束

- `total_remain_seconds` 必须等于所有有效 `batch:{batchId}:remain_seconds` 之和。
- `active_batch_count` 必须等于有效批次字段数量。
- `batch:{batchId}:remain_seconds` 只缓存 `status=1`、`expire_at > now` 且 `remain_seconds > 0` 的批次。
- 快照只用于展示和预检；开启躺平和实际扣减必须锁定数据库批次行。
- 写入快照使用 `DEL` 后批量 `HSET`，或先写临时键再重命名；出现半写冲突时立即删除缓存。
- 余额键使用短 TTL，读取不延长 TTL，避免长期掩盖失效失败。

### 3.2 计数键约束

- 日/周计数只累加实际发放的 `earned_seconds`，不是理论换算值。
- 节点奖励和专注结算都计入同一个日/周计数。
- 键中包含周期 ID，即使旧周期请求跨过 00:00 到达，也不会覆盖新周期键。
- Redis 计数不参与最终 `min(理论额度, 日剩余, 周剩余)` 决策；最终值来自数据库事务计数。

### 3.3 锁约束

锁 Value 只保存随机 owner token，不保存用户余额。释放动作为：

```text
EVAL:
  if GET(lockKey) == ownerToken then DEL(lockKey) else return 0
```

不得使用无条件 `DEL` 释放锁。锁过期后即使另一个请求取得锁，数据库行锁、唯一键和余额非负校验仍负责最终一致性。

## 四、额度写入流程

### 4.1 专注结算与节点奖励

```text
服务端接受结束/领取命令
  -> 固定业务时间与周期 ID
  -> 获取用户级 Redis 锁（可选加速）
  -> 开启数据库事务
  -> 锁定 t_quota_grant_counter 的日/周行
  -> 按规则 1 计算理论额度
  -> 与 DB 日/周剩余上限取最小值
  -> 写额度批次、收入流水和计数
  -> 提交
  -> 失效并重建 Redis 余额、过期索引和日/周计数
```

任一 Redis 更新失败只记录告警，不回滚已提交的数据库交易。下一次读取按 DB 重建。

### 4.2 躺平扣减

```text
服务端心跳
  -> 获取用户级 Redis 锁（可选加速）
  -> 数据库锁定 t_rest_session
  -> 按 expire_at 升序锁定有效额度批次
  -> 校验余额、扣减批次、写支出流水
  -> 提交
  -> 刷新余额缓存和过期索引
```

余额不足时直接结束躺平会话。客户端本地时钟只用于展示，不作为扣减依据。

### 4.3 额度过期

```text
从 Redis ZSet 获取候选（Redis不可用时扫描 DB）
  -> 逐批数据库条件更新 status=3、remain_seconds=0
  -> 写 direction=3 的幂等过期流水
  -> 提交
  -> 从 ZSet 删除批次并重建余额快照
```

Redis ZSet 只是候选索引，最终是否过期由数据库 `status`、`expire_at` 和条件更新决定。

## 五、跨天与跨周归属规则

### 5.1 唯一规则

**专注会话整体归属于首次被服务端接受的结束时间 `end_time` 所在的业务日和业务周。**

具体执行：

1. 停止请求由服务端接收时，服务端 Clock 生成一次 `end_time`。
2. timer 先以原子条件更新关闭会话并提交 `end_time`、结束状态和 `settled=0`；额度结算失败时由定时补偿重试，不重新生成 `end_time`。
3. `settlement_date = date(end_time, Asia/Shanghai)`。
4. `week_start = end_time 所在周周一 00:00`，周键使用 ISO 年和周。
5. 数据库 `t_quota_batch.grant_time`、`grant_date`、日/周计数和 Redis 周期键都使用该业务时间。
6. 数据库提交时间、客户端时间、消息消费时间不参与周期归属。
7. 一个专注会话不跨日拆分；跨午夜后结束的会话整体归结束业务日。

### 5.2 23:59:59 示例

服务端在 `2026-10-23 23:59:59.700 Asia/Shanghai` 接受停止请求，数据库在 `2026-10-24 00:00:01` 才写入额度批次：

```text
归属业务日：2026-10-23
日键：tpdiary:v1:quota:grant:day:{userId}:20261023
归属业务周：2026-10-19 至 2026-10-25
周键：tpdiary:v1:quota:grant:week:{userId}:2026W43
```

即使数据库插入发生在 00:00:01，也不能改归 2026-10-24。若服务端直到 00:00:01 才实际接收到停止请求，则归属 2026-10-24；以服务端接收时间为准。

### 5.3 边界保护

- 日/周 Redis 键在周期结束后保留 10 分钟，支持结算提交晚于 00:00 的落库。
- 周期键过期不影响 DB 计数；重试会按 `end_time` 重建正确周期的缓存。
- 客户端回传时间只能作为展示数据，必须经过服务端时间窗口校验。
- 发帖资格使用同一 `end_time` 归属的业务日累计有效专注秒数。

## 六、一致性问题回答

### 6.1 Redis 日/周计数与 `t_daily_stat` 不一致，以谁为准？

**数据库额度账本和 `t_quota_grant_counter` 为准，二者不能被 Redis 或统计投影反向修正。**

- `t_quota_grant_counter`：额度上限判定的数据库事务真相。
- `t_quota_batch` + `t_quota_ledger`：实际发放事实。
- `t_daily_stat`：展示投影，允许在事件延迟时短暂落后。
- Redis 日/周计数：短 TTL 加速值，任何时刻都允许丢失。

若 Redis 与 `t_daily_stat` 不一致：

1. 禁止根据 Redis 调整 `t_daily_stat`、批次、流水或发放计数。
2. 重新计算该用户对应周期的已发放秒数。
3. 先核对批次与流水净额是否满足 P04 的账本等式。
4. 账本一致时，用数据库发放计数修正 `t_daily_stat`，再删除并重建 Redis 周期键。
5. 账本不一致时冻结该用户额度写入，告警并进行人工对账。

日统计重算口径：

```sql
SELECT
    user_id,
    grant_date,
    SUM(CAST(amount_seconds AS SIGNED)) AS earned_seconds
FROM t_quota_batch
WHERE deleted = 0
GROUP BY user_id, grant_date;
```

该结果中的 `earned_seconds` 应与同一用户、同一日期的事务性发放计数和 `t_daily_stat.earned_seconds` 一致。过期批次仍计入“曾经获得”，因此不按 `status=1` 过滤。

### 6.2 Redis 重启导致计数丢失，如何防止重复发放？

Redis 重启不会导致重复发放，因为发放判定不依赖 Redis：

1. 每次发放在 MySQL 事务内锁定 `t_quota_grant_counter` 的日/周行。
2. 从 DB 读取当日和当周已发放秒数，计算两个剩余上限。
3. `uk_quota_batch_source(user_id, source_type, source_id)` 阻止同一来源重复建批次。
4. `uk_quota_ledger_idempotency(user_id, idempotency_key)` 阻止重复入账。
5. 同一专注会话和任务节点只能产生一次有效发放。
6. Redis 未命中时按 DB 计数重建；重建失败时本次请求仍可使用 DB 完成。

若 DB 计数行缺失但批次和流水存在，需在用户锁和数据库事务内根据批次 `grant_date` 重新计算周期汇总，再补建计数行；不能从 Redis 补 DB。

### 6.3 23:59:59 发起、00:00:01 落库，归属哪一天？

若服务端在 23:59:59 接受停止请求并记录 `end_time=23:59:59`，则归属**前一日**；00:00:01 只是数据库提交时间，不改变周期。若服务端实际接收时已经是 00:00:01，则归属**新一日**。

跨周同理：归属 `end_time` 所在的自然周，周一开始。

## 七、缓存失效与降级方案

| Key 或能力 | Redis 故障时是否可降级 | 降级方式 | 边界 |
|---|---|---|---|
| 额度余额快照 | 可以 | 查询 `t_quota_batch` 有效批次汇总；操作完成后可暂不写缓存 | 展示可能变慢，金额不变 |
| 过期批次 ZSet | 可以 | 扫描 `t_quota_batch(status=1, expire_at<=now)` | 到期判定仍以 DB 为准 |
| 日/周获取计数 | 可以 | 读取 `t_quota_grant_counter`，缺失时在锁内重建 | 不得跳过 DB 校验 |
| 当前专注会话 | 可以 | 查询 `t_focus_session(user_id,status)` | 断线恢复变慢但可恢复 |
| 额度锁 | 可以 | 使用数据库行锁和唯一键串行化同一用户写入 | Redis 锁只减少争用，不是正确性来源 |
| JWT 黑名单 | **不可以** | 无法确认撤销状态时保护接口 fail closed；恢复后再放行 | 不能把未知状态当作“未撤销” |
| 发帖资格标记 | 可以 | 查询 `t_daily_stat.post_unlocked`；必要时按有效专注重算 | 资格结果必须准确 |
| 定时任务锁 | 单实例可以，多实例不可以 | 一期单实例继续执行；多实例时停止自动任务并保留人工补跑 | 防止重复任务和数据错乱 |
| 额度数据库 | **不可以** | Redis 不得充当账号余额或流水账本 | 数据库不可用时停止额度发放和消费 |

### 7.1 缓存穿透、击穿和雪崩

- 用户余额和资格不使用不存在的空值长期缓存；未命中时回源 DB。
- 余额 TTL 固定且不随读取续期，避免热点键永不过期。
- 用户级 Key 分散，不使用全站单 Key 保存所有余额。
- JWT 黑名单只缓存已撤销 Token；未命中表示需要继续走正常验签逻辑，不写永久空值。
- Redis 批量失效失败时记录告警，由短 TTL 和下一次 DB 读取修复。

## 八、验收清单

| 验收项 | 通过标准 | 负责人 |
|---|---|---|
| 命名规范 | 所有键使用 `tpdiary:v1:` 前缀，键中无手机号、JWT 明文或其他敏感信息 | 后端 |
| 必备键齐全 | 余额、过期 ZSet、日/周计数、当前专注、额度锁、JWT 黑名单、发帖资格全部存在 | 后端 |
| DB 为账本真相 | 余额、计数、锁相关流程均保留 DB 事务、行锁和唯一键校验 | 后端；测试 |
| Redis 清空恢复 | 清空 Redis 后仍可结算、扣减、展示余额并重建缓存 | 测试 |
| 并发不超支 | Redis 锁丢失或过期时，唯一键与 DB 行锁仍能阻止负余额和重复入账 | 后端；测试 |
| 跨天归属 | 23:59:59 服务端接受、00:00:01 落库归前一日；00:00:01 接收归新一日 | 后端；测试 |
| 跨周归属 | 周从周一 00:00 开始，周期由 `end_time` 决定 | 后端；测试 |
| JWT 故障策略 | Redis 不可用时保护接口 fail closed，不将撤销状态视为有效 | 后端；测试 |
| 过期扫描 | Redis ZSet 丢失后 DB 扫描仍能完成过期流水和余额修正 | 后端；测试 |
| 发帖资格 | Redis 未命中时从 DB 获取，1800 秒阈值和次日重置规则保持准确 | 后端；测试 |
