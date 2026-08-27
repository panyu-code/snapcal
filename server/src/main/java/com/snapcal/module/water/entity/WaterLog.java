package com.snapcal.module.water.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.io.Serializable;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@TableName("sc_water_log")
public class WaterLog implements Serializable {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long userId;

    private LocalDate logDate;

    /** 毫升 (补记可为负) */
    private Integer amountMl;

    private LocalDateTime createTime;
}
