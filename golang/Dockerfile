FROM golang:1.15.1-alpine3.12 AS build-env

WORKDIR /tmp/simple-go-app

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build 

FROM scratch
WORKDIR /app
COPY static/index.html /app/static/index.html
COPY --from=build-env /tmp/simple-go-app/prometheus-sample-app /app/prometheus-sample-app

EXPOSE 8080
CMD ["./prometheus-sample-app"]
