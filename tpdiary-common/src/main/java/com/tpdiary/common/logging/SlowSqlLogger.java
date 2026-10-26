package com.tpdiary.common.logging;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;

/**
 * 慢 SQL 结构化日志入口。
 *
 * <p>后续 MyBatis 性能拦截器只应传入 Mapper 标识和执行耗时；SQL 参数必须保持占位符，
 * 不得把密码、手机号或 Token 写入日志。调用示例：
 * <pre>{@code
 * SlowSqlLogger.logIfSlow("TaskMapper.selectByUser", sqlTemplate, elapsedMillis, 1000);
 * }</pre>
 */
public final class SlowSqlLogger {

    public static final String LOGGER_NAME = "TPDIARY_SLOW_SQL";
    public static final long DEFAULT_THRESHOLD_MILLIS = 1000L;

    private static final Logger log = LoggerFactory.getLogger(LOGGER_NAME);

    private SlowSqlLogger() {
    }

    public static void logIfSlow(String mapperId, String sqlTemplate, long elapsedMillis) {
        logIfSlow(mapperId, sqlTemplate, elapsedMillis, DEFAULT_THRESHOLD_MILLIS);
    }

    public static void logIfSlow(
            String mapperId,
            String sqlTemplate,
            long elapsedMillis,
            long thresholdMillis
    ) {
        if (!log.isWarnEnabled() || elapsedMillis < Math.max(0L, thresholdMillis)) {
            return;
        }

        String previousEvent = MDC.get("event");
        String previousElapsed = MDC.get("elapsedMs");
        String previousMapper = MDC.get("mapperId");
        try {
            MDC.put("event", "slow_sql");
            MDC.put("elapsedMs", Long.toString(elapsedMillis));
            MDC.put("mapperId", mapperId == null ? "unknown" : mapperId);
            log.warn("slow_sql mapper={} elapsedMs={} sql={}",
                    mapperId == null ? "unknown" : mapperId,
                    elapsedMillis,
                    sqlTemplate == null ? "" : sqlTemplate);
        } finally {
            restoreMdc("event", previousEvent);
            restoreMdc("elapsedMs", previousElapsed);
            restoreMdc("mapperId", previousMapper);
        }
    }

    private static void restoreMdc(String key, String value) {
        if (value == null) {
            MDC.remove(key);
        } else {
            MDC.put(key, value);
        }
    }
}
