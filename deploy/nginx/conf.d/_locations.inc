location / {
    proxy_pass http://base-web:31079;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}

# 001 FR-003: rust-api /metrics 不得對外暴露。location /api/ 會剝前綴把 /api/metrics 轉到
# rust-api /metrics;用 exact-match 擋塊回 404(優先於 prefix /api/)。內網 prometheus 仍直接
# scrape rust-api:31081/metrics、不經 nginx、不受此擋塊影響。
location = /api/metrics {
    return 404;
}

location /api/ {
    proxy_pass http://rust-api:31081/;   # ★ 末尾 / 必要:strip /api 前綴
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Request-Id $request_id;
    # 013 FR-010 · CF 驗證旗標 + strip 後的權威 client IP（geo/map 定義於 nginx.conf http context）。
    # ★ proxy_set_header 會【覆寫】client 偽造的同名 header＝防偽造核心：非 CF 源 $x_cf_verified=0、
    #   $cf_cip_safe="" → rust overlay 不 fire。CF 只進 /api/，location / 不需加。
    proxy_set_header X-CF-Verified $x_cf_verified;
    proxy_set_header CF-Connecting-IP $cf_cip_safe;
}

location = /health {
    default_type text/plain;
    return 200 "ok\n";
}
