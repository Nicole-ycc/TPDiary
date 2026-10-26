package com.tpdiary.common.logging;

import com.tpdiary.common.security.CurrentUserProvider;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * 为每个 HTTP 请求注入 traceId 和 userId。
 *
 * <p>完整用户模块接入后，只需提供 {@link CurrentUserProvider} Bean；在尚未接入认证的
 * M0 阶段，userId 使用 {@code anonymous}。客户端提交的用户 ID Header 不会被信任。
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class MdcTraceFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(MdcTraceFilter.class);

    private final ObjectProvider<CurrentUserProvider> currentUserProvider;

    public MdcTraceFilter(ObjectProvider<CurrentUserProvider> currentUserProvider) {
        this.currentUserProvider = currentUserProvider;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        String traceId = TraceContext.resolveTraceId(request.getHeader(TraceContext.TRACE_ID_HEADER));
        String userId = resolveUserId();

        TraceContext.bind(traceId, userId);
        request.setAttribute(TraceContext.TRACE_ID_REQUEST_ATTRIBUTE, traceId);
        response.setHeader(TraceContext.TRACE_ID_HEADER, traceId);
        try {
            filterChain.doFilter(request, response);
        } finally {
            TraceContext.clear();
        }
    }

    private String resolveUserId() {
        CurrentUserProvider provider = currentUserProvider.getIfAvailable();
        if (provider == null) {
            return TraceContext.ANONYMOUS_USER;
        }
        try {
            return provider.currentUserId()
                    .filter(id -> !id.isBlank())
                    .orElse(TraceContext.ANONYMOUS_USER);
        } catch (RuntimeException exception) {
            // 日志上下文不能阻断业务请求。
            log.warn("Unable to resolve current user id for MDC", exception);
            return TraceContext.ANONYMOUS_USER;
        }
    }
}
