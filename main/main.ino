#include <WiFi.h>
#include <WebSocketsServer.h>
#include "esp_camera.h"

// Thông tin Wi-Fi
const char* ssid = "nocnoc31";
const char* password = "12345678";

// WebSocket server
WebSocketsServer webSocket = WebSocketsServer(81);

// Cấu hình chân kết nối camera
#define PWDN_GPIO_NUM  32
#define RESET_GPIO_NUM -1
#define XCLK_GPIO_NUM  0
#define SIOD_GPIO_NUM  26
#define SIOC_GPIO_NUM  27
#define Y9_GPIO_NUM    35
#define Y8_GPIO_NUM    34
#define Y7_GPIO_NUM    39
#define Y6_GPIO_NUM    36
#define Y5_GPIO_NUM    21
#define Y4_GPIO_NUM    19
#define Y3_GPIO_NUM    18
#define Y2_GPIO_NUM    5
#define VSYNC_GPIO_NUM 25
#define HREF_GPIO_NUM  23
#define PCLK_GPIO_NUM  22

// Cấu hình chân cảm biến HC-SR04
#define TRIG_PIN 12  // IO12
#define ECHO_PIN 13  // IO13

// Định nghĩa chân LED và Buzzer
const int led = 4;
const int buzz = 15;

// Biến toàn cục
SemaphoreHandle_t recordingMutex;
volatile bool isRecording = false;
QueueHandle_t imageQueue;
QueueHandle_t distanceQueue;

// Task Handles
TaskHandle_t TaskWiFiHandle;
TaskHandle_t TaskWebSocketHandle;
TaskHandle_t TaskCameraHandle;
TaskHandle_t TaskDistanceHandle;

// Hàm nháy LED
void blinkLED(int times) {
    for (int i = 0; i < times; i++) {
        digitalWrite(led, HIGH);
        delay(200);
        digitalWrite(led, LOW);
        delay(200);
    }
}

// Hàm kích hoạt buzzer
void triggerBuzzer() {
    digitalWrite(buzz, HIGH); // Bật buzzer
    delay(500);              // Kêu trong 500ms
    digitalWrite(buzz, LOW);  // Tắt buzzer
}

// Khởi tạo camera
bool startCamera() {
    camera_config_t config;
    config.ledc_channel = LEDC_CHANNEL_0;
    config.ledc_timer = LEDC_TIMER_0;
    config.pin_d0 = Y2_GPIO_NUM;
    config.pin_d1 = Y3_GPIO_NUM;
    config.pin_d2 = Y4_GPIO_NUM;
    config.pin_d3 = Y5_GPIO_NUM;
    config.pin_d4 = Y6_GPIO_NUM;
    config.pin_d5 = Y7_GPIO_NUM;
    config.pin_d6 = Y8_GPIO_NUM;
    config.pin_d7 = Y9_GPIO_NUM;
    config.pin_xclk = XCLK_GPIO_NUM;
    config.pin_pclk = PCLK_GPIO_NUM;
    config.pin_vsync = VSYNC_GPIO_NUM;
    config.pin_href = HREF_GPIO_NUM;
    config.pin_sscb_sda = SIOD_GPIO_NUM;
    config.pin_sscb_scl = SIOC_GPIO_NUM;
    config.pin_pwdn = PWDN_GPIO_NUM;
    config.pin_reset = RESET_GPIO_NUM;
    config.xclk_freq_hz = 20000000;
    config.pixel_format = PIXFORMAT_JPEG;

    if (psramFound()) {
        config.frame_size = FRAMESIZE_UXGA;
        config.jpeg_quality = 10;
        config.fb_count = 2;
    } else {
        config.frame_size = FRAMESIZE_SVGA;
        config.jpeg_quality = 12;
        config.fb_count = 1;
    }

    esp_err_t err = esp_camera_init(&config);
    if (err != ESP_OK) {
        Serial.printf("Camera init failed with error 0x%x\n", err);
        return false;
    }
    return true;
}

// Chụp ảnh và gửi qua Queue
void captureAndSendImage() {
    camera_fb_t *fb = esp_camera_fb_get();
    if (!fb) {
        Serial.println("Camera capture failed");
        return;
    }
    if (xQueueSend(imageQueue, &fb, pdMS_TO_TICKS(100)) != pdTRUE) {
        Serial.println("Failed to send image to queue");
        esp_camera_fb_return(fb);
    }
}

// Hàm đo khoảng cách từ HC-SR04 và gửi qua Queue
void measureDistance() {
    digitalWrite(TRIG_PIN, LOW);
    delayMicroseconds(2);
    digitalWrite(TRIG_PIN, HIGH);
    delayMicroseconds(10);
    digitalWrite(TRIG_PIN, LOW);

    long duration = pulseIn(ECHO_PIN, HIGH, 30000);
    if (duration > 0) {
        int distance = duration * 0.034 / 2;
        if (xQueueSend(distanceQueue, &distance, pdMS_TO_TICKS(100)) != pdTRUE) {
            Serial.println("Failed to send distance to queue");
        }
    }
}

// Task 4: Đọc khoảng cách từ HC-SR04
void TaskDistance(void *parameter) {
    pinMode(TRIG_PIN, OUTPUT);
    pinMode(ECHO_PIN, INPUT);
    Serial.println("TaskDistance started");
    blinkLED(3);

    while (1) {
        measureDistance();
        vTaskDelay(1000 / portTICK_PERIOD_MS);
    }
}

// WebSocket event handler
void webSocketEvent(uint8_t num, WStype_t type, uint8_t *payload, size_t length) {
    switch (type) {
        case WStype_DISCONNECTED:
            Serial.printf("[%u] Disconnected!\n", num);
            break;
        case WStype_CONNECTED:
            Serial.printf("[%u] Connected\n", num);
            blinkLED(2);
            break;
        case WStype_TEXT:
            if (strcmp((char*)payload, "CAPTURE") == 0) {
                captureAndSendImage();
            } else if (strcmp((char*)payload, "START_RECORD") == 0) {
                if (xSemaphoreTake(recordingMutex, pdMS_TO_TICKS(100)) == pdTRUE) {
                    isRecording = true;
                    xSemaphoreGive(recordingMutex);
                    Serial.println("Recording started");
                }
            } else if (strcmp((char*)payload, "STOP_RECORD") == 0) {
                if (xSemaphoreTake(recordingMutex, pdMS_TO_TICKS(100)) == pdTRUE) {
                    isRecording = false;
                    xSemaphoreGive(recordingMutex);
                    Serial.println("Recording stopped");
                }
            } else if (strcmp((char*)payload, "BUZZ") == 0) {
                Serial.println("Received BUZZ command");
                triggerBuzzer(); // Kích hoạt buzzer khi nhận tín hiệu "BUZZ"
            }
            break;
    }
}

// Task 1: Quản lý Wi-Fi và WebSocket
void TaskWiFi(void *parameter) {
    WiFi.softAP(ssid, password);
    Serial.print("AP IP: ");
    Serial.println(WiFi.softAPIP());
    blinkLED(1);

    webSocket.begin();
    webSocket.onEvent(webSocketEvent);

    while (1) {
        webSocket.loop();
        vTaskDelay(2 / portTICK_PERIOD_MS);
    }
}

// Task 2: Gửi dữ liệu WebSocket (ảnh và khoảng cách)
void TaskWebSocket(void *parameter) {
    Serial.println("TaskWebSocket started");
    blinkLED(2);

    while (1) {
        camera_fb_t *fb;
        if (xQueueReceive(imageQueue, &fb, 0) == pdTRUE) {
            webSocket.broadcastBIN(fb->buf, fb->len);
            esp_camera_fb_return(fb);
        }

        int distance;
        if (xQueueReceive(distanceQueue, &distance, 0) == pdTRUE) {
            char buffer[10];
            sprintf(buffer, "%d", distance);
            webSocket.broadcastTXT(buffer);
        }

        vTaskDelay(1 / portTICK_PERIOD_MS);
    }
}

// Task 3: Xử lý Camera
void TaskCamera(void *parameter) {
    Serial.println("TaskCamera started");
    blinkLED(4);

    while (1) {
        if (xSemaphoreTake(recordingMutex, pdMS_TO_TICKS(100)) == pdTRUE) {
            bool recording = isRecording;
            xSemaphoreGive(recordingMutex);

            if (recording) {
                camera_fb_t *fb = esp_camera_fb_get();
                if (fb) {
                    if (xQueueSend(imageQueue, &fb, pdMS_TO_TICKS(100)) != pdTRUE) {
                        esp_camera_fb_return(fb);
                    }
                }
            }
        }
        vTaskDelay(33 / portTICK_PERIOD_MS);
    }
}

void setup() {
    Serial.begin(115200);
    pinMode(led, OUTPUT);
    digitalWrite(led, LOW);
    pinMode(buzz, OUTPUT); // Khởi tạo chân buzzer
    digitalWrite(buzz, LOW); // Tắt buzzer ban đầu

    if (!startCamera()) {
        Serial.println("Camera failed. Restarting...");
        delay(1000);
        ESP.restart();
    }

    recordingMutex = xSemaphoreCreateMutex();
    imageQueue = xQueueCreate(2, sizeof(camera_fb_t*));
    distanceQueue = xQueueCreate(5, sizeof(int));

    if (recordingMutex == NULL || imageQueue == NULL || distanceQueue == NULL) {
        Serial.println("Failed to create FreeRTOS objects. Restarting...");
        delay(1000);
        ESP.restart();
    }

    if (xTaskCreatePinnedToCore(TaskWiFi, "TaskWiFi", 8192, NULL, 1, &TaskWiFiHandle, 0) != pdPASS ||
        xTaskCreatePinnedToCore(TaskWebSocket, "TaskWebSocket", 8192, NULL, 1, &TaskWebSocketHandle, 1) != pdPASS ||
        xTaskCreatePinnedToCore(TaskCamera, "TaskCamera", 8192, NULL, 2, &TaskCameraHandle, 0) != pdPASS ||
        xTaskCreatePinnedToCore(TaskDistance, "TaskDistance", 4096, NULL, 1, &TaskDistanceHandle, 1) != pdPASS) {
        Serial.println("Failed to create tasks. Restarting...");
        ESP.restart();
    }
}

void loop() {
    vTaskDelay(portMAX_DELAY);
}