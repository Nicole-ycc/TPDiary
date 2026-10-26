package com.tpdiary.common.api;

import com.tpdiary.common.error.ErrorCode;
import com.tpdiary.common.logging.TraceContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class ResultTest {

    @BeforeEach
    void setUp() {
        TraceContext.bind("trace-result-001", "1001");
    }

    @AfterEach
    void tearDown() {
        TraceContext.clear();
    }

    @Test
    void successContainsBusinessDataAndTraceId() {
        Result<String> result = Result.success("task-1");

        assertThat(result.code()).isZero();
        assertThat(result.message()).isEqualTo("ok");
        assertThat(result.data()).isEqualTo("task-1");
        assertThat(result.traceId()).isEqualTo("trace-result-001");
    }

    @Test
    void failureUsesStableErrorCode() {
        Result<Void> result = Result.failure(ErrorCode.QUOTA_INSUFFICIENT);

        assertThat(result.code()).isEqualTo(30001);
        assertThat(result.message()).isEqualTo("可用躺平额度不足");
        assertThat(result.data()).isNull();
    }
}
