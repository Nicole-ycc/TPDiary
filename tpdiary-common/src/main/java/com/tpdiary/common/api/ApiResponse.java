package com.tpdiary.common.api;

/**
 * 兼容 P08 骨架期间使用的响应工厂，实际返回 {@link Result}。
 *
 * @deprecated 新代码统一使用 {@link Result}。
 */
@Deprecated(forRemoval = true)
public final class ApiResponse<T> {

    private ApiResponse() {
    }

    public static <T> Result<T> success(T data, String traceId) {
        return new Result<>(0, "ok", data, traceId);
    }

    public static <T> Result<T> failure(int code, String message, String traceId) {
        return new Result<>(code, message, null, traceId);
    }
}
