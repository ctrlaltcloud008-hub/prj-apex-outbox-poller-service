FROM golang:1.26.3 AS build
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /outbox-relay ./cmd

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=build /outbox-relay /app/outbox-relay

ENV PORT=8000
EXPOSE 8000

ENTRYPOINT ["/app/outbox-relay"]
