package com.tpdiary.common.api;

/**
 * 统一 API 响应结构。
 *
 * @param code    业务码，0 表示成功
 * @param message 可展示的消息
 * @param data    业务数据
 * @param traceId 链路追踪 ID
 * @param <T>     业务数据类型
 */
public record ApiResponse<T>(int code, String message, T data, String traceId) {

    public static <T> ApiResponse<T> success(T data, String traceId) {
        return new ApiResponse<>(0, "ok", data, traceId);
    }

    public static <T> ApiResponse<T> failure(int code, String message, String traceId) {
        return new ApiResponse<>(code, message, null, traceId);
    }
}
