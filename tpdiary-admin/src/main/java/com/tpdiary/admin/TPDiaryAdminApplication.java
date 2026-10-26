package com.tpdiary.admin;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * TPDiary 管理端启动入口。
 */
@SpringBootApplication(scanBasePackages = "com.tpdiary")
public class TPDiaryAdminApplication {

    public static void main(String[] args) {
        SpringApplication.run(TPDiaryAdminApplication.class, args);
    }
}
