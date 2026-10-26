package com.tpdiary.common.validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 校验字段是否为大于 0 的整数秒数。
 *
 * <p>可为空的场景应与 {@link jakarta.validation.constraints.NotNull} 组合使用。
 */
@Documented
@Constraint(validatedBy = PositiveSecondsValidator.class)
@Target({
        ElementType.FIELD,
        ElementType.PARAMETER,
        ElementType.ANNOTATION_TYPE,
        ElementType.RECORD_COMPONENT
})
@Retention(RetentionPolicy.RUNTIME)
public @interface PositiveSeconds {

    String message() default "时长必须是正整数秒数";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
