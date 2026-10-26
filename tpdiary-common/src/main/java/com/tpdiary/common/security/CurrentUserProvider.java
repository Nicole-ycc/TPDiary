package com.tpdiary.common.security;

import java.util.Optional;

/**
 * 当前用户 ID 提供者。
 *
 * <p>M0 阶段没有完整认证实现时不需要提供该 Bean；接入用户模块后，可提供一个实现并把
 * 当前登录用户的内部 ID 返回给日志上下文，示例：
 * <pre>{@code
 * @Bean
 * CurrentUserProvider currentUserProvider(CurrentUser currentUser) {
 *     return () -> currentUser.id();
 * }
 * }</pre>
 */
@FunctionalInterface
public interface CurrentUserProvider {

    Optional<String> currentUserId();
}
