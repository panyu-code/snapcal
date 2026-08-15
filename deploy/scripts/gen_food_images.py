#!/usr/bin/env python3
# SnapCal 食物图片批量生成器 (服务器执行)
# 流程: MySQL拿待生成食物 -> SiliconFlow Kolors生成 -> 下载 -> RustFS -> 更新image_url
# 断点续传: 只处理 image_url IS NULL 的食物
import json, subprocess, time, sys, urllib.request, os

SF_KEY = "sk-kkssmcrhecyoucmlpbfxcapdisceermsrcrntmnnlgnhuagx"
SF_URL = "https://api.siliconflow.cn/v1/images/generations"
MODEL = "Kwai-Kolors/Kolors"
MYSQL = "docker exec dataviz-mysql mysql -uroot -pYuPan95270. snapcal -N -B --default-character-set=utf8mb4"
AWS_ENV = "AWS_ACCESS_KEY_ID=dataviz AWS_SECRET_ACCESS_KEY=YuPan95270. AWS_ENDPOINT_URL=http://127.0.0.1:9000 AWS_REGION=us-east-1"
BUCKET = "snapcal"
PUBLIC_BASE = "http://myblog.wiki:9000/snapcal/food"

LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 0   # 0=全部
INTERVAL = 12   # 每张间隔秒数 (QPS限制)
TMP = "/tmp/snapcal_food_tmp.png"

def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

def pending_foods(limit):
    sql = f"SELECT id,name FROM sc_food WHERE image_url IS NULL ORDER BY id"
    if limit > 0:
        sql += f" LIMIT {limit}"
    r = sh(f"{MYSQL} -e \"{sql}\" 2>/dev/null")
    foods = []
    for line in r.stdout.strip().split("\n"):
        parts = line.split("\t")
        if len(parts) >= 2:
            foods.append((parts[0], parts[1]))
    return foods

def generate(food_name):
    prompt = f"食物摄影，{food_name}，白色背景，居中构图，高清，无文字"
    body = json.dumps({
        "model": MODEL,
        "prompt": prompt,
        "image_size": "1024x1024",
        "num_inference_steps": 20
    }).encode()
    req = urllib.request.Request(SF_URL, data=body, headers={
        "Authorization": f"Bearer {SF_KEY}",
        "Content-Type": "application/json"
    })
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = json.loads(resp.read())
        imgs = data.get("images") or []
        if imgs:
            return imgs[0]["url"]
        print(f"  生成失败: {json.dumps(data, ensure_ascii=False)[:150]}")
        return None
    except Exception as e:
        print(f"  请求异常: {e}")
        return None

def process(fid, name):
    url = generate(name)
    if not url:
        return False
    # 下载
    try:
        urllib.request.urlretrieve(url, TMP)
    except Exception as e:
        print(f"  下载失败: {e}")
        return False
    # 上传 RustFS
    key = f"food/{fid}.png"
    up = sh(f"{AWS_ENV} aws s3 cp {TMP} s3://{BUCKET}/{key} --content-type image/png 2>&1")
    if up.returncode != 0:
        print(f"  上传失败: {up.stderr[:100]}")
        return False
    # 更新 DB
    img_url = f"{PUBLIC_BASE}/{fid}.png"
    upd = sh(f"{MYSQL} -e \"UPDATE sc_food SET image_url='{img_url}' WHERE id={fid};\" 2>/dev/null")
    if upd.returncode != 0:
        print(f"  更新DB失败")
        return False
    return True

def main():
    foods = pending_foods(LIMIT)
    total = len(foods)
    print(f"待生成: {total} 种食物")
    ok = 0
    for i, (fid, name) in enumerate(foods, 1):
        print(f"[{i}/{total}] {name} (id={fid})")
        if process(fid, name):
            ok += 1
        else:
            print(f"  ✗ {name} 失败, 跳过")
        if i < total:
            time.sleep(INTERVAL)
    print(f"\n完成: 成功 {ok}/{total}")

if __name__ == "__main__":
    main()
