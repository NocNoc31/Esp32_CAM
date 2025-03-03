// Kết nối WebSocket
function createWebSocket() {
    const socket = new WebSocket("ws://192.168.4.1:81");
    
    const reconnectConfig = {
        maxAttempts: 5,
        currentAttempts: 0,
        delay: 2000,
        maxDelay: 10000
    };

    socket.onopen = () => {
        console.log("WebSocket connected");
        reconnectConfig.currentAttempts = 0;
    };

    socket.onerror = (error) => {
        console.error("WebSocket Error: ", error);
    };

    socket.onclose = () => {
        console.warn("WebSocket closed. Attempting to reconnect...");
        if (reconnectConfig.currentAttempts < reconnectConfig.maxAttempts) {
            const delay = Math.min(
                reconnectConfig.delay * Math.pow(2, reconnectConfig.currentAttempts),
                reconnectConfig.maxDelay
            );
            console.log(`Reconnecting in ${delay/1000} seconds... (Attempt ${reconnectConfig.currentAttempts + 1}/${reconnectConfig.maxAttempts})`);
            setTimeout(() => {
                reconnectConfig.currentAttempts++;
                createWebSocket();
            }, delay);
        } else {
            console.error("Max reconnect attempts reached. Please check the server!");
        }
    };

    return socket;
}

// Khởi tạo WebSocket
const socket = createWebSocket();
let isStreaming = false;
let distanceInput = 10;
let timeInput = 5;
let timeErrorCounter = 0;
let isCountingTimeError = false;

const ctx = document.getElementById('chart').getContext('2d');
const chart = new Chart(ctx, {
    type: 'line',
    data: {
        labels: [],
        datasets: [{
            label: 'Distance (cm)',
            data: [],
            borderColor: 'blue',
            borderWidth: 1
        }]
    },
    options: { scales: { y: { beginAtZero: true } } }
});

// Xử lý dữ liệu nhận từ WebSocket
socket.onmessage = function (event) {
    if (event.data instanceof Blob) {
        const imageUrl = URL.createObjectURL(event.data);
        if (isStreaming) {
            document.getElementById("capturedVideo").src = imageUrl;
        } else {
            document.getElementById("capturedImage").src = imageUrl;
        }
    } else {
        const distance = parseInt(event.data);
        if (!isNaN(distance)) {
            document.getElementById("distance_now").textContent = distance;
            updateChart(distance);
        }
    }
};

// Cập nhật biểu đồ khoảng cách
function updateChart(newDistance) {
    chart.data.labels.push(chart.data.labels.length.toString());
    chart.data.datasets[0].data.push(newDistance);
    chart.update();

    if (distanceInput !== null && newDistance < distanceInput) {
        console.log(`Distance Input ${distanceInput}`);
        console.log(`New Distance ${newDistance}`);
        if (!isCountingTimeError) {
            showPopup('Đang tính thời gian cảnh báo...');
            isCountingTimeError = true;
        }
        timeErrorCounter++;
        document.getElementById('time_error').textContent = timeErrorCounter;

        if (timeErrorCounter > timeInput) {
            showPopup('Cảnh báo: Hãy điều chỉnh khoảng cách!');
            // Gửi tín hiệu BUZZ đến Arduino
            if (socket.readyState === WebSocket.OPEN) {
                socket.send("BUZZ");
                console.log("Sent BUZZ signal to Arduino");
            } else {
                console.error("WebSocket not connected, cannot send BUZZ signal!");
            }
        }
    } else {
        timeErrorCounter = 0;
        isCountingTimeError = false;
        document.getElementById('time_error').textContent = "0";
    }
}

// Thiết lập khoảng cách cảnh báo
document.getElementById('set_distance_btn').addEventListener('click', () => {
    distanceInput = parseFloat(document.getElementById('set_distance').value);
    if (!isNaN(distanceInput)) {
        showPopup(`Khoảng cách cảnh báo: ${distanceInput} cm`);
    } else {
        showPopup('Vui lòng nhập giá trị khoảng cách hợp lệ!');
    }
});

// Thiết lập thời gian cảnh báo
document.getElementById('set_time_btn').addEventListener('click', () => {
    timeInput = parseFloat(document.getElementById('set_time').value);
    if (!isNaN(timeInput)) {
        showPopup(`Thời gian cảnh báo: ${timeInput} giây`);
    } else {
        showPopup('Vui lòng nhập giá trị thời gian hợp lệ!');
    }
});

// Hiển thị popup cảnh báo
function showPopup(message) {
    const popupMessage = document.getElementById("popupMessage");
    const popupModal = document.getElementById("popupModal");
    if (popupMessage && popupModal) {
        popupMessage.textContent = message;
        popupModal.style.display = "block";
    } else {
        console.error("Không tìm thấy phần tử popup!");
    }
}

// Xử lý chụp ảnh
document.getElementById('capture_btn').addEventListener('click', () => {
    isStreaming = false;
    if (socket.readyState === WebSocket.OPEN) {
        socket.send("CAPTURE");
        document.getElementById("imageModal").style.display = "block";
        console.log("Chụp ảnh thành công");
    } else {
        console.error("WebSocket chưa kết nối, không thể gửi lệnh CAPTURE!");
    }
});

// Mở cửa sổ quay video
document.getElementById('video_btn').addEventListener('click', () => {
    document.getElementById("videoModal").style.display = "block";
});

// Bắt đầu quay video
document.getElementById('start_btn').addEventListener('click', () => {
    isStreaming = true;
    if (socket.readyState === WebSocket.OPEN) {
        socket.send("START_RECORD");
        console.log("Bắt đầu quay video");
        showPopup("Đang quay video...");
    } else {
        console.error("WebSocket chưa kết nối, không thể gửi lệnh START_RECORD!");
    }
});

// Dừng quay video
document.getElementById('stop_btn').addEventListener('click', () => {
    isStreaming = false;
    if (socket.readyState === WebSocket.OPEN) {
        socket.send("STOP_RECORD");
        console.log("Dừng quay video");
        showPopup("Dừng quay video!");
    } else {
        console.error("WebSocket chưa kết nối, không thể gửi lệnh STOP_RECORD!");
    }
});

// Đóng modal khi nhấn 'X'
document.querySelectorAll(".close").forEach((btn) => {
    btn.addEventListener("click", () => btn.parentElement.parentElement.style.display = "none");
});