package com.tpdiary.common.error;

import org.springframework.http.HttpStatus;

/**
 * TPDiary 稳定业务错误码。
 *
 * <p>业务模块号段：用户 10xxx、任务 20xxx、额度 30xxx、社区 40xxx。
 * 40xxx 同时承载通用请求错误；认证、权限、限流和系统错误使用协议级固定码。
 */
public enum ErrorCode {

    // 通用请求、认证、权限和系统错误
    INVALID_ARGUMENT(40001, "请求参数不正确", HttpStatus.BAD_REQUEST),
    INVALID_TIME_FORMAT(40002, "时间格式不正确", HttpStatus.BAD_REQUEST),
    UNSUPPORTED_FILE_TYPE(40003, "不支持的文件类型", HttpStatus.BAD_REQUEST),
    FILE_TOO_LARGE(40004, "文件大小超出限制", HttpStatus.PAYLOAD_TOO_LARGE),
    UNAUTHENTICATED(40100, "请先登录", HttpStatus.UNAUTHORIZED),
    TOKEN_INVALID_OR_EXPIRED(40101, "登录状态已失效，请重新登录", HttpStatus.UNAUTHORIZED),
    TOKEN_REVOKED(40103, "登录状态已撤销", HttpStatus.UNAUTHORIZED),
    VERIFICATION_CODE_INVALID(40104, "验证码错误或已过期", HttpStatus.UNAUTHORIZED),
    INVALID_CREDENTIALS(40105, "账号或密码错误", HttpStatus.UNAUTHORIZED),
    PROCTOR_SIGNATURE_INVALID(40106, "督学事件签名无效", HttpStatus.UNAUTHORIZED),
    GUEST_FEATURE_FORBIDDEN(40300, "游客不可使用该功能", HttpStatus.FORBIDDEN),
    RESOURCE_OWNERSHIP_DENIED(40303, "无权操作该资源", HttpStatus.FORBIDDEN),
    RESOURCE_NOT_FOUND(40401, "资源不存在", HttpStatus.NOT_FOUND),
    RATE_LIMITED(42901, "操作过于频繁，请稍后再试", HttpStatus.TOO_MANY_REQUESTS),
    INTERNAL_ERROR(50000, "系统繁忙，请稍后重试", HttpStatus.INTERNAL_SERVER_ERROR),
    AI_SERVICE_UNAVAILABLE(50001, "AI 服务暂不可用", HttpStatus.INTERNAL_SERVER_ERROR),
    STORAGE_UNAVAILABLE(50002, "文件存储暂不可用", HttpStatus.INTERNAL_SERVER_ERROR),

    // 用户模块：10xxx
    USER_NOT_FOUND(10001, "用户不存在", HttpStatus.NOT_FOUND),
    USER_PHONE_ALREADY_REGISTERED(10002, "手机号已经注册", HttpStatus.CONFLICT),
    USER_DISABLED(10003, "账号已被禁用", HttpStatus.FORBIDDEN),

    // 任务模块：20xxx
    TASK_NOT_FOUND(20001, "任务不存在", HttpStatus.NOT_FOUND),
    TASK_STATE_CONFLICT(20002, "任务当前状态不允许该操作", HttpStatus.CONFLICT),
    TASK_NODE_NOT_COMPLETABLE(20003, "任务节点当前不可领取", HttpStatus.CONFLICT),
    TASK_NODE_LIMIT_EXCEEDED(20004, "单个任务最多配置 5 个奖励节点", HttpStatus.BAD_REQUEST),

    // 额度模块：30xxx
    QUOTA_INSUFFICIENT(30001, "可用躺平额度不足", HttpStatus.CONFLICT),
    QUOTA_SOURCE_NOT_ALLOWED(30002, "额度只能由有效专注或节点奖励获得", HttpStatus.CONFLICT),
    QUOTA_LEDGER_INCONSISTENT(30003, "额度账本不一致，请联系管理员", HttpStatus.INTERNAL_SERVER_ERROR),
    QUOTA_BATCH_TERMINAL(30004, "额度批次已经用尽或过期", HttpStatus.CONFLICT),

    // 社区模块：40xxx
    COMMUNITY_POST_NOT_FOUND(40010, "帖子不存在", HttpStatus.NOT_FOUND),
    COMMUNITY_COMMENT_NOT_FOUND(40011, "评论不存在", HttpStatus.NOT_FOUND),
    COMMUNITY_CONTENT_REJECTED(40012, "内容未通过基础敏感词校验", HttpStatus.BAD_REQUEST),
    POST_NOT_UNLOCKED(40301, "今日有效专注满 30 分钟才可发帖", HttpStatus.FORBIDDEN);

    private final int code;
    private final String message;
    private final HttpStatus httpStatus;

    ErrorCode(int code, String message, HttpStatus httpStatus) {
        this.code = code;
        this.message = message;
        this.httpStatus = httpStatus;
    }

    public int getCode() {
        return code;
    }

    public String getMessage() {
        return message;
    }

    public HttpStatus getHttpStatus() {
        return httpStatus;
    }
}
