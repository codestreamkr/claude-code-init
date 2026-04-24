---
name: ct:spring-security
description: Spring Security 구성 패턴 전문 지식. SecurityFilterChain·JWT·OAuth2(Login/Resource Server)·CORS·CSRF·메서드 보안·보안 헤더·Refresh 로테이션·로그아웃·테스트·감사 이벤트까지 다룬다. 환경(Java·Boot·빌드 도구) 감지 후 버전에 맞게 적용한다.
---

# Spring Security 구성 패턴

---

## 환경 감지 — 코드 작성 전 필수 확인

| 확인 항목 | 위치 |
|---|---|
| 빌드 도구 | `pom.xml` 존재 → Maven / `build.gradle` 존재 → Gradle |
| Spring Boot 버전 | Maven: `<parent>`의 `<version>` / Gradle: `id 'org.springframework.boot' version '...'` 또는 `libs.versions.toml` |
| Java 버전 | Maven: `<java.version>` / Gradle: `sourceCompatibility` 또는 `toolchain` |
| 인증 방식 | 기존 코드에 `JwtAuthenticationFilter` · `oauth2Login` · `oauth2ResourceServer` · `formLogin` 중 무엇이 쓰였는지 |
| 토큰 저장소 | Redis 의존성 · `RefreshToken` 엔티티 존재 여부 |

버전이 다르면 컴파일 자체가 안 된다. 인증 방식과 토큰 저장소는 기존 구조를 따라가는 기준점이다.

### 의존성 아티팩트

| 용도 | artifactId |
|---|---|
| Security 기본 | `spring-boot-starter-security` |
| Security 테스트 | `spring-security-test` (test scope) |
| JWT (jjwt) | `jjwt-api` + `jjwt-impl`, `jjwt-jackson` (runtime) |
| OAuth2 Login (사용자 인증) | `spring-boot-starter-oauth2-client` |
| OAuth2 Resource Server (API 보호) | `spring-boot-starter-oauth2-resource-server` |
| Rate Limiting (선택) | `com.bucket4j:bucket4j-core` |

jjwt 0.11.x와 0.12.x는 API가 다르다. 프로젝트 기존 버전부터 확인.

### 적용 절차 — 이 스킬의 코드를 읽는 방법

**이 스킬의 모든 코드 블록은 최신 기준선(Spring Security 6 / jjwt 0.12.x) 문법이다.** 감지된 환경이 다르면 그대로 복붙하면 컴파일 안 된다.

1. **환경 감지**에서 Boot/Security/jjwt 버전을 먼저 확인
2. 기준선(Security 6, jjwt 0.12.x)과 다른 점이 있으면 하단 **버전 적용 규칙**의 변환표를 거쳐 출력
3. 감지된 버전을 사용자에게 먼저 공유 — "자네 프로젝트는 Boot 2.7 / Security 5네. 아래 코드는 `requestMatchers` → `antMatchers`로 바꿔 적용했네"
4. 변환이 불확실한 경우엔 기준선 코드를 그대로 제시하지 말고, 판단을 에이전트에 넘긴다

이 절차를 건너뛰고 기준선 코드를 그대로 출력하면 버전 오류의 원인이 된다.

---

## 이 스킬의 범위

이 스킬은 **Spring Security 분야의 구현 문법·구성 패턴**만 담당한다. 보안 아키텍처 판단과 정책 결정은 spring 에이전트가 맡는다.

**다루는 것 (Security 구현 문법·구성 패턴)**
- SecurityFilterChain 구성 문법 — HTTP DSL, 필터 등록, 체인 분리
- 인증 구현 — 폼/세션 설정, JWT Provider·Filter 작성, OAuth2 Login/Resource Server 구성
- 인가 구현 — `hasRole`·`hasAuthority` 사용, 메서드 보안 어노테이션, `@AuthenticationPrincipal`
- 토큰 구현 패턴 — Refresh 로테이션 구조, 로그아웃 블랙리스트 구현
- 부속 구성 — CORS·CSRF 설정, 보안 헤더, 비밀번호 인코딩(`DelegatingPasswordEncoder`), 세션 설정
- 부가 기능 — 감사 이벤트 리스너, Rate Limiting 구현, 서비스 간 토큰 전파, `spring-security-test`

**다루지 않는 것 (spring 에이전트 영역)**
- 인증 방식 선택 판단 — JWT vs 세션 vs OAuth2 Login vs Resource Server
- 보안 경계 설계 — 어디서 인증 종료하고 어디로 전파할지 (예: Gateway vs 각 서비스)
- 다중 SecurityFilterChain 분리 여부 판단 (경로·사용자 그룹별 정책 결정)
- 권한 모델 설계 — 어떤 Role·Authority를 둘지, 도메인 권한을 어떻게 구조화할지
- Access/Refresh 만료 정책 결정 (서비스 특성에 따른 트레이드오프)
- 블랙리스트 vs 짧은 만료 전략 선택 (운영 비용 vs 즉시성 판단)
- Authorization Server 구축 (`spring-authorization-server` 별도 프로젝트)
- LDAP/SAML 연동, 멀티테넌시 보안 아키텍처
- 비밀번호 정책 검증(Passay 등 별도 라이브러리)

판단·설계 질문이 들어오면 에이전트가 먼저 정리한 뒤, 구현 단계에서 이 스킬을 쓴다.

**표준 우선 원칙**: 에이전트의 표준 우선 원칙을 따른다 — 별도 요구 없으면 Spring Security 공식 권장 방식을 선택.

---

## 진단 플로우

1. **Boot 버전부터** — Boot 3.x = Security 6.x. `WebSecurityConfigurerAdapter` 없음
2. **403 vs 401** — 401: 인증 안 됨 / 403: 인증됐지만 권한 없음
3. **필터 체인 추적** — `logging.level.org.springframework.security=TRACE`로 어느 필터에서 막히는지 확인
4. **CORS** — OPTIONS preflight가 401/403이면 `permitAll()` 누락 또는 MVC ↔ Security 설정 충돌
5. **JWT 검증 실패** — 서명 키 불일치 → 만료 → 클레임 오류 순
6. **메서드 보안 미동작** — `@EnableMethodSecurity` 누락, self-invocation (같은 클래스 내부 호출)
7. **Refresh 무한 순환** — 로테이션 미적용 상태에서 동일 Refresh 재사용하면 항상 새 Access 발급됨. 탈취 감지 불가

---

## 수치 감각

- **Access Token 만료** — 15분~1시간
- **Refresh Token 만료** — 7~30일. 저장소에서 탈취 시 무효화 가능해야
- **BCrypt strength** — 기본 10. 해시 시간 300ms 이내 권장
- **세션 타임아웃** — 기본 30분. `server.servlet.session.timeout`
- **CORS MaxAge** — 3600초
- **로그인 실패 제한** — 5~10회/15분 후 차단
- **JWT payload 크기** — 1KB 이내 권장. 과도한 claim은 쿠키·헤더 크기 초과 유발

---

## SecurityFilterChain 기본 구성

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/auth/**", "/api/public/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .exceptionHandling(ex -> ex
                .authenticationEntryPoint(authEntryPoint)
                .accessDeniedHandler(accessDeniedHandler))
            .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }
}
```

| 상황 | 세션 정책 | CSRF |
|---|---|---|
| REST API (Bearer) | STATELESS | disable |
| SSR (서버 렌더링) | IF_REQUIRED | enable (기본값) |
| REST + Cookie | STATELESS | CookieCsrfTokenRepository |

---

## 비밀번호 인코딩

```java
@Bean
public PasswordEncoder passwordEncoder() {
    return PasswordEncoderFactories.createDelegatingPasswordEncoder();
    // 기본값: BCrypt. 저장 시 {bcrypt} 프리픽스 자동 부여
}
```

- `DelegatingPasswordEncoder`는 해시에 `{bcrypt}`, `{scrypt}`, `{argon2}` 프리픽스로 알고리즘을 기록
- **레거시 마이그레이션**: 기존 해시에 `{noop}` 또는 `{MD5}` 프리픽스를 붙여 저장 → 사용자 로그인 시 BCrypt로 재인코딩하는 방식
- 평문 비교 금지. 항상 `matches()` 사용

---

## 로그인 처리 (폼/REST 공통)

### AuthenticationManager 주입

```java
@Bean
public AuthenticationManager authenticationManager(
        AuthenticationConfiguration config) throws Exception {
    return config.getAuthenticationManager();
}
```

### REST 로그인 컨트롤러

```java
@RestController
@RequiredArgsConstructor
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final JwtTokenProvider tokenProvider;
    private final RefreshTokenService refreshTokenService;

    @PostMapping("/api/auth/login")
    public TokenResponse login(@Valid @RequestBody LoginRequest request) {
        Authentication authentication = authenticationManager.authenticate(
            new UsernamePasswordAuthenticationToken(request.email(), request.password()));

        CustomUserDetails user = (CustomUserDetails) authentication.getPrincipal();
        String access = tokenProvider.createAccessToken(user.getId(), user.getRole());
        String refresh = refreshTokenService.issue(user.getId());
        return new TokenResponse(access, refresh);
    }
}
```

`authenticate()`가 성공하면 `UserDetailsService` + `PasswordEncoder`로 검증 완료된 상태. 실패 시 `BadCredentialsException` 발생.

---

## JWT 인증 패턴

```
요청 → JwtAuthenticationFilter → 토큰 파싱·검증 → SecurityContext 저장 → 인가 처리
```

### JwtTokenProvider

```java
@Component
public class JwtTokenProvider {

    private final SecretKey secretKey;
    private final long accessTokenExpiry;

    public JwtTokenProvider(@Value("${jwt.secret}") String secret,
                            @Value("${jwt.access-token-expiry}") long expiry) {
        this.secretKey = Keys.hmacShaKeyFor(Decoders.BASE64.decode(secret));
        this.accessTokenExpiry = expiry;
    }

    public String createAccessToken(Long userId, String role) {
        return Jwts.builder()
            .subject(String.valueOf(userId))
            .claim("role", role)
            .issuedAt(new Date())
            .expiration(new Date(System.currentTimeMillis() + accessTokenExpiry))
            .signWith(secretKey)
            .compact();
    }

    public Claims parseClaims(String token) {
        return Jwts.parser().verifyWith(secretKey).build()
            .parseSignedClaims(token).getPayload();
    }
}
```

### JwtAuthenticationFilter

```java
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtTokenProvider tokenProvider;
    private final UserDetailsService userDetailsService;
    private final TokenBlacklistService blacklistService;   // 로그아웃 지원

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        String token = resolveToken(request);
        if (token != null && !blacklistService.isBlacklisted(token)) {
            try {
                Claims claims = tokenProvider.parseClaims(token);
                UserDetails user = userDetailsService.loadUserByUsername(claims.getSubject());
                SecurityContextHolder.getContext().setAuthentication(
                    new UsernamePasswordAuthenticationToken(user, null, user.getAuthorities()));
            } catch (JwtException ignored) {
                // 인증 실패 시 SecurityContext 비워둠 → EntryPoint에서 401 처리
            }
        }
        chain.doFilter(request, response);
    }

    private String resolveToken(HttpServletRequest request) {
        String bearer = request.getHeader("Authorization");
        return StringUtils.hasText(bearer) && bearer.startsWith("Bearer ")
            ? bearer.substring(7) : null;
    }
}
```

### 401/403 응답

```java
@Component
public class AuthEntryPoint implements AuthenticationEntryPoint {
    @Override
    public void commence(HttpServletRequest req, HttpServletResponse res,
                         AuthenticationException e) throws IOException {
        res.setStatus(401);
        res.setContentType(MediaType.APPLICATION_JSON_VALUE);
        res.getWriter().write("{\"error\":\"Unauthorized\"}");
    }
}
// AccessDeniedHandler도 동일한 패턴으로 403 응답
```

---

## Refresh Token 로테이션

**기본 원칙**
- 저장소에서 관리할 수 있어야 탈취 시 무효화 가능 (Redis 권장)
- 재발급 시 기존 Refresh 폐기 → 새 Refresh 발급 (로테이션)
- 동일 Refresh 재사용 감지 시 해당 사용자 전체 토큰 무효화 (reuse detection)

### Redis 기반 구조

```
Key:   refresh:{userId}:{tokenId}
Value: { tokenHash, createdAt, userAgent, ip }
TTL:   refresh 만료와 동일
```

### 재발급 플로우

```java
@Service
@RequiredArgsConstructor
public class RefreshTokenService {

    private final StringRedisTemplate redis;
    private final JwtTokenProvider tokenProvider;

    public TokenResponse reissue(String refreshToken) {
        Claims claims = tokenProvider.parseClaims(refreshToken);
        Long userId = Long.valueOf(claims.getSubject());
        String tokenId = claims.getId();  // jti
        String key = "refresh:" + userId + ":" + tokenId;

        String stored = redis.opsForValue().get(key);
        if (stored == null) {
            // 저장소에 없으면 이미 로테이션됐거나 폐기된 것 → 재사용 의심
            revokeAll(userId);
            throw new TokenReuseDetectedException();
        }

        redis.delete(key);  // 기존 refresh 제거 (로테이션)
        String newAccess = tokenProvider.createAccessToken(userId, ...);
        String newRefresh = issue(userId);
        return new TokenResponse(newAccess, newRefresh);
    }

    public String issue(Long userId) { /* 새 Refresh 발급 + Redis 저장 */ }
    public void revokeAll(Long userId) { /* refresh:{userId}:* 전체 삭제 */ }
}
```

---

## 로그아웃 / 블랙리스트

Stateless JWT는 서버가 토큰을 "잊을" 수 없다. 두 가지 전략 중 선택.

| 전략 | 장점 | 단점 |
|---|---|---|
| **Access 짧게 + Refresh 폐기** | 블랙리스트 불필요, 성능 좋음 | 로그아웃 직후 최대 Access 만료까지 유효 |
| **Access 블랙리스트 (Redis)** | 즉시 무효화 | 모든 요청마다 Redis 조회 비용 |

### Access 블랙리스트 구현

```java
@Service
@RequiredArgsConstructor
public class TokenBlacklistService {

    private final StringRedisTemplate redis;

    public void blacklist(String token, long remainingSeconds) {
        redis.opsForValue().set("blacklist:" + token, "1",
            Duration.ofSeconds(remainingSeconds));
    }

    public boolean isBlacklisted(String token) {
        return Boolean.TRUE.equals(redis.hasKey("blacklist:" + token));
    }
}
```

`LogoutHandler`에서 현재 Access를 블랙리스트에 추가 + Refresh 삭제 + SecurityContext 클리어.

---

## OAuth2 Login (사용자 SSO)

사용자를 외부 IdP(Google·Kakao 등)로 로그인시킬 때.

```yaml
spring.security.oauth2.client.registration.google:
  client-id: ${GOOGLE_CLIENT_ID}
  client-secret: ${GOOGLE_CLIENT_SECRET}
  scope: openid, profile, email
```

```java
http.oauth2Login(oauth2 -> oauth2
    .userInfoEndpoint(u -> u.userService(customOAuth2UserService))
    .successHandler(oAuth2SuccessHandler)
);
```

### CustomOAuth2UserService + SuccessHandler

`loadUser()`에서 provider/providerId로 회원 조회·가입 → `onAuthenticationSuccess()`에서 JWT 발급 후 프론트로 리다이렉트.

```java
@Override
public void onAuthenticationSuccess(HttpServletRequest req, HttpServletResponse res,
                                    Authentication auth) throws IOException {
    CustomOAuth2User user = (CustomOAuth2User) auth.getPrincipal();
    String token = tokenProvider.createAccessToken(user.getUserId(), user.getRole());
    getRedirectStrategy().sendRedirect(req, res, "/oauth2/callback?token=" + token);
}
```

---

## OAuth2 Resource Server (API 보호)

외부 IdP(Keycloak·Auth0·Cognito)가 발급한 JWT로 API를 보호할 때. 자체 JWT 필터를 만들 필요 없음.

```yaml
spring.security.oauth2.resourceserver.jwt:
  issuer-uri: https://auth.example.com/realms/myrealm
  # 또는 jwk-set-uri 직접 지정
```

```java
http.oauth2ResourceServer(oauth2 -> oauth2
    .jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthenticationConverter()))
);
```

### 권한 매핑 (Keycloak 예)

IdP가 넣어주는 claim을 Spring의 `GrantedAuthority`로 변환.

```java
@Bean
public JwtAuthenticationConverter jwtAuthenticationConverter() {
    JwtGrantedAuthoritiesConverter authorities = new JwtGrantedAuthoritiesConverter();
    authorities.setAuthoritiesClaimName("roles");  // IdP가 쓰는 claim 이름
    authorities.setAuthorityPrefix("ROLE_");

    JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
    converter.setJwtGrantedAuthoritiesConverter(authorities);
    return converter;
}
```

**Login vs Resource Server 선택 기준**
- 사용자가 브라우저로 직접 로그인하는가 → **Login**
- 이미 발급된 JWT(IdP 또는 자체 발급)로 API를 호출받는가 → **Resource Server**
- 둘 다 필요하면 `SecurityFilterChain`을 분리해서 `@Order`로 우선순위 지정

---

## CORS 설정

```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration config = new CorsConfiguration();
    config.setAllowedOrigins(List.of("https://example.com"));
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
    config.setAllowedHeaders(List.of("*"));
    config.setAllowCredentials(true);
    config.setMaxAge(3600L);
    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/**", config);
    return source;
}
```

- `allowCredentials(true)` + `allowedOrigins("*")` 불가 → 도메인 명시
- `allowedOriginPatterns(...)`를 쓰면 와일드카드 허용
- `@CrossOrigin`과 충돌 시 Security 설정이 우선

---

## CSRF

- REST + Bearer 토큰 → disable
- SSR → 기본값 유지
- SPA + 세션 쿠키 → `CookieCsrfTokenRepository.withHttpOnlyFalse()` + `CsrfTokenRequestAttributeHandler` (Security 6 기본 Xor 핸들러가 SPA와 충돌하면 비Xor 핸들러로 교체)

```java
http.csrf(csrf -> csrf
    .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
    .csrfTokenRequestHandler(new CsrfTokenRequestAttributeHandler())
);
```

---

## 보안 헤더

Spring Security는 기본으로 `X-Frame-Options`, `X-Content-Type-Options`, `Cache-Control` 등을 설정. API 서버에선 필요 없는 것 제거, 프론트 서버에선 추가 강화.

```java
http.headers(headers -> headers
    .httpStrictTransportSecurity(hsts -> hsts
        .includeSubDomains(true)
        .maxAgeInSeconds(31536000))  // 1년
    .frameOptions(FrameOptionsConfig::deny)
    .contentSecurityPolicy(csp -> csp
        .policyDirectives("default-src 'self'; frame-ancestors 'none'"))
    .referrerPolicy(r -> r.policy(ReferrerPolicy.SAME_ORIGIN))
);
```

- HSTS는 HTTPS 환경에서만 의미 있음
- CSP는 프론트를 같은 서버에서 서빙할 때 효과적. SPA 분리 구조면 프론트 측에서 설정

---

## 권한 설계 패턴

| 구분 | 접두사 | 사용 메서드 |
|---|---|---|
| Role | `ROLE_` 자동 추가 | `hasRole("ADMIN")` |
| Authority | 없음 | `hasAuthority("order:write")` |

```java
public class CustomUserDetails implements UserDetails {
    private final User user;

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_" + user.getRole().name()));
    }
    // getPassword() → user.getPassword()
    // getUsername() → String.valueOf(user.getId())
    // 나머지 boolean 메서드 → 별도 정책 없으면 true
}
```

---

## 메서드 보안

```java
@EnableMethodSecurity  // Security 6. Security 5: @EnableGlobalMethodSecurity(prePostEnabled = true)
```

```java
@PreAuthorize("hasRole('ADMIN')")
@PreAuthorize("hasAuthority('order:write')")
@PreAuthorize("authentication.name == #userId.toString()")
@PreAuthorize("hasRole('ADMIN') or authentication.name == #userId.toString()")
@PostAuthorize("returnObject.ownerId == authentication.name")
```

self-invocation 주의: 같은 클래스 내부 호출은 AOP 프록시를 우회. 별도 빈으로 분리.

---

## @AuthenticationPrincipal

컨트롤러에서 현재 사용자를 꺼낼 때.

```java
@GetMapping("/api/me")
public UserDto me(@AuthenticationPrincipal CustomUserDetails user) {
    return userService.findById(user.getId());
}

// SpEL로 특정 필드만
@GetMapping("/api/my-orders")
public List<Order> myOrders(@AuthenticationPrincipal(expression = "id") Long userId) {
    return orderService.findByUserId(userId);
}
```

OAuth2 Resource Server 환경에서는 Principal이 `Jwt` 타입. `@AuthenticationPrincipal Jwt jwt`로 받고 `jwt.getSubject()`, `jwt.getClaim("email")` 조회.

---

## Rate Limiting / Brute Force 방어

로그인 엔드포인트는 반드시 제한. 전용 라이브러리(Bucket4j) 또는 Redis 카운터로 구현.

### Redis 카운터 기본 구조

```java
@Component
@RequiredArgsConstructor
public class LoginAttemptService {

    private final StringRedisTemplate redis;
    private static final int MAX_ATTEMPTS = 5;
    private static final Duration BLOCK_DURATION = Duration.ofMinutes(15);

    public void recordFailure(String key) {
        Long count = redis.opsForValue().increment("login:fail:" + key);
        if (count != null && count == 1) {
            redis.expire("login:fail:" + key, BLOCK_DURATION);
        }
        if (count != null && count >= MAX_ATTEMPTS) {
            throw new TooManyAttemptsException();
        }
    }

    public void reset(String key) {
        redis.delete("login:fail:" + key);
    }
}
```

key는 `email + IP` 조합 권장. IP만 쓰면 NAT 환경에서 정상 사용자까지 차단.

---

## 감사 이벤트

Spring Security는 인증 성공·실패 이벤트를 자동 발행. 로그인 이력·실패 추적에 활용.

```java
@Component
@Slf4j
public class AuthEventListener {

    @EventListener
    public void handleSuccess(AuthenticationSuccessEvent event) {
        log.info("login success: {}", event.getAuthentication().getName());
    }

    @EventListener
    public void handleFailure(AbstractAuthenticationFailureEvent event) {
        log.warn("login failure: {} - {}",
            event.getAuthentication().getName(),
            event.getException().getMessage());
    }
}
```

- `AuthenticationSuccessEvent`, `AuthenticationFailureBadCredentialsEvent`, `AuthenticationFailureLockedEvent` 등 개별 이벤트 존재
- 프로덕션에선 실패 이벤트를 Rate Limiter에 연결

---

## 서비스 간 인증 전파

현재 요청의 JWT를 다른 서비스 호출에 전달할 때.

```java
@Bean
public WebClient webClient() {
    return WebClient.builder()
        .filter((request, next) -> {
            String token = Optional.ofNullable(SecurityContextHolder.getContext().getAuthentication())
                .map(auth -> (Jwt) auth.getPrincipal())
                .map(Jwt::getTokenValue)
                .orElse(null);
            if (token != null) {
                return next.exchange(ClientRequest.from(request)
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + token)
                    .build());
            }
            return next.exchange(request);
        })
        .build();
}
```

비동기 경계에서는 `DelegatingSecurityContextExecutor`로 감싸거나, 스레드 로컬 전략을 `MODE_INHERITABLETHREADLOCAL`로.

---

## 테스트 (spring-security-test)

```java
// 1. 역할·권한 지정
@Test
@WithMockUser(username = "admin", roles = "ADMIN")
void 관리자_삭제_성공() { ... }

// 2. 실제 UserDetailsService 사용
@Test
@WithUserDetails("user@example.com")
void 본인만_접근() { ... }

// 3. MockMvc에서 JWT 모사
mockMvc.perform(get("/api/admin/users")
    .with(jwt().authorities(new SimpleGrantedAuthority("ROLE_ADMIN"))))
    .andExpect(status().isOk());

// 4. CSRF 토큰이 필요한 POST
mockMvc.perform(post("/api/orders").with(csrf())...);
```

- 통합 테스트에선 실제 `AuthenticationManager`로 로그인 후 토큰을 받아 호출하는 편이 안전
- `@WithMockUser`는 `UserDetailsService`를 타지 않으므로 Principal 타입이 다를 수 있음

---

## 안티패턴

- **requestMatchers 순서** — 구체적 경로 먼저. `anyRequest()`는 마지막
- **비동기 SecurityContext 누락** — 기본 ThreadLocal 전략은 새 스레드에 전파 안 됨. `MODE_INHERITABLETHREADLOCAL` 또는 `DelegatingSecurityContextExecutor`
- **passwordEncoder 순환 참조** — `PasswordEncoder`와 `UserDetailsService`를 같은 설정 클래스에 두면 순환 의존. 분리
- **Refresh를 JWT로만 관리** — 저장소 없이는 탈취·로그아웃 대응 불가
- **Refresh에 권한 claim 포함** — Refresh는 재발급 식별용. 권한은 Access에만
- **JWT에 민감정보 담기** — Payload는 Base64일 뿐 암호화 아님
- **`permitAll()` + Security Context 없는 상태에서 Principal 조회** — NPE. null 체크 또는 `Optional` 처리
- **테스트 SecurityContext 직접 조작** — `@WithMockUser` / `@WithUserDetails` 사용

---

## 버전 적용 규칙

환경 감지 결과에 맞춰 변환.

### Spring Security 5 → 6

| Security 5 (Boot 2.x) | Security 6 (Boot 3.x) |
|---|---|
| `WebSecurityConfigurerAdapter` 상속 | `SecurityFilterChain` 빈 |
| `antMatchers()` | `requestMatchers()` |
| `authorizeRequests()` | `authorizeHttpRequests()` |
| `@EnableGlobalMethodSecurity(prePostEnabled = true)` | `@EnableMethodSecurity` |
| 메서드 체인 DSL (`http.csrf().disable()`) | lambda DSL (`http.csrf(c -> c.disable())`) |

Boot 2.7에서 기존 코드가 Adapter 방식이면 그대로 유지.

### jjwt 0.11.x → 0.12.x

| 0.11.x | 0.12.x |
|---|---|
| `Jwts.parserBuilder().setSigningKey(key).build()` | `Jwts.parser().verifyWith(key).build()` |
| `.parseClaimsJws(token).getBody()` | `.parseSignedClaims(token).getPayload()` |
| `.setSubject()`, `.setIssuedAt()`, `.setExpiration()` | `.subject()`, `.issuedAt()`, `.expiration()` |

### Java 버전별 활용

| Java | 적용 가능한 것 |
|---|---|
| 8 | 기본 문법만 |
| 11 | `var` 타입 추론 |
| 17+ | `record`로 DTO 선언 (`record TokenResponse(String access, String refresh) {}`) |
| 21 | 가상 스레드. 블로킹 세션 코드 성능 재검토 |

---

## 추가 확장 제안

프로젝트 성격에 따라 이후 검토할 것들. 지금 넣을 필요가 없으면 건너뛰되, 요구가 생기면 별도 요청.

| 상황 | 제안 |
|---|---|
| 다중 인증 방식 공존 (예: 내부 관리자는 폼+세션, 외부 API는 JWT) | `SecurityFilterChain`을 `@Order`로 분리. `securityMatcher()`로 경로별 체인 구성 |
| 마이크로서비스 게이트웨이 | Gateway에서 인증 종료 후 내부 서비스엔 `X-User-Id` 헤더 또는 서명된 토큰 전달 |
| 2FA / MFA 요구 | OTP 라이브러리(예: `java-totp`)로 2차 단계 구성. AuthenticationProvider 체인에 추가 |
| 감사 규제(SOX, ISO 27001 등) | 로그인/권한 변경 이력을 별도 감사 테이블에 영구 저장. Spring Data Envers 검토 |
| Remember-Me (SSR) | `http.rememberMe(r -> r.key(...).tokenValiditySeconds(...))` + `PersistentTokenRepository` |
| API Key 인증 (B2B/서버 간) | 커스텀 `AuthenticationFilter` + API Key 저장소. JWT와 필터 체인 분리 |
| 세분화된 도메인 권한 (예: "본인 부서 주문만 수정") | `PermissionEvaluator` 구현 + `@PreAuthorize("hasPermission(...)")` |
| 비밀번호 정책 강제 | Passay 라이브러리 + `@Valid` 커스텀 validator |
| 보안 스캔·취약점 감사 | `spring-boot-starter-actuator` + OWASP Dependency Check / `snyk` 자동화 |
