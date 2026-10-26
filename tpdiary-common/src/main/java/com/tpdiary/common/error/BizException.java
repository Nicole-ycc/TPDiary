package com.tpdiary.common.error;

import java.util.Objects;

/**
 * 可预期的业务异常。
 *
 * <p>业务代码示例：
 * <pre>{@code
 * if (availableSeconds <= 0) {
 *     throw new BizException(ErrorCode.QUOTA_INSUFFICIENT);
 * }
 * }</pre>
 *
 * <p>该异常由 {@code GlobalExceptionHandler} 转换为统一的 HTTP 响应。
 */
public class BizException extends RuntimeException {

    private final ErrorCode errorCode;

    public BizException(ErrorCode errorCode) {
        super(Objects.requireNonNull(errorCode, "errorCode must not be null").getMessage());
        this.errorCode = errorCode;
    }

    public BizException(ErrorCode errorCode, String message) {
        super(resolveMessage(errorCode, message));
        this.errorCode = errorCode;
    }

    public BizException(ErrorCode errorCode, Throwable cause) {
        super(Objects.requireNonNull(errorCode, "errorCode must not be null").getMessage(), cause);
        this.errorCode = errorCode;
    }

    public ErrorCode getErrorCode() {
        return errorCode;
    }

    private static String resolveMessage(ErrorCode errorCode, String message) {
        ErrorCode requiredCode = Objects.requireNonNull(errorCode, "errorCode must not be null");
        return message == null || message.isBlank() ? requiredCode.getMessage() : message;
    }
}
