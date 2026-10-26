package com.tpdiary.common.validation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;

import java.math.BigDecimal;

/**
 * 正整数秒校验器。null 交由 {@code @NotNull} 处理。
 */
public final class PositiveSecondsValidator implements ConstraintValidator<PositiveSeconds, Number> {

    @Override
    public boolean isValid(Number value, ConstraintValidatorContext context) {
        if (value == null) {
            return true;
        }
        try {
            BigDecimal decimal = new BigDecimal(value.toString());
            return decimal.signum() > 0 && decimal.stripTrailingZeros().scale() <= 0;
        } catch (NumberFormatException exception) {
            return false;
        }
    }
}
