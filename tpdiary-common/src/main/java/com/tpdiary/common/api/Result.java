package com.tpdiary.common.api;

import com.tpdiary.common.error.ErrorCode;
import com.tpdiary.common.logging.TraceContext;

import java.util.Objects;

/**
 * TPDiary 统一响应体。
 *
 * <p>成功示例：
 * <pre>{@code
 * return Result.success(taskId);
 * }</pre>
 *
 * <p>失败示例：
 * <pre>{@code
 * return Result.failure(ErrorCode.QUOTA_INSUFFICIENT);
 * }</pre>
 *
 * @param code    业务码，0 表示成功
 * @param message 可展示的说明
 * @param data    业务数据
 * @param traceId 请求链路 ID
 * @param <T>     业务数据类型
 */
public record Result<T>(int code, String message, T data, String traceId) {

    private static final String SUCCESS_MESSAGE = "ok";

    public Result {
        message = Objects.requireNonNullElse(message, "");
        traceId = traceId == null || traceId.isBlank() ? TraceContext.currentTraceId() : traceId;
    }

    public static <T> Result<T> success(T data) {
        return new Result<>(0, SUCCESS_MESSAGE, data, TraceContext.currentTraceId());
    }

    public static <T> Result<T> success(String message, T data) {
        return new Result<>(0, message, data, TraceContext.currentTraceId());
    }

    public static <T> Result<T> failure(ErrorCode errorCode) {
        Objects.requireNonNull(errorCode, "errorCode must not be null");
        return failure(errorCode.getCode(), errorCode.getMessage());
    }

    public static <T> Result<T> failure(ErrorCode errorCode, String message) {
        Objects.requireNonNull(errorCode, "errorCode must not be null");
        String safeMessage = message == null || message.isBlank() ? errorCode.getMessage() : message;
        return failure(errorCode.getCode(), safeMessage);
    }

    public static <T> Result<T> failure(int code, String message) {
        return new Result<>(code, message, null, TraceContext.currentTraceId());
    }

}
