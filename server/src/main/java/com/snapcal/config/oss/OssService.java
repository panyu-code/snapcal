package com.snapcal.config.oss;

import com.snapcal.common.exception.BizException;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.InputStream;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class OssService {

    private final S3Client s3Client;
    private final OssProperties props;

    @PostConstruct
    public void initBucket() {
        try {
            s3Client.headBucket(b -> b.bucket(props.getBucket()));
        } catch (Exception e) {
            try {
                s3Client.createBucket(b -> b.bucket(props.getBucket()));
                log.info("已创建 OSS bucket [{}]", props.getBucket());
            } catch (Exception ex) {
                log.warn("创建 bucket 失败: {}", ex.getMessage());
            }
        }
    }

    public String upload(String directory, String ext, InputStream input, long size, String contentType) {
        String datePath = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy/MM"));
        String key = directory + "/" + datePath + "/" + UUID.randomUUID().toString().replace("-", "") + ext;
        try {
            s3Client.putObject(
                    PutObjectRequest.builder()
                            .bucket(props.getBucket())
                            .key(key)
                            .contentType(contentType)
                            .build(),
                    RequestBody.fromInputStream(input, size));
            String base = props.getExternalEndpoint().replaceAll("/+$", "");
            return base + "/" + props.getBucket() + "/" + key;
        } catch (Exception e) {
            log.error("文件上传失败", e);
            throw new BizException("图片上传失败");
        }
    }
}
