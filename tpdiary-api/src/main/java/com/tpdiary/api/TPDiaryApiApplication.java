package com.tpdiary.api;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * TPDiary 主业务 API 启动入口。
 */
@SpringBootApplication(scanBasePackages = "com.tpdiary")
public class TPDiaryApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(TPDiaryApiApplication.class, args);
    }
}
