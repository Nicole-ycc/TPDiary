package com.tpdiary.common.web;

import com.tpdiary.common.api.Result;
import com.tpdiary.common.error.BizException;
import com.tpdiary.common.error.ErrorCode;
import com.tpdiary.common.logging.TraceContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import static org.assertj.core.api.Assertions.assertThat;

class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @BeforeEach
    void setUp() {
        TraceContext.bind("trace-handler-001", "2001");
    }

    @AfterEach
    void tearDown() {
        TraceContext.clear();
    }

    @Test
    void businessExceptionKeepsSafeErrorCodeAndMessage() {
        ResponseEntity<Result<Void>> response =
                handler.handleBizException(new BizException(ErrorCode.QUOTA_INSUFFICIENT));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().code()).isEqualTo(30001);
        assertThat(response.getBody().traceId()).isEqualTo("trace-handler-001");
    }

    @Test
    void unknownExceptionDoesNotExposeInternalMessageOrStackTrace() {
        ResponseEntity<Result<Void>> response =
                handler.handleUnknown(new IllegalStateException("database password=secret"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().code()).isEqualTo(50000);
        assertThat(response.getBody().message()).isEqualTo("系统繁忙，请稍后重试");
        assertThat(response.getBody().message()).doesNotContain("database", "secret", "IllegalStateException");
        assertThat(response.getBody().data()).isNull();
    }
}
