-- TPDiary 一期 MVP 初始化脚本（V1）
-- 目标数据库：MySQL 8.0.16+
-- 约定：
-- 1. 所有金额和时长统一使用 BIGINT 存储秒数，不使用浮点类型。
-- 2. create_time/update_time 使用数据库时间；业务判定使用服务端应用时间。
-- 3. deleted=1 仅供可变业务数据逻辑删除；流水、事件等追加型表不得更新为已删除。
-- 4. 不建立物理外键，引用完整性由 application/domain 层维护，避免模块边界和数据迁移耦合。

SET NAMES utf8mb4;

CREATE TABLE t_user (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '用户ID',
    phone VARCHAR(20) NOT NULL COMMENT '手机号',
    password_hash VARCHAR(255) NULL COMMENT '密码哈希；验证码用户可为空',
    nickname VARCHAR(50) NOT NULL DEFAULT '' COMMENT '昵称',
    avatar_url VARCHAR(512) NULL COMMENT '头像地址',
    intro VARCHAR(500) NOT NULL DEFAULT '' COMMENT '个性简介',
    birthday DATE NULL COMMENT '生日',
    identity_type TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '身份：1日常自律,2考研,3考公,4技能学习,5备考学生',
    is_guest TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '游客标记：0否,1是；持久化用户预期为0',
    status TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '状态：0禁用,1正常,2锁定',
    pet_id BIGINT UNSIGNED NULL COMMENT '【二期预留】AI宠物ID，一期不读取',
    coin BIGINT NOT NULL DEFAULT 0 COMMENT '【二期预留】积分余额，非时间秒；一期固定为0',
    deleted TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '逻辑删除：0否,1是',
    create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_user_phone (phone),
    KEY idx_user_status_create (status, create_time),
    CONSTRAINT chk_user_identity CHECK (identity_type BETWEEN 1 AND 5),
    CONSTRAINT chk_user_guest CHECK (is_guest IN (0, 1)),
    CONSTRAINT chk_user_status CHECK (status IN (0, 1, 2)),
    CONSTRAINT chk_user_coin CHECK (coin >= 0),
    CONSTRAINT chk_user_deleted CHECK (deleted IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='用户主表';

CREATE TABLE t_user_setting (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '设置ID',
    user_id BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    remind_switch TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '提醒总开关：0关,1开',
    proctor_switch TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '在岗督学开关：0关,1开',
    rest_remind_switch TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '躺平或额度到期提醒开关：0关,1开',
    away_threshold_seconds BIGINT UNSIGNED NOT NULL DEFAULT 120 COMMENT '离席判定阈值，单位秒',
    deleted TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '逻辑删除：0否,1是',
    create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_user_setting_user (user_id),
    CONSTRAINT chk_user_setting_switch CHECK (
        remind_switch IN (0, 1)
        AND proctor_switch IN (0, 1)
        AND rest_remind_switch IN (0, 1)
    ),
    CONSTRAINT chk_user_setting_threshold CHECK (away_threshold_seconds > 0),
    CONSTRAINT chk_user_setting_deleted CHECK (deleted IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='用户设置';

CREATE TABLE t_task (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '任务ID',
    user_id BIGINT UNSIGNED NOT NULL COMMENT '所属用户ID',
    type TINYINT UNSIGNED NOT NULL COMMENT '任务类型：1当日短任务,2长期阶段任务',
    title VARCHAR(100) NOT NULL COMMENT '任务名称',
    content TEXT NULL COMMENT '任务内容',
    priority TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '优先级：0最低至5最高',
    est_seconds BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '预计专注时长，单位秒',
    due_time DATETIME(3) NULL COMMENT '截止时间；短任务可为当日结束，长任务必填由应用校验',
    status TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '状态：0待开始,1进行中,2已完成,3已取消',
    plan_id BIGINT UNSIGNED NULL COMMENT '最近一次AI规划ID；逻辑引用，不建立物理外键',
    deleted TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '逻辑删除：0否,1是',
    create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id),
    KEY idx_task_user_type_status_due (user_id, type, status, due_time),
    KEY idx_task_user_status_priority (user_id, status, priority),
    KEY idx_task_plan (plan_id),
    CONSTRAINT chk_task_type CHECK (type IN (1, 2)),
    CONSTRAINT chk_task_priority CHECK (priority BETWEEN 0 AND 5),
    CONSTRAINT chk_task_est CHECK (est_seconds >= 0),
    CONSTRAINT chk_task_status CHECK (status IN (0, 1, 2, 3)),
    CONSTRAINT chk_task_deleted CHECK (deleted IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='短任务与长期任务';

CREATE TABLE t_task_node (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '任务节点ID',
    task_id BIGINT UNSIGNED NOT NULL COMMENT '任务ID',
    seq TINYINT UNSIGNED NOT NULL COMMENT '节点顺序号：1至5',
    name VARCHAR(100) NOT NULL COMMENT '节点名称',
    description VARCHAR(500) NOT NULL DEFAULT '' COMMENT '节点说明',
    reward_seconds BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '节点奖励额度，单位秒；0表示不奖励',
    status TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '状态：0未完成,1已领取,2已取消',
    claimed_at DATETIME(3) NULL COMMENT '领取时间',
    deleted TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '逻辑删除：0否,1是',
    create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_task_node_seq (task_id, seq),
    KEY idx_task_node_task_status (task_id, status, seq),
    CONSTRAINT chk_task_node_seq CHECK (seq BETWEEN 1 AND 5),
    CONSTRAINT chk_task_node_reward CHECK (reward_seconds >= 0),
    CONSTRAINT chk_task_node_status CHECK (status IN (0, 1, 2)),
    CONSTRAINT chk_task_node_claim CHECK (
        (status = 1 AND claimed_at IS NOT NULL)
        OR (status <> 1)
    ),
    CONSTRAINT chk_task_node_deleted CHECK (deleted IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='任务奖励节点';

CREATE TABLE t_task_daily (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '每日子任务ID',
    user_id BIGINT UNSIGNED NOT NULL COMMENT '所属用户ID（冗余自任务，便于按日查询）',
    task_id BIGINT UNSIGNED NOT NULL COMMENT '长期任务ID',
    plan_date DATE NOT NULL COMMENT '计划日期，按服务端业务日期写入',
    seq SMALLINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '同一任务同日内的子任务顺序',
    content VARCHAR(1000) NOT NULL COMMENT '每日小任务内容',
    est_seconds BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '预计时长，单位秒',
    status TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '状态：0未开始,1进行中,2完成,3未完成',
    deleted TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '逻辑删除：0否,1是',
    create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_task_daily_plan_seq (task_id, plan_date, seq),
    KEY idx_task_daily_user_date_status (user_id, plan_date, status),
    CONSTRAINT chk_task_daily_seq CHECK (seq > 0),
    CONSTRAINT chk_task_daily_est CHECK (est_seconds >= 0),
    CONSTRAINT chk_task_daily_status CHECK (status IN (0, 1, 2, 3)),
    CONSTRAINT chk_task_daily_deleted CHECK (deleted IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='AI拆解后的每日子任务';

CREATE TABLE t_ai_plan (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'AI规划ID',
    user_id BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    task_id BIGINT UNSIGNED NULL COMMENT '关联任务ID；生成阶段可为空',
    prompt TEXT NULL COMMENT '任务拆解输入快照',
    result_json JSON NULL COMMENT '结构化规划结果',
    source_type TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '结果来源：1大模型,2规则模板降级',
    status TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '状态：0处理中,1成功,2降级成功,3失败',
    provider VARCHAR(50) NULL COMMENT '模型服务商标识',
    model_name VARCHAR(100) NULL COMMENT '模型标识',
    error_message VARCHAR(1000) NULL COMMENT '受控错误摘要，不保存敏感提示词或凭据',
    deleted TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '逻辑删除：0否,1是',
    create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id),
    KEY idx_ai_plan_user_time (user_id, create_time),
    KEY idx_ai_plan_task (task_id),
    CONSTRAINT chk_ai_plan_source CHECK (source_type IN (1, 2)),
    CONSTRAINT chk_ai_plan_status CHECK (status IN (0, 1, 2, 3)),
    CONSTRAINT chk_ai_plan_deleted CHECK (deleted IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='AI任务拆解记录';

CREATE TABLE t_focus_session (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '专注会话ID',
    user_id BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    task_id BIGINT UNSIGNED NULL COMMENT '关联任务ID，可为空',
    start_time DATETIME(3) NOT NULL COMMENT '服务端开始时间',
    end_time DATETIME(3) NULL COMMENT '服务端结束时间',
    last_heartbeat_time DATETIME(3) NULL COMMENT '最近一次服务端确认心跳时间',
    paused_seconds BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '累计暂停秒数',
    invalid_seconds BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '离席超时或异常判定无效秒数',
    effective_seconds BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '有效专注秒数',
    earned_seconds BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '实际到账额度秒数',
    status TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '状态：1专注中,2已暂停,3已结束,4异常结束',
    end_reason TINYINT UNSIGNED NULL COMMENT '结束原因：1用户停止,2心跳超时,3系统异常',
    settled TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '结算标记：0未结算,1已结算',
    settlement_status TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '结算状态：0未尝试,1成功,2失败',
    settlement_attempt_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '结算尝试次数',
    settlement_error VARCHAR(500) NULL COMMENT '最近一次结算失败摘要',
    next_settlement_retry_at DATETIME(3) NULL COMMENT '下次结算补偿时间',
    deleted TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '逻辑删除：0否,1是；会话表不执行删除',
    create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id),
    KEY idx_focus_session_user_status (user_id, status),
    KEY idx_focus_session_user_start (user_id, start_time),
    KEY idx_focus_session_task (task_id),
    KEY idx_focus_session_stale (status, last_heartbeat_time),
    KEY idx_focus_session_settlement_retry (settlement_status, next_settlement_retry_at, id),
    CONSTRAINT chk_focus_session_seconds CHECK (
        paused_seconds >= 0
        AND invalid_seconds >= 0
        AND effective_seconds >= 0
        AND earned_seconds >= 0
    ),
    CONSTRAINT chk_focus_session_status CHECK (status IN (1, 2, 3, 4)),
    CONSTRAINT chk_focus_session_end_reason CHECK (
        (status IN (1, 2) AND end_time IS NULL AND end_reason IS NULL)
        OR (
            status IN (3, 4)
            AND end_time IS NOT NULL
            AND end_reason IS NOT NULL
            AND end_reason IN (1, 2, 3)
        )
    ),
    CONSTRAINT chk_focus_session_settled CHECK (settled IN (0, 1)),
    CONSTRAINT chk_focus_session_settlement CHECK (
        settlement_status IN (0, 1, 2)
        AND (
            (settled = 1 AND settlement_status = 1)
            OR (settled = 0 AND settlement_status IN (0, 2))
        )
        AND (
            settlement_status = 0
            OR (status IN (3, 4) AND end_time IS NOT NULL)
        )
    ),
    CONSTRAINT chk_focus_session_time CHECK (end_time IS NULL OR end_time >= start_time),
    CONSTRAINT chk_focus_session_deleted CHECK (deleted IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='专注会话';

CREATE TABLE t_rest_session (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '躺平会话ID',
    user_id BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    start_time DATETIME(3) NOT NULL COMMENT '服务端开始时间',
    end_time DATETIME(3) NULL COMMENT '服务端结束时间',
    last_heartbeat_time DATETIME(3) NULL COMMENT '最近一次扣减心跳时间',
    consumed_seconds BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '本次累计消耗额度秒数',
    status TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '状态：1躺平中,2已结束',
    end_reason TINYINT UNSIGNED NULL COMMENT '结束原因：1用户停止,2余额耗尽,3系统异常',
    deleted TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '逻辑删除：0否,1是；会话表不执行删除',
    create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id),
    KEY idx_rest_session_user_status (user_id, status),
    KEY idx_rest_session_user_start (user_id, start_time),
    CONSTRAINT chk_rest_session_consumed CHECK (consumed_seconds >= 0),
    CONSTRAINT chk_rest_session_status CHECK (status IN (1, 2)),
    CONSTRAINT chk_rest_session_end_reason CHECK (
        (status = 1 AND end_time IS NULL AND end_reason IS NULL)
        OR (
            status = 2
            AND end_time IS NOT NULL
            AND end_reason IS NOT NULL
            AND end_reason IN (1, 2, 3)
        )
    ),
    CONSTRAINT chk_rest_session_time CHECK (end_time IS NULL OR end_time >= start_time),
    CONSTRAINT chk_rest_session_deleted CHECK (deleted IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='躺平会话';

CREATE TABLE t_quota_batch (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '额度批次ID',
    user_id BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    amount_seconds BIGINT UNSIGNED NOT NULL COMMENT '批次初始额度，单位秒',
    remain_seconds BIGINT UNSIGNED NOT NULL COMMENT '批次剩余额度，单位秒',
    source_type TINYINT UNSIGNED NOT NULL COMMENT '来源：1专注结算,2任务节点奖励',
    source_id BIGINT UNSIGNED NOT NULL COMMENT '来源业务ID；逻辑引用，无物理外键',
    grant_time DATETIME(3) NOT NULL COMMENT '发放时间',
    grant_date DATE NOT NULL COMMENT '发放业务日期，按服务端日期写入',
    expire_at DATETIME(3) NOT NULL COMMENT '固定到期时间：grant_time + 7天',
    status TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '状态：1有效,2已用尽,3已过期',
    deleted TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '逻辑删除：0否,1是；额度批次不删除',
    create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_quota_batch_source (user_id, source_type, source_id),
    KEY idx_quota_batch_balance (user_id, status, expire_at, remain_seconds),
    KEY idx_quota_batch_expire_scan (status, expire_at, user_id),
    CONSTRAINT chk_quota_batch_amount CHECK (amount_seconds > 0),
    CONSTRAINT chk_quota_batch_remain CHECK (remain_seconds <= amount_seconds),
    CONSTRAINT chk_quota_batch_status CHECK (status IN (1, 2, 3)),
    CONSTRAINT chk_quota_batch_expire CHECK (expire_at > grant_time),
    CONSTRAINT chk_quota_batch_used CHECK (status <> 2 OR remain_seconds = 0),
    CONSTRAINT chk_quota_batch_deleted CHECK (deleted IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='躺平额度批次';

CREATE TABLE t_quota_ledger (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '额度流水ID',
    user_id BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    batch_id BIGINT UNSIGNED NOT NULL COMMENT '额度批次ID',
    direction TINYINT UNSIGNED NOT NULL COMMENT '方向：1收入,2支出,3过期',
    amount_seconds BIGINT UNSIGNED NOT NULL COMMENT '变动秒数，始终为正数',
    biz_type VARCHAR(32) NOT NULL COMMENT '业务类型：FOCUS_SETTLE,NODE_REWARD,REST_CONSUME,QUOTA_EXPIRE',
    biz_id VARCHAR(64) NOT NULL COMMENT '业务幂等源ID',
    idempotency_key VARCHAR(128) NOT NULL COMMENT '完整幂等键；由业务确定性生成',
    deleted TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '逻辑删除：0否,1是；流水禁止删除或修改',
    create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_quota_ledger_idempotency (user_id, idempotency_key),
    KEY idx_quota_ledger_user_time (user_id, create_time, direction),
    KEY idx_quota_ledger_batch_time (batch_id, create_time, direction),
    KEY idx_quota_ledger_biz (biz_type, biz_id),
    CONSTRAINT chk_quota_ledger_direction CHECK (direction IN (1, 2, 3)),
    CONSTRAINT chk_quota_ledger_amount CHECK (amount_seconds > 0),
    CONSTRAINT chk_quota_ledger_deleted CHECK (deleted = 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='额度收支及过期流水';

CREATE TABLE t_quota_grant_counter (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '额度发放计数ID',
    user_id BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    period_type TINYINT UNSIGNED NOT NULL COMMENT '周期类型：1自然日,2自然周',
    period_start DATE NOT NULL COMMENT '周期起点；日为本日，周为周一',
    granted_seconds BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '周期内实际发放秒数',
    create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_quota_counter_period (user_id, period_type, period_start),
    CONSTRAINT chk_quota_counter_type CHECK (period_type IN (1, 2)),
    CONSTRAINT chk_quota_counter_limit CHECK (
        (period_type = 1 AND granted_seconds <= 10800)
        OR (period_type = 2 AND granted_seconds <= 86400)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='额度日周上限事务计数（支持核心规则2）';

CREATE TABLE t_daily_stat (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '日统计ID',
    user_id BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    stat_date DATE NOT NULL COMMENT '业务日期',
    focus_seconds BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '当日有效专注秒数',
    earned_seconds BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '当日获得额度秒数',
    consumed_seconds BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '当日消耗额度秒数',
    expired_seconds BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '当日过期额度秒数',
    post_unlocked TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '发帖资格：0未解锁,1已解锁',
    task_completed_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '当日完成任务数',
    task_total_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '当日任务总数',
    version INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '投影乐观锁版本',
    deleted TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '逻辑删除：0否,1是；日统计不删除',
    create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_daily_stat_user_date (user_id, stat_date),
    KEY idx_daily_stat_date (stat_date),
    CONSTRAINT chk_daily_stat_post CHECK (post_unlocked IN (0, 1)),
    CONSTRAINT chk_daily_stat_deleted CHECK (deleted IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='用户日统计投影';

CREATE TABLE t_proctor_event (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '在岗事件ID',
    user_id BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    session_id BIGINT UNSIGNED NOT NULL COMMENT '专注会话ID',
    event_type TINYINT UNSIGNED NOT NULL COMMENT '事件：1在岗,2离席',
    event_time DATETIME(3) NOT NULL COMMENT '事件发生时间（服务端校验后的时间）',
    source VARCHAR(32) NOT NULL DEFAULT 'MEDIAPIPE' COMMENT '端侧检测来源标识',
    payload_json JSON NULL COMMENT '非视频结构化附加信息；禁止上传视频或人脸影像',
    deleted TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '逻辑删除：0否,1是；事件表不删除',
    create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id),
    KEY idx_proctor_user_time (user_id, event_time),
    KEY idx_proctor_session_type_time (session_id, event_type, event_time),
    CONSTRAINT chk_proctor_event_type CHECK (event_type IN (1, 2)),
    CONSTRAINT chk_proctor_event_deleted CHECK (deleted = 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='在岗/离席事件';

CREATE TABLE t_post (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '帖子ID',
    user_id BIGINT UNSIGNED NOT NULL COMMENT '发布用户ID',
    content TEXT NULL COMMENT '文字内容',
    images JSON NULL COMMENT '图片地址数组',
    status TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '状态：0审核中,1已发布,2已隐藏',
    category VARCHAR(32) NULL COMMENT '【二期预留】考试分区或树洞分类，一期为NULL',
    anonymous TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '【二期预留】匿名标记，一期固定0',
    like_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '点赞数投影',
    comment_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '评论数投影',
    deleted TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '逻辑删除：0否,1是',
    create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id),
    KEY idx_post_feed (status, create_time, id),
    KEY idx_post_user_time (user_id, create_time),
    KEY idx_post_category_feed (category, status, create_time),
    CONSTRAINT chk_post_status CHECK (status IN (0, 1, 2)),
    CONSTRAINT chk_post_anonymous CHECK (anonymous IN (0, 1)),
    CONSTRAINT chk_post_deleted CHECK (deleted IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='轻量社区帖子';

CREATE TABLE t_comment (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '评论ID',
    post_id BIGINT UNSIGNED NOT NULL COMMENT '帖子ID',
    user_id BIGINT UNSIGNED NOT NULL COMMENT '评论用户ID',
    parent_id BIGINT UNSIGNED NULL COMMENT '父评论ID；一期可为空',
    content VARCHAR(1000) NOT NULL COMMENT '评论正文',
    status TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '状态：0审核中,1已发布,2已隐藏',
    like_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '点赞数投影',
    deleted TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '逻辑删除：0否,1是',
    create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id),
    KEY idx_comment_post_feed (post_id, status, create_time),
    KEY idx_comment_user_time (user_id, create_time),
    KEY idx_comment_parent (parent_id),
    CONSTRAINT chk_comment_status CHECK (status IN (0, 1, 2)),
    CONSTRAINT chk_comment_deleted CHECK (deleted IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='帖子评论';

CREATE TABLE t_like (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '点赞ID',
    post_id BIGINT UNSIGNED NOT NULL COMMENT '帖子ID',
    user_id BIGINT UNSIGNED NOT NULL COMMENT '点赞用户ID',
    deleted TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '逻辑删除：0有效,1取消点赞',
    create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_like_post_user (post_id, user_id),
    KEY idx_like_user_time (user_id, create_time),
    CONSTRAINT chk_like_deleted CHECK (deleted IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='帖子点赞';

CREATE TABLE t_sensitive_word (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '敏感词ID',
    word VARCHAR(100) NOT NULL COMMENT '敏感词',
    level TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '级别：1拦截,2审核,3提示',
    status TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '状态：0停用,1启用',
    deleted TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '逻辑删除：0否,1是',
    create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_sensitive_word (word),
    KEY idx_sensitive_status_level (status, level),
    CONSTRAINT chk_sensitive_level CHECK (level IN (1, 2, 3)),
    CONSTRAINT chk_sensitive_status CHECK (status IN (0, 1)),
    CONSTRAINT chk_sensitive_deleted CHECK (deleted IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='敏感词库';

CREATE TABLE t_reminder (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '提醒ID',
    user_id BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
    type TINYINT UNSIGNED NOT NULL COMMENT '提醒类型：1任务开始,2任务截止,3长时间未学习,4额度即将过期',
    biz_type VARCHAR(32) NOT NULL COMMENT '关联业务类型',
    biz_id VARCHAR(64) NOT NULL COMMENT '关联业务ID',
    plan_time DATETIME(3) NOT NULL COMMENT '计划发送时间',
    send_time DATETIME(3) NULL COMMENT '实际发送时间',
    status TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '状态：0待发送,1已发送,2失败,3取消',
    retry_count INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '扫描重试次数',
    dedupe_key VARCHAR(128) NOT NULL COMMENT '提醒唯一业务键',
    error_message VARCHAR(500) NULL COMMENT '失败摘要',
    deleted TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '逻辑删除：0否,1是',
    create_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '创建时间',
    update_time DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_reminder_dedupe (dedupe_key),
    KEY idx_reminder_due_scan (status, plan_time, id),
    KEY idx_reminder_user_time (user_id, create_time),
    KEY idx_reminder_biz (biz_type, biz_id),
    CONSTRAINT chk_reminder_type CHECK (type IN (1, 2, 3, 4)),
    CONSTRAINT chk_reminder_status CHECK (status IN (0, 1, 2, 3)),
    CONSTRAINT chk_reminder_sent CHECK (
        (status = 1 AND send_time IS NOT NULL)
        OR (status <> 1)
    ),
    CONSTRAINT chk_reminder_retry CHECK (retry_count >= 0),
    CONSTRAINT chk_reminder_deleted CHECK (deleted IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci ROW_FORMAT=DYNAMIC COMMENT='站内及推送提醒记录';
