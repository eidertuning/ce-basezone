let timerInterval;

function updateTimer(seconds) {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    document.getElementById('timer').textContent =
        `${minutes.toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}`;
}

function showTimer() {
    document.getElementById('timer-container').classList.remove('hidden');
}

function hideTimer() {
    document.getElementById('timer-container').classList.add('hidden');
}

window.addEventListener('message', (event) => {
    if (event.data.type === 'updateTimer') {
        clearInterval(timerInterval);
        if (event.data.time > 0) {
            showTimer();
            updateTimer(event.data.time);
            timerInterval = setInterval(() => {
                event.data.time--;
                if (event.data.time <= 0) {
                    hideTimer();
                    clearInterval(timerInterval);
                } else {
                    updateTimer(event.data.time);
                }
            }, 1000);
        } else {
            hideTimer();
        }
    }
});
