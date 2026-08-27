package com.snapcal.module.water.vo;

import lombok.Data;

import java.io.Serializable;

@Data
public class WaterTodayVO implements Serializable {

    private String date;

    private Integer totalMl;

    private Integer goalMl;
}
