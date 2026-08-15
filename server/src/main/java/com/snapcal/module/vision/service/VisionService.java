package com.snapcal.module.vision.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.snapcal.common.exception.BizException;
import com.snapcal.config.oss.OssService;
import com.snapcal.module.vision.dto.VisionProperties;
import com.snapcal.module.vision.vo.RecognizeResultVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import net.coobird.thumbnailator.Thumbnails;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.client.RestClient;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class VisionService {

    private static final String PROMPT = """
            你是营养分析专家。分析这张餐盘照片，识别所有食物。
            严格输出 JSON 数组（不要任何其他文字），每项字段：
            {"name":"菜品中文名","weight_g":克重整数,"kcal":该重量热量整数,
             "protein_g":蛋白质克数,"carbs_g":碳水克数,"fat_g":脂肪克数,"confidence":0到1置信度}
            weight_g 按图片中食物典型份量估算。不确定的食物宁可不列。""";

    private final VisionProperties props;
    private final OssService ossService;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public RecognizeResultVO recognize(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BizException("请上传餐盘照片");
        }
        String contentType = file.getContentType();
        if (contentType == null || !contentType.startsWith("image/")) {
            throw new BizException("仅支持图片文件");
        }

        try {
            // 1. 压缩到 1024px 内, 减小体积
            byte[] compressed = compress(file);

            // 2. 存 OSS 拿外网地址
            String ext = ".jpg";
            String url = ossService.upload("meal", ext,
                    new ByteArrayInputStream(compressed), compressed.length, MediaType.IMAGE_JPEG_VALUE);

            // 3. 调视觉 AI 识别
            List<RecognizeResultVO.Item> items;
            String engine;
            if ("mock".equals(props.getProvider())) {
                items = mockItems();
                engine = "mock";
            } else {
                items = callVisionApi(url);
                engine = props.getModel();
            }

            RecognizeResultVO vo = new RecognizeResultVO();
            vo.setImage(url);
            vo.setItems(items);
            vo.setEngine(engine);
            return vo;
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.error("识别失败", e);
            throw new BizException("图片识别失败: " + e.getMessage());
        }
    }

    private byte[] compress(MultipartFile file) throws Exception {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        Thumbnails.of(file.getInputStream())
                .size(1024, 1024)
                .outputFormat("jpg")
                .outputQuality(0.82)
                .toOutputStream(out);
        return out.toByteArray();
    }

    /** OpenAI 兼容视觉接口 (GLM-4V / Qwen-VL / SiliconFlow) */
    private List<RecognizeResultVO.Item> callVisionApi(String imageUrl) {
        if (!StringUtils.hasText(props.getApiKey())) {
            throw new BizException("视觉 AI 未配置 API Key (VISION_API_KEY)");
        }
        Map<String, Object> body = Map.of(
                "model", props.getModel(),
                "temperature", 0.1,
                "messages", List.of(Map.of(
                        "role", "user",
                        "content", List.of(
                                Map.of("type", "text", "text", PROMPT),
                                Map.of("type", "image_url",
                                        "image_url", Map.of("url", imageUrl))
                        )
                ))
        );
        try {
            SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
            factory.setConnectTimeout(15_000);
            factory.setReadTimeout(90_000);
            JsonNode response = RestClient.builder()
                    .baseUrl(props.getApiUrl())
                    .requestFactory(factory)
                    .defaultHeader("Authorization", "Bearer " + props.getApiKey())
                    .build()
                    .post()
                    .body(body)
                    .retrieve()
                    .body(JsonNode.class);

            String content = response.path("choices").path(0).path("message").path("content").asText();
            return parseItems(content);
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            throw new BizException("视觉 AI 调用失败: " + e.getMessage());
        }
    }

    private List<RecognizeResultVO.Item> parseItems(String content) {
        try {
            String json = content.trim();
            int start = json.indexOf('[');
            int end = json.lastIndexOf(']');
            if (start >= 0 && end > start) {
                json = json.substring(start, end + 1);
            }
            JsonNode array = objectMapper.readTree(json);
            List<RecognizeResultVO.Item> items = new ArrayList<>();
            for (JsonNode node : array) {
                RecognizeResultVO.Item item = new RecognizeResultVO.Item();
                item.setName(node.path("name").asText());
                item.setWeightG(node.path("weight_g").asInt(100));
                item.setKcal(node.path("kcal").asInt(0));
                item.setProteinG(node.path("protein_g").asDouble(0));
                item.setCarbsG(node.path("carbs_g").asDouble(0));
                item.setFatG(node.path("fat_g").asDouble(0));
                item.setConfidence(node.path("confidence").asDouble(0.8));
                if (StringUtils.hasText(item.getName())) {
                    items.add(item);
                }
            }
            if (items.isEmpty()) {
                throw new BizException("AI 未能识别出食物");
            }
            return items;
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.warn("AI 返回解析失败: {}", content);
            throw new BizException("AI 返回格式异常, 请重试");
        }
    }

    /** mock 模式演示数据 (未配置视觉 AI key 时跑通全链路) */
    private List<RecognizeResultVO.Item> mockItems() {
        return List.of(
                item("米饭", 200, 232, 5.1, 49.5, 0.6, 0.97),
                item("红烧鸡腿", 120, 245, 22.8, 4.2, 14.1, 0.92),
                item("清炒西兰花", 150, 51, 4.2, 5.6, 0.6, 0.88)
        );
    }

    private RecognizeResultVO.Item item(String name, int weight, int kcal,
                                        double protein, double carbs, double fat, double conf) {
        RecognizeResultVO.Item i = new RecognizeResultVO.Item();
        i.setName(name); i.setWeightG(weight); i.setKcal(kcal);
        i.setProteinG(protein); i.setCarbsG(carbs); i.setFatG(fat); i.setConfidence(conf);
        return i;
    }
}
