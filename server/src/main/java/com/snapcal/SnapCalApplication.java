package com.snapcal;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
@MapperScan("com.snapcal.module.**.mapper")
public class SnapCalApplication {

    public static void main(String[] args) {
        SpringApplication.run(SnapCalApplication.class, args);
        System.out.println("""

                ╔══════════════════════════════════════╗
                ║   SnapCal 卡路里相机 后端启动成功!     ║
                ║   http://localhost:8081/api/health   ║
                ╚══════════════════════════════════════╝
                """);
    }
}
