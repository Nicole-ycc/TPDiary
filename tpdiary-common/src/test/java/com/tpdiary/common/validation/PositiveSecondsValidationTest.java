package com.tpdiary.common.validation;

import com.tpdiary.common.validation.example.PositiveSecondsExampleRequest;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import org.junit.jupiter.api.Test;

import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

class PositiveSecondsValidationTest {

    private final Validator validator = Validation.buildDefaultValidatorFactory().getValidator();

    @Test
    void acceptsPositiveWholeSeconds() {
        Set<ConstraintViolation<PositiveSecondsExampleRequest>> violations =
                validator.validate(new PositiveSecondsExampleRequest("阅读", 60L));

        assertThat(violations).isEmpty();
    }

    @Test
    void rejectsZeroNegativeAndFractionalSeconds() {
        assertThat(validator.validate(new PositiveSecondsExampleRequest("阅读", 0L))).hasSize(1);
        assertThat(validator.validate(new PositiveSecondsExampleRequest("阅读", -1L))).hasSize(1);
        assertThat(new PositiveSecondsValidator().isValid(1.5, null)).isFalse();
    }

    @Test
    void nullIsLeftToNotNullConstraint() {
        assertThat(new PositiveSecondsValidator().isValid(null, null)).isTrue();
        assertThat(validator.validate(new PositiveSecondsExampleRequest("阅读", null))).hasSize(1);
    }
}
