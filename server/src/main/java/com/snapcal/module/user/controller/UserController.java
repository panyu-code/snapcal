package com.snapcal.module.user.controller;

import com.snapcal.common.result.Result;
import com.snapcal.module.user.dto.ProfileUpdateReqDTO;
import com.snapcal.module.user.service.UserService;
import com.snapcal.module.user.vo.UserVO;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/user")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping("/me")
    public Result<UserVO> me() {
        return Result.success(userService.me());
    }

    @PutMapping("/profile")
    public Result<UserVO> updateProfile(@Valid @RequestBody ProfileUpdateReqDTO dto) {
        return Result.success(userService.updateProfile(dto));
    }
}
