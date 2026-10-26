package com.tpdiary.common.validation.example;

import com.tpdiary.common.validation.PositiveSeconds;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * 任务创建时的 JSR-303 业务使用示例。
 *
 * <p>Controller 参数增加 {@code @Valid} 后，非法时长会由全局异常处理器转换为
 * HTTP 400 和统一错误码 {@code 40001}。
 *
 * @param taskTitle        任务标题
 * @param estimatedSeconds 预计专注秒数
 */
public record PositiveSecondsExampleRequest(
        @NotBlank(message = "任务标题不能为空")
        String taskTitle,

        @NotNull(message = "预计专注时长不能为空")
        @PositiveSeconds
        Long estimatedSeconds
) {
}
