# ===== build stage =====
FROM golang:1.25 AS builder

WORKDIR /app

# まだ go.sum は無いので go.mod だけコピー
COPY go.mod ./

# コンテナ内で go mod tidy → ここで go.sum が生成される
RUN go mod tidy

# 残りのソースをコピー
COPY . .

# Linux 向けにビルド
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o server .

# ===== run stage =====
FROM gcr.io/distroless/base-debian12

WORKDIR /app
COPY --from=builder /app/server /app/server

ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/app/server"]
