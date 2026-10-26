package com.tpdiary.common.logging;

import org.slf4j.MDC;

import java.util.UUID;
import java.util.regex.Pattern;

/**
 * 请求日志上下文。
 *
 * <p>MDC 只保存 traceId 和 userId，不保存 Token、手机号、密码或请求正文。
 */
public final class TraceContext {

    public static final String TRACE_ID_KEY = "traceId";
    public static final String USER_ID_KEY = "userId";
    public static final String TRACE_ID_HEADER = "X-Trace-Id";
    public static final String TRACE_ID_REQUEST_ATTRIBUTE = TraceContext.class.getName() + ".traceId";
    public static final String ANONYMOUS_USER = "anonymous";

    private static final Pattern VALID_TRACE_ID = Pattern.compile("^[A-Za-z0-9._-]{8,64}$");

    private TraceContext() {
    }

    public static String resolveTraceId(String candidate) {
        if (candidate != null && VALID_TRACE_ID.matcher(candidate).matches()) {
            return candidate;
        }
        return newTraceId();
    }

    public static String newTraceId() {
        return UUID.randomUUID().toString().replace("-", "");
    }

    public static String currentTraceId() {
        String traceId = MDC.get(TRACE_ID_KEY);
        return traceId == null || traceId.isBlank() ? newTraceId() : traceId;
    }

    public static String currentUserId() {
        String userId = MDC.get(USER_ID_KEY);
        return userId == null || userId.isBlank() ? ANONYMOUS_USER : userId;
    }

    public static void bind(String traceId, String userId) {
        MDC.put(TRACE_ID_KEY, resolveTraceId(traceId));
        MDC.put(USER_ID_KEY, userId == null || userId.isBlank() ? ANONYMOUS_USER : userId);
    }

    public static void clear() {
        MDC.remove(TRACE_ID_KEY);
        MDC.remove(USER_ID_KEY);
    }
}
