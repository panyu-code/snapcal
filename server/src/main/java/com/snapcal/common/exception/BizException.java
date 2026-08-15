package com.snapcal.common.exception;

import com.snapcal.common.result.ResultCode;
import lombok.Getter;

@Getter
public class BizException extends RuntimeException {

    private final Integer code;

    public BizException(String message) {
        super(message);
        this.code = ResultCode.FAIL.getCode();
    }

    public BizException(ResultCode code) {
        super(code.getMessage());
        this.code = code.getCode();
    }

    public BizException(Integer code, String message) {
        super(message);
        this.code = code;
    }
}
