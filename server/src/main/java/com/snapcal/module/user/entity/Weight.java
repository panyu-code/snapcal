package com.snapcal.module.user.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.io.Serializable;
import java.time.LocalDate;

@Data
@TableName("sc_weight")
public class Weight implements Serializable {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long userId;

    private Double weightKg;

    private LocalDate recordDate;
}
