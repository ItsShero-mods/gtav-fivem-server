function setUpNotesApp(data) {
    $(".phone-app").hide();
    $(".app-notes").show();

    $(".notes-home").show();
    $(".opened-note").hide();

    const list = $(".notes-list");
    list.empty();

    if (!data || data.length === 0) {
        console.log("No notes yet")
        list.append('<div class="notes-empty">No notes yet</div>');
        $("#notes-header-count").text("0 Notes");
        return;
    }

    $("#notes-header-count").text(`${data.length} Notes`);

    data.forEach(note => {
        const item = $(`
            <div class="note-item" data-id="${note.id}">
                <div class="note-item-title">${note.title || "Untitled"}</div>
                <div class="note-item-preview">${(note.content || "").slice(0, 50)}</div>
            </div>
        `);

        item.on("click", function() {
            openNote(note);
        });

        list.append(item);
    });
}

function openNote(note) {
    $(".notes-home").hide();
    $(".opened-note").show();

    $("#note-title-input").val(note.title || "");
    $("#note-content-input").val(note.content || "");
    window.currentNote = note;
}

function createNewNote() {
    $(".notes-home").hide();
    $(".opened-note").show();

    $("#note-title-input").val("");
    $("#note-content-input").val("");

    // Store an internal state if you want (e.g., editing vs creating)
    window.currentNote = null;

    console.log("Opened editor for new note");
}

function refreshNotes() {
    console.log("Refreshing notes...");
    $.post("https://qb-phone/GetNotes", JSON.stringify({}), function (data) {
        console.log("GetNotes returned:", data);
        setUpNotesApp(data);
    });
}


$(document).on("click", "#save-note", function () {
    const noteData = {
        id: window.currentNote ? window.currentNote.id : null,
        title: $("#note-title-input").val().trim(),
        content: $("#note-content-input").val().trim(),
    };

    console.log("Saving note:", noteData);

    $.post("https://qb-phone/SaveNote", JSON.stringify(noteData), function () {
        console.log("Note saved");
        // Refresh notes list after saving
        setTimeout(() => {
            refreshNotes();
            $(".opened-note").hide();
            $(".notes-home").show();
        }, 250);
    });


});

$(document).on("click", "#note-back", function () {
    refreshNotes();
    $(".opened-note").hide();
    $(".notes-home").show();
});

$(document).on("click", "#delete-note", function () {
    console.log("Note delete entered");
    if (!currentNote || !currentNote.id) {
        console.log("No note selected to delete");
        // For a brand new unsaved note, just go back
        $(".opened-note").hide();
        $(".notes-home").show();
        return;
    }

    const payload = { id: currentNote.id };

    console.log("Deleting note:", payload);

    $.post("https://qb-phone/DeleteNote", JSON.stringify(payload), function () {
        // After delete, refresh notes list
        setTimeout(() => {
            refreshNotes();
            $(".opened-note").hide();
            $(".notes-home").show();
        }, 250);
    });
    
    currentNote = null;
});