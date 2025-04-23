
// Kết nối WebSocket
function createWebSocket() {
    const socket = new WebSocket("ws://192.168.4.1:81");
    // const socket = new WebSocket("ws://localhost:8765");

  
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
let latestImageBlob = null;
// Mảng lưu trữ lịch sử khoảng cách
let distanceHistory = [];


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

function formatTimestamp(date) {
    const pad = (num) => String(num).padStart(2, '0');
    return `${pad(date.getDate())}/${pad(date.getMonth() + 1)}/${date.getFullYear()} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

// Lưu trạng thái
function saveState() {
    const state = {
        distanceInput,
        timeInput
    };
    localStorage.setItem('systemState', JSON.stringify(state));
}

// Xuất mảng khoảng cách sang file CSV
function exportToCSV() {
    if (distanceHistory.length === 0) {
        showPopup("Không có dữ liệu khoảng cách để xuất!");
        return;
    }

    // Tạo nội dung CSV
    const csvContent = [
        "Timestamp,Distance (cm)", // Tiêu đề
        ...distanceHistory.map((entry) => `${entry.timestamp},${entry.distance}`)
    ].join("\n");

    // Tạo Blob và tải file
    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute("download", `distance_history_${formatTimestamp(new Date()).replace(/[: ]/g, "-")}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);

    showPopup("Đã xuất dữ liệu khoảng cách sang file CSV!");
}

// Đọc trạng thái thủ công
function readSavedState() {
    const savedState = localStorage.getItem('systemState');
    if (savedState) {
        const state = JSON.parse(savedState);
        showPopup(
            `Khoảng cách: ${state.distanceInput || 'Chưa thiết lập'} cm\n` +
            `Thời gian: ${state.timeInput || 'Chưa thiết lập'} giây`
        );
    } else {
        showPopup('Chưa có dữ liệu được lưu!');
    }
}

function downloadImage(blob, timestamp) {
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `image_${timestamp.replace(/[:/ ]/g, "-")}.jpg`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
    showPopup(`Đã tải ảnh: image_${timestamp.replace(/[:/ ]/g, "-")}.jpg`);
}

// Xử lý dữ liệu nhận từ WebSocket
socket.onmessage = function (event) {
    if (event.data instanceof Blob) {
        const timestamp = formatTimestamp(new Date());
        const imageUrl = URL.createObjectURL(event.data);
        latestImageBlob = event.data;
        document.getElementById("capturedImage").src = imageUrl;
        console.log("Updated capturedImage");
        downloadImage(latestImageBlob, timestamp);
    } else {
        const distance = parseInt(event.data);
        if (!isNaN(distance)) {
            document.getElementById("distance_now").textContent = distance;
            // Lưu khoảng cách vào mảng với timestamp
            distanceHistory.push({
                timestamp: formatTimestamp(new Date()),
                distance: distance
            });
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
        saveState();
        showPopup(`Khoảng cách cảnh báo: ${distanceInput} cm`);
    } else {
        showPopup('Vui lòng nhập giá trị khoảng cách hợp lệ!');
    }
});

// Thiết lập thời gian cảnh báo
document.getElementById('set_time_btn').addEventListener('click', () => {
    timeInput = parseFloat(document.getElementById('set_time').value);
    if (!isNaN(timeInput)) {
        saveState();
        showPopup(`Thời gian cảnh báo: ${timeInput} giây`);
    } else {
        showPopup('Vui lòng nhập giá trị thời gian hợp lệ!');
    }
});

// Reset trạng thái
document.getElementById('reset_btn').addEventListener('click', () => {
    localStorage.removeItem('systemState');
    distanceInput = 10;
    timeInput = 5;
    document.getElementById('set_distance').value = '';
    document.getElementById('set_time').value = '';
    showPopup('Đã đặt lại cài đặt!');
});

// Gắn sự kiện đọc trạng thái
document.getElementById('read_state_btn').addEventListener('click', readSavedState);

// Khôi phục trạng thái khi tải trang
window.addEventListener('load', () => {
    const savedState = localStorage.getItem('systemState');
    if (savedState) {
        const state = JSON.parse(savedState);
        distanceInput = state.distanceInput || 10;
        timeInput = state.timeInput || 5;
        document.getElementById('set_distance').value = distanceInput;
        document.getElementById('set_time').value = timeInput;
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
document.getElementById('capture_btn').addEventListener('click', async () => {
    isStreaming = false;
    if (socket.readyState === WebSocket.OPEN) {
        socket.send("CAPTURE");
        document.getElementById("imageModal").style.display = "block";
        console.log("Sent CAPTURE command");
        await new Promise(resolve => setTimeout(resolve, 3000));
    } else {
        console.error("WebSocket not connected, cannot send CAPTURE!");
    }
});

// Đóng modal khi nhấn 'X'
document.querySelectorAll(".close").forEach((btn) => {
    btn.addEventListener("click", () => btn.parentElement.parentElement.style.display = "none");
});

// Xuất dữ liệu khoảng cách
document.getElementById('export_btn').addEventListener('click', () => {
    exportToCSV();
});

// Xuất dữ liệu khi đóng trang
window.addEventListener('beforeunload', () => {
    exportToCSV();
});