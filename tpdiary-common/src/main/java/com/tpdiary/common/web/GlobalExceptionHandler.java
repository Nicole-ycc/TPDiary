package com.tpdiary.common.web;

import com.tpdiary.common.api.Result;
import com.tpdiary.common.error.BizException;
import com.tpdiary.common.error.ErrorCode;
import com.tpdiary.common.logging.TraceContext;
import jakarta.validation.ConstraintViolationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.MessageSourceResolvable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.validation.BindException;
import org.springframework.validation.BindingResult;
import org.springframework.validation.FieldError;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * 全局异常转换入口。
 *
 * <p>Controller 只需抛业务异常或使用 JSR-303 校验，不在各接口重复拼接错误响应。
 * 未知异常只在服务端记录完整堆栈，前端始终收到固定安全文案。
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);
    private static final int MAX_VALIDATION_DETAILS = 3;

    @ExceptionHandler(BizException.class)
    public ResponseEntity<Result<Void>> handleBizException(BizException exception) {
        return response(exception.getErrorCode(), exception.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Result<Void>> handleMethodArgumentNotValid(
            MethodArgumentNotValidException exception
    ) {
        return validationResponse(exception.getBindingResult());
    }

    @ExceptionHandler(BindException.class)
    public ResponseEntity<Result<Void>> handleBindException(BindException exception) {
        return validationResponse(exception.getBindingResult());
    }

    @ExceptionHandler(HandlerMethodValidationException.class)
    public ResponseEntity<Result<Void>> handleMethodValidation(
            HandlerMethodValidationException exception
    ) {
        List<String> details = exception.getAllValidationResults().stream()
                .flatMap(result -> {
                    String parameterName = Optional.ofNullable(result.getMethodParameter().getParameterName())
                            .orElse("parameter");
                    return result.getResolvableErrors().stream()
                            .map(error -> parameterName + ": " + safeValidationMessage(error));
                })
                .limit(MAX_VALIDATION_DETAILS)
                .toList();
        log.debug("Request method validation failed: {}", details);
        return response(ErrorCode.INVALID_ARGUMENT, validationMessage(details));
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<Result<Void>> handleConstraintViolation(
            ConstraintViolationException exception
    ) {
        List<String> details = exception.getConstraintViolations().stream()
                .map(violation -> violation.getPropertyPath() + ": " + violation.getMessage())
                .limit(MAX_VALIDATION_DETAILS)
                .toList();
        log.debug("Request constraint validation failed: {}", details);
        return response(ErrorCode.INVALID_ARGUMENT, validationMessage(details));
    }

    @ExceptionHandler(MissingServletRequestParameterException.class)
    public ResponseEntity<Result<Void>> handleMissingParameter(
            MissingServletRequestParameterException exception
    ) {
        log.debug("Missing request parameter: {}", exception.getParameterName());
        return response(ErrorCode.INVALID_ARGUMENT, "缺少请求参数: " + exception.getParameterName());
    }

    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<Result<Void>> handleTypeMismatch(
            MethodArgumentTypeMismatchException exception
    ) {
        log.debug("Request parameter type mismatch: {}", exception.getName());
        return response(ErrorCode.INVALID_ARGUMENT, "请求参数格式不正确: " + exception.getName());
    }

    @ExceptionHandler({HttpMessageNotReadableException.class, HttpMediaTypeNotSupportedException.class})
    public ResponseEntity<Result<Void>> handleUnreadableRequest(Exception exception) {
        log.debug("Unreadable request body or unsupported media type", exception);
        return response(ErrorCode.INVALID_ARGUMENT, "请求内容格式不正确");
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Result<Void>> handleIllegalArgument(IllegalArgumentException exception) {
        log.debug("Illegal argument rejected", exception);
        return response(ErrorCode.INVALID_ARGUMENT);
    }

    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<Result<Void>> handleNoResource(NoResourceFoundException exception) {
        log.debug("Requested resource was not found: {}", exception.getResourcePath());
        return response(ErrorCode.RESOURCE_NOT_FOUND);
    }

    @ExceptionHandler(AuthenticationException.class)
    public ResponseEntity<Result<Void>> handleAuthentication(AuthenticationException exception) {
        log.warn("Authentication failed: {}", exception.getClass().getSimpleName());
        return response(ErrorCode.UNAUTHENTICATED);
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<Result<Void>> handleAccessDenied(AccessDeniedException exception) {
        log.warn("Access denied: {}", exception.getClass().getSimpleName());
        return response(ErrorCode.RESOURCE_OWNERSHIP_DENIED);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Result<Void>> handleUnknown(Exception exception) {
        String traceId = TraceContext.currentTraceId();
        String userId = TraceContext.currentUserId();
        log.error("Unhandled exception traceId={} userId={}", traceId, userId, exception);
        return response(ErrorCode.INTERNAL_ERROR, ErrorCode.INTERNAL_ERROR.getMessage());
    }

    private ResponseEntity<Result<Void>> validationResponse(BindingResult bindingResult) {
        List<String> details = bindingResult.getFieldErrors().stream()
                .limit(MAX_VALIDATION_DETAILS)
                .map(this::formatFieldError)
                .toList();
        List<String> allDetails = details.isEmpty()
                ? bindingResult.getGlobalErrors().stream()
                        .limit(MAX_VALIDATION_DETAILS)
                        .map(error -> safeText(error.getDefaultMessage()))
                        .toList()
                : details;
        log.debug("Request binding validation failed: {}", allDetails);
        return response(ErrorCode.INVALID_ARGUMENT, validationMessage(allDetails));
    }

    private String formatFieldError(FieldError error) {
        return error.getField() + ": " + safeText(error.getDefaultMessage());
    }

    private String safeValidationMessage(MessageSourceResolvable error) {
        return safeText(error.getDefaultMessage());
    }

    private String safeText(String text) {
        return text == null || text.isBlank() ? "参数不符合要求" : text;
    }

    private String validationMessage(List<String> details) {
        if (details.isEmpty()) {
            return ErrorCode.INVALID_ARGUMENT.getMessage();
        }
        return details.stream().filter(Objects::nonNull).collect(Collectors.joining("; "));
    }

    private ResponseEntity<Result<Void>> response(ErrorCode errorCode) {
        return response(errorCode, errorCode.getMessage());
    }

    private ResponseEntity<Result<Void>> response(ErrorCode errorCode, String message) {
        HttpStatus status = errorCode.getHttpStatus();
        Result<Void> body = Result.failure(errorCode, message);
        return ResponseEntity.status(status).body(body);
    }
}
