let sequence = [];
let index = 0;

window.addEventListener("message", (event) => {
    let data = event.data;

    if (data.action === "showChallenge") {
        sequence = data.sequence;
        index = 0;

        document.getElementById("sequence").innerHTML =
            sequence.map((k, i) =>
                `<span style="color:${i < index ? 'lime' : 'white'}">${k}</span>`
            ).join(" ");

        document.getElementById("challenge").style.display = "block";
    }

    if (data.action === "hideChallenge") {
        document.getElementById("challenge").style.display = "none";
    }
});

// Handle keypresses from the browser window
document.addEventListener("keydown", (e) => {
    if (!sequence.length) return;

    let key = e.key.toUpperCase();

    if (key === sequence[index]) {
        index++;

        if (index >= sequence.length) {
            fetch(`https://${GetParentResourceName()}/finishSequence`, {
                method: "POST"
            });

            sequence = [];
            return;
        }

        document.getElementById("sequence").innerHTML =
            sequence.map((k, i) =>
                `<span style="color:${i < index ? 'lime' : 'white'}">${k}</span>`
            ).join(" ");

    } else {
        fetch(`https://${GetParentResourceName()}/failSequence`, {
            method: "POST"
        });
        sequence = [];
    }
});
