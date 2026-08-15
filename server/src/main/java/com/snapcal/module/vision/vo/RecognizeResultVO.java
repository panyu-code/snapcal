package com.snapcal.module.vision.vo;

import lombok.Data;

import java.io.Serializable;
import java.util.List;

@Data
public class RecognizeResultVO implements Serializable {

    /** 照片外网地址 */
    private String image;

    /** 识别出的食物项 */
    private List<Item> items;

    /** 识别方式 mock 或模型名 */
    private String engine;

    @Data
    public static class Item implements Serializable {
        private String name;
        private Integer weightG;
        private Integer kcal;
        private Double proteinG;
        private Double carbsG;
        private Double fatG;
        private Double confidence;
    }
}
