const state = {
  notes: [],
  selectedNoteId: null,
  filters: {
    search: "",
    tag: "",
    includeArchived: false
  }
};

const elements = {
  notesHeading: document.querySelector("#notes-heading"),
  notesList: document.querySelector("#notes-list"),
  tagCloud: document.querySelector("#tag-cloud"),
  statusLine: document.querySelector("#status-line"),
  editorHeading: document.querySelector("#editor-heading"),
  titleInput: document.querySelector("#title-input"),
  tagsInput: document.querySelector("#tags-input"),
  bodyInput: document.querySelector("#body-input"),
  saveButton: document.querySelector("#save-button"),
  archiveButton: document.querySelector("#archive-button"),
  deleteButton: document.querySelector("#delete-button"),
  newNoteButton: document.querySelector("#new-note-button"),
  refreshButton: document.querySelector("#refresh-button"),
  filtersForm: document.querySelector("#filters"),
  searchInput: document.querySelector("#search-input"),
  tagInput: document.querySelector("#tag-input"),
  archivedInput: document.querySelector("#archived-input"),
  noteForm: document.querySelector("#note-form")
};

async function request(path, options = {}) {
  return graphql(path, options);
}

async function graphql(query, variables = {}) {
  const response = await fetch("/graphql", {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      query,
      variables
    })
  });

  const payload = await response.json();

  if (!response.ok || payload.errors?.length) {
    const detail = payload?.errors?.[0]?.message || "Request failed";
    throw new Error(detail);
  }

  return payload.data;
}

async function loadNotes() {
  setStatus("Loading notes…");

  const payload = await request(
    `
      query Notes($search: String, $tag: String, $includeArchived: Boolean) {
        notes(search: $search, tag: $tag, includeArchived: $includeArchived) {
          id
          title
          body
          tags
          archived
          created
          modified
        }
      }
    `,
    {
      search: state.filters.search || null,
      tag: state.filters.tag || null,
      includeArchived: state.filters.includeArchived
    }
  );

  state.notes = payload.notes;

  if (!state.notes.find((note) => note.id === state.selectedNoteId)) {
    state.selectedNoteId = state.notes[0]?.id || null;
  }

  renderNotes();
  renderEditor();
  setStatus(state.selectedNoteId ? "Note loaded." : "No note selected.");
}

async function loadTags() {
  const payload = await request(
    `
      query {
        tags {
          tag
          count
        }
      }
    `
  );

  const entries = payload.tags
    .map(({ tag, count }) => [tag, count])
    .sort((left, right) => right[1] - left[1]);

  if (entries.length === 0) {
    elements.tagCloud.innerHTML = '<p class="empty-state">No tags yet.</p>';
    return;
  }

  elements.tagCloud.innerHTML = entries
    .map(([tag, count]) => `
      <button class="chip" type="button" data-tag="${escapeHtml(tag)}">
        <span>${escapeHtml(tag)}</span>
        <strong>${count}</strong>
      </button>
    `)
    .join("");

  elements.tagCloud.querySelectorAll("[data-tag]").forEach((button) => {
    button.addEventListener("click", () => {
      elements.tagInput.value = button.dataset.tag;
      state.filters.tag = button.dataset.tag;
      refresh();
    });
  });
}

function renderNotes() {
  elements.notesHeading.textContent = state.filters.search || state.filters.tag ? "Filtered notes" : "Recent notes";

  if (state.notes.length === 0) {
    elements.notesList.innerHTML = '<p class="empty-state">No notes match the current filter.</p>';
    return;
  }

  elements.notesList.innerHTML = state.notes
    .map((note) => {
      const preview = note.body.trim().replace(/\s+/g, " ").slice(0, 120) || "No content yet.";
      const tags = note.tags.slice(0, 3).map((tag) => `<span class="chip">${escapeHtml(tag)}</span>`).join("");

      return `
        <article class="note-card ${note.id === state.selectedNoteId ? "active" : ""}" data-note-id="${note.id}">
          <h3>${escapeHtml(note.title || "Untitled")}</h3>
          <p>${escapeHtml(preview)}</p>
          <div class="note-meta">
            ${tags}
            ${note.archived ? '<span class="chip">archived</span>' : ""}
          </div>
        </article>
      `;
    })
    .join("");

  elements.notesList.querySelectorAll("[data-note-id]").forEach((card) => {
    card.addEventListener("click", () => {
      state.selectedNoteId = card.dataset.noteId;
      renderNotes();
      renderEditor();
    });
  });
}

function renderEditor() {
  const note = getSelectedNote();
  const editable = Boolean(note);

  elements.titleInput.disabled = !editable;
  elements.tagsInput.disabled = !editable;
  elements.bodyInput.disabled = !editable;
  elements.saveButton.disabled = !editable;
  elements.archiveButton.disabled = !editable;
  elements.deleteButton.disabled = !editable;

  if (!note) {
    elements.editorHeading.textContent = "Select a note";
    elements.titleInput.value = "";
    elements.tagsInput.value = "";
    elements.bodyInput.value = "";
    elements.archiveButton.textContent = "Archive";
    return;
  }

  elements.editorHeading.textContent = note.title || "Untitled";
  elements.titleInput.value = note.title || "";
  elements.tagsInput.value = note.tags.join(", ");
  elements.bodyInput.value = note.body || "";
  elements.archiveButton.textContent = note.archived ? "Unarchive" : "Archive";
}

async function createNote() {
  setStatus("Creating note…");
  const payload = await request(
    `
      mutation {
        createNote(title: "Untitled note", body: "", tags: []) {
          id
        }
      }
    `
  );

  state.selectedNoteId = payload.createNote.id;
  await refresh();
  elements.titleInput.focus();
  elements.titleInput.select();
  setStatus("New note created.");
}

async function saveNote(event) {
  event.preventDefault();

  const note = getSelectedNote();

  if (!note) {
    return;
  }

  setStatus("Saving note…");

  const updated = await request(
    `
      mutation UpdateNote($id: ID!, $title: String, $body: String, $archived: Boolean) {
        updateNote(id: $id, title: $title, body: $body, archived: $archived) {
          id
        }
      }
    `,
    {
      id: note.id,
      title: elements.titleInput.value.trim() || "Untitled",
      body: elements.bodyInput.value,
      archived: note.archived
    }
  );

  const currentTags = note.tags.join(", ");
  const newTags = elements.tagsInput.value.trim();

  if (newTags !== currentTags) {
    await syncTags(updated.updateNote.id, note.tags, parseTags(newTags));
  }

  await refresh();
  state.selectedNoteId = updated.updateNote.id;
  setStatus("Note saved.");
}

async function syncTags(noteId, oldTags, newTags) {
  const toAdd = newTags.filter((tag) => !oldTags.includes(tag));
  const toRemove = oldTags.filter((tag) => !newTags.includes(tag));

  if (toAdd.length > 0) {
    await request(
      `
        mutation AddTags($id: ID!, $tags: [String!]!) {
          addTags(id: $id, tags: $tags) { id }
        }
      `,
      { id: noteId, tags: toAdd }
    );
  }

  if (toRemove.length > 0) {
    await request(
      `
        mutation RemoveTags($id: ID!, $tags: [String!]!) {
          removeTags(id: $id, tags: $tags) { id }
        }
      `,
      { id: noteId, tags: toRemove }
    );
  }
}

async function toggleArchive() {
  const note = getSelectedNote();

  if (!note) {
    return;
  }

  setStatus(note.archived ? "Restoring note…" : "Archiving note…");

  await request(
    `
      mutation ToggleArchive($id: ID!, $archived: Boolean) {
        updateNote(id: $id, archived: $archived) { id }
      }
    `,
    {
      id: note.id,
      archived: !note.archived
    }
  );

  await refresh();
  setStatus(note.archived ? "Note restored." : "Note archived.");
}

async function deleteNote() {
  const note = getSelectedNote();

  if (!note) {
    return;
  }

  const confirmed = window.confirm(`Delete "${note.title || "Untitled"}"?`);

  if (!confirmed) {
    return;
  }

  setStatus("Deleting note…");
  await request(
    `
      mutation DeleteNote($id: ID!) {
        deleteNote(id: $id)
      }
    `,
    {
      id: note.id
    }
  );
  state.selectedNoteId = null;
  await refresh();
  setStatus("Note deleted.");
}

function getSelectedNote() {
  return state.notes.find((note) => note.id === state.selectedNoteId) || null;
}

function parseTags(input) {
  return input
    .split(",")
    .map((tag) => tag.trim())
    .filter(Boolean)
    .filter((tag, index, array) => array.indexOf(tag) === index);
}

function setStatus(message) {
  elements.statusLine.textContent = message;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

async function refresh() {
  await Promise.all([loadNotes(), loadTags()]);
}

elements.newNoteButton.addEventListener("click", () => {
  createNote().catch(handleError);
});

elements.refreshButton.addEventListener("click", () => {
  refresh().catch(handleError);
});

elements.noteForm.addEventListener("submit", (event) => {
  saveNote(event).catch(handleError);
});

elements.archiveButton.addEventListener("click", () => {
  toggleArchive().catch(handleError);
});

elements.deleteButton.addEventListener("click", () => {
  deleteNote().catch(handleError);
});

elements.filtersForm.addEventListener("input", () => {
  state.filters.search = elements.searchInput.value.trim();
  state.filters.tag = elements.tagInput.value.trim();
  state.filters.includeArchived = elements.archivedInput.checked;
  refresh().catch(handleError);
});

function handleError(error) {
  console.error(error);
  setStatus(error.message || "Request failed.");
}

refresh().catch(handleError);
