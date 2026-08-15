package com.snapcal.module.vision.dto;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Data
@Configuration
@ConfigurationProperties(prefix = "snapcal.vision")
public class VisionProperties {

    /** mock / glm / qwen / siliconflow */
    private String provider = "mock";

    private String apiKey;

    private String model = "glm-4v-flash";

    private String apiUrl = "https://open.bigmodel.cn/api/paas/v4/chat/completions";
}
