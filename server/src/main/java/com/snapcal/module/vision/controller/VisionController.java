package com.snapcal.module.vision.controller;

import com.snapcal.common.result.Result;
import com.snapcal.module.vision.service.VisionService;
import com.snapcal.module.vision.vo.RecognizeResultVO;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/vision")
@RequiredArgsConstructor
public class VisionController {

    private final VisionService visionService;

    /** 上传餐盘照片 → AI 识别食物营养 */
    @PostMapping("/recognize")
    public Result<RecognizeResultVO> recognize(@RequestParam("file") MultipartFile file) {
        return Result.success(visionService.recognize(file));
    }
}
