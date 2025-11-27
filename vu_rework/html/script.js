let sequence = [];
let index = 0;
let timerDuration = 0;
let timerStart = 0;
let timerInterval = null;

window.addEventListener("message", (event) => {
    let data = event.data;
    if (data.action === "showChallenge") {
        sequence = data.sequence;
        index = 0;

        document.getElementById("sequence").innerHTML =
            sequence.map((k, i) =>
                `<div class="key-box ${i < index ? 'active' : ''}">${k}</div>`
            ).join("");

        document.getElementById("challenge").style.display = "block";
        startTimer(data.timer);
    }

    if (data.action === "hideChallenge") {
        stopTimer();
        document.getElementById("challenge").style.display = "none";
    }
});

// Handle keypresses from the browser window
document.addEventListener("keydown", (e) => {
    if (!sequence.length) return;

    let key = e.key.toUpperCase();

    if (key === sequence[index]) {
        playLockSound();
        index++;

        if (index >= sequence.length) {
            fetch(`https://${GetParentResourceName()}/finishSequence`, {
                method: "POST"
            });
            stopTimer();
            sequence = [];
 
            return;
        }

        document.getElementById("sequence").innerHTML =
            sequence.map((k, i) =>
                `<div class="key-box ${i < index ? 'active' : ''}">${k}</div>`
            ).join("");

    } else {
        fetch(`https://${GetParentResourceName()}/failSequence`, {
            method: "POST"
        });
        stopTimer();
        sequence = [];
    }
});

function playLockSound() {
    const audio = new Audio("sounds/lock.ogg");
    audio.volume = 0.25; // adjust volume
    audio.play();
}


function startTimer(ms) {
    timerDuration = ms;
    timerStart = performance.now();

    const bar = document.getElementById("timerBar");
    bar.style.width = "100%";

    if (timerInterval) clearInterval(timerInterval);

    timerInterval = setInterval(() => {
        let elapsed = performance.now() - timerStart;
        let pct = Math.max(0, 1 - (elapsed / timerDuration));

        bar.style.width = (pct * 100) + "%";

        if (pct <= 0) {
            clearInterval(timerInterval);
        }
    }, 50);
}

function stopTimer() {
    if (timerInterval) {
        clearInterval(timerInterval);
        timerInterval = null;
    }
}