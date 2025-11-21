let player = null;
let playerReady = false;
let pendingVideoId = null;

// Called by YouTube IFrame API
function onYouTubeIframeAPIReady() {
    player = new YT.Player('player', {
        width: '1920',
        height: '1080',
        playerVars: {
            autoplay: 1,
            controls: 0,
            rel: 0,
            modestbranding: 1,
            showinfo: 0,
            iv_load_policy: 3,
            fs: 0,
            disablekb: 1
        },
        events: {
            onReady: onPlayerReady
        }
    });
}

function onPlayerReady() {
    playerReady = true;

    // If Lua already requested a video before API was ready
    if (pendingVideoId) {
        playVideoById(pendingVideoId);
        pendingVideoId = null;
    }
}

function playVideoById(videoId) {
    if (!playerReady || !player) {
        pendingVideoId = videoId;
        return;
    }
    player.loadVideoById(videoId);
    player.unMute();
}

function stopVideo() {
    if (player && playerReady) {
        player.stopVideo();
    }
}

function setVolume(vol) {
    if (!playerReady || !player) return;

    // Clamp 0 - 100
    vol = Math.max(0, Math.min(100, vol));

    player.setVolume(vol);
    if (vol <= 0) {
        player.mute();
    } else {
        player.unMute();
    }
}

// Message handler from Lua (SendDuiMessage)
window.addEventListener('message', function (event) {
    let data = null;
    try {
        data = JSON.parse(event.data);
    } catch (e) {
        return;
    }

    if (!data || !data.action) return;

    switch (data.action) {
        case 'play':
            if (data.videoId) {
                playVideoById(data.videoId);
            }
            break;

        case 'stop':
            stopVideo();
            break;

        case 'setVolume':
            if (typeof data.value === 'number') {
                setVolume(data.value);
            }
            break;
    }
});
