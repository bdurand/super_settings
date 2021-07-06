(function() {
  // Return the table row element for a setting.
  function findSettingRow(id) {
    if (id) {
      return document.querySelector('#settings-table tr[data-id="' + id + '"]');
    } else {
      return null;
    }
  }

  // Return the number of settings that have been edited.
  function changesCount() {
    return document.querySelectorAll("#settings-table tbody tr[data-edited=true]").length;
  }

  // Set the enabled status of the save button for submitting the form.
  function enableSaveButton() {
    const saveButton = document.querySelector("#save-settings");
    const discardButton = document.querySelector("#discard-changes");
    if (saveButton) {
      const count = changesCount();
      const countSpan = saveButton.querySelector(".count");
      if (count === 0) {
        saveButton.disabled = true;
        countSpan.innerHTML = "";
        discardButton.disabled = true;
      } else {
        saveButton.disabled = false;
        countSpan.innerHTML = count;
        discardButton.disabled = false;
      }
    }
  }

  // Set the display value for a setting.
  function setSettingDisplayValue(element, setting) {
    if (setting.value === null || setting.value === undefined) {
      element.innerText = "";
    } else if (Array.isArray(setting.value)) {
      let arrayHTML = "";
      setting.value.map(function(val) {
        arrayHTML += `<div>${escapeHTML(val)}</div>`;
      });
      element.innerHTML = arrayHTML;
    } else if (setting.value_type === "datetime") {
      try {
        const datetime = new Date(Date.parse(setting.value));
        element.innerText = datetime.toUTCString().replace("GMT", "UTC");
      } catch (e) {
        element.innerText = "" + setting.value
      }
    } else if (setting.value_type === "secret") {
      let placeholder = "••••••••••••••••••••••••";
      if (!setting.encrypted) {
        placeholder += '<br><span class="text-danger">not encrypted</span>'
      }
      element.innerHTML = placeholder;
    } else {
      element.innerText = "" + setting.value
    }
  }

  // Get the value of a setting from the edit form field.
  function getSettingEditValue(row) {
    if (row.querySelector(".super-settings-value input.js-setting-value[type=checkbox]")) {
      return row.querySelector(".super-settings-value input.js-setting-value[type=checkbox]").checked;
    } else {
      return row.querySelector(".super-settings-value .js-setting-value").value;
    }
  }

  // Helper function to pad time values with a zero for making ISO-8601 date and time formats.
  function padTimeVal(val) {
    return ("" + val).padStart(2, "0");
  }

  // Escape special HTML characters in text.
  function escapeHTML(text) {
    if (text === null || text === undefined) {
      return "";
    }
    const htmlEscapes = {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#x27;', '/': '&#x2F;'};
    const htmlEscaper = /[&<>"'\/]/g;
    return ('' + text).replace(htmlEscaper, function(match) {
      return htmlEscapes[match];
    });
  }

  // Helper function for use with templates to replace the text {{id}} with a setting's id value.
  function mustacheSubstitute(html, setting) {
    return html.replaceAll("{{id}}", escapeHTML(setting.id));
  }

  // Extract a new DOM element from a <template> element on the page.
  function elementFromSettingTemplate(setting, templateSelector) {
    let html = document.querySelector(templateSelector).innerHTML;
    html = mustacheSubstitute(html, setting);
    const template = document.createElement('template');
    template.innerHTML = html.trim();
    return template.content.firstChild;
  }

  // Create a table row element for displaying a setting.
  function settingRow(setting) {
    const row = elementFromSettingTemplate(setting, "#setting-row-template");
    row.dataset.id = setting.id
    row.dataset.key = setting.key
    row.querySelector(".js-setting-key").value = setting.key;
    if (setting.deleted) {
      row.dataset.edited = true
      row.dataset.deleted = true
      row.querySelector(".js-setting-deleted").value = "1";
    }
    if (setting.key !== null && setting.key !== undefined) {
      row.querySelector(".super-settings-key .js-value-placeholder").innerText = setting.key;
    }
    if (setting.value !== null && setting.value !== undefined) {
      setSettingDisplayValue(row.querySelector(".super-settings-value .js-value-placeholder"), setting);
    }
    if (setting.value_type !== null && setting.value_type !== undefined) {
      row.querySelector(".super-settings-value-type .js-value-placeholder").innerText = setting.value_type;
    }
    if (setting.description !== null && setting.description !== undefined) {
      row.querySelector(".super-settings-description .js-value-placeholder").innerHTML = escapeHTML(setting.description).replaceAll("\n", "<br>");
    }

    return row
  }

  // Create an input element from a template depending on the value type.
  function createValueInputElement(setting) {
    let templateName = null;
    if (setting.value_type === "integer") {
      templateName = "#setting-value-field-integer-template";
    } else if (setting.value_type === "float") {
      templateName = "#setting-value-field-float-template";
    } else if (setting.value_type === "datetime") {
      templateName = "#setting-value-field-datetime-template";
    } else if (setting.value_type === "boolean") {
      templateName = "#setting-value-field-boolean-template";
    } else if (setting.value_type === "array") {
      templateName = "#setting-value-field-array-template";
    } else {
      templateName = "#setting-value-field-template";
    }
    const html = mustacheSubstitute(document.querySelector(templateName).innerHTML, setting);
    const template = document.createElement('template');
    template.innerHTML = html.trim();
    return template.content.firstChild;
  }

  // Create the elements needed to edit a setting value and set the element value.
  function valueInputElement(setting) {
    const element = createValueInputElement(setting);
    if (setting.value_type === "boolean") {
      const checked = (`${setting.value}` === "true" || parseInt(setting.value) > 0);
      const checkbox = element.querySelector('input[type="checkbox"]');
      checkbox.checked = checked;
    } else if (setting.value_type === "array") {
      if (Array.isArray(setting.value)) {
        element.value = setting.value.join("\n");
      } else {
        element.value = setting.value;
      }
    } else if (setting.value_type === "datetime") {
      const datetime = new Date(Date.parse(setting.value));
      const isoDate = `${datetime.getUTCFullYear()}-${padTimeVal(datetime.getUTCMonth() + 1)}-${padTimeVal(datetime.getUTCDate())}`;
      const isoTime = `${padTimeVal(datetime.getUTCHours())}:${padTimeVal(datetime.getUTCMinutes())}:${padTimeVal(datetime.getUTCSeconds())}`;
      element.querySelector('input[type="date"]').value = isoDate;
      element.querySelector('input[type="time"]').value = isoTime;
      element.querySelector(".js-setting-value").value = setting.value;
    } else {
      element.value = setting.value;
    }

    return element;
  }

  // Create a table row with form elements for editing a setting.
  function editSettingRow(setting) {
    const row = elementFromSettingTemplate(setting, "#setting-row-edit-template");
    row.dataset.id = setting.id

    row.querySelector(".super-settings-key input").value = setting.key;

    const valueInput = valueInputElement(setting);
    const valuePlaceholder = row.querySelector(".super-settings-value .js-value-placeholder");
    valuePlaceholder.innerHTML = "";
    valuePlaceholder.appendChild(valueInput);

    const valueType = row.querySelector(".super-settings-value-type select");
    for (let i = 0; i < valueType.options.length; i++) {
      if (valueType.options[i].value === setting.value_type) {
        valueType.selectedIndex = i;
        break;
      }
    }

    if (setting.errors && setting.errors.length > 0) {
      let errorsHTML = "";
      setting.errors.forEach(function(error) {
        errorsHTML += `<div>${escapeHTML(error)}</div>`
      });
      row.querySelector(".js-setting-errors").innerHTML = errorsHTML;
    }

    if (setting.new_record) {
      row.dataset.newrecord = "true";
    }

    return row
  }

  // Create a table row with form elements for creating a new setting.
  function newSettingRow() {
    const randomId = "new" + Math.floor((Math.random() * 0xFFFFFFFFFFFFFF)).toString(16);
    const setting = {id: randomId, key: "", value: "", value_type: "string", new_record: true}
    row = editSettingRow(setting);
    return row;
  }

  // Add a setting table row the table of settings.
  function addRowToTable(row) {
    const existingRow = findSettingRow(row.dataset.id);
    if (existingRow) {
      existingRow.replaceWith(row);
    } else {
      document.querySelector("#settings-table tbody").prepend(row);
    }
    bindSettingControlEvents(row);
    filterSettings(document.querySelector("#filter").value);
    row.scrollIntoView({block: "nearest"});
    enableSaveButton();
    return row;
  }

  // Update the window location URL to reflect the current filter text.
  function updateFilterURL(filter) {
    const queryParams = new URLSearchParams(window.location.search);
    if (filter === "") {
      queryParams.delete("filter");
    } else {
      queryParams.set("filter", filter);
    }
    if (queryParams.toString() !== "") {
      history.replaceState(null, null, "?" + queryParams.toString());
    } else {
      history.replaceState(null, null, window.location.pathname);
    }
  }

  // Apply the given filter to only show settings that have a key, value, or description
  // that includes the filter text. Settings that are currently being edited will also be shown.
  function filterSettings(filterText) {
    const filters = [];
    filterText.split(" ").forEach(function(filter) {
      filter = filter.toUpperCase();
      filters.push(function(tr) {
        let text = "";
        const settingKey = tr.querySelector(".super-settings-key");
        if (settingKey) {
          text += " " + settingKey.textContent.toUpperCase();
        }
        const settingValue = tr.querySelector(".super-settings-value");
        if (settingValue) {
          text += " " + settingValue.textContent.toUpperCase();
        }
        const settingDescription = tr.querySelector(".setting-description");
        if (settingDescription) {
          text += " " + settingDescription.textContent.toUpperCase();
        }
        return (text.indexOf(filter) > -1);
      });
    });

    document.querySelectorAll("#settings-table tbody tr").forEach(function(tr) {
      let matched = true;
      if (!tr.dataset.edited) {
        filters.forEach(function(filter) {
          matched = matched && filter(tr);
        });
      }
      if (matched) {
        tr.style.display = "table-row";
      } else {
        tr.style.display = "none";
      }
    });
  }

  // Programatically apply the filter again to keep it up to date with other changes.
  function applyFilter(value) {
    const filter = document.querySelector("#filter");
    if (filter) {
      if (value) {
        filter.value = value;
      }
      filter.dispatchEvent(new Event("input"));
    }
  }

  // Display validation errors on settings form.
  function showValidationErrors(errors) {
    const table = document.querySelector("#settings-table");
    Object.keys(errors).forEach(function(key) {
      table.querySelectorAll(".super-settings-edit-row").forEach(function(row) {
        if (row.querySelector(".js-setting-key")?.value === key) {
          const errorsElement = row.querySelector(".js-setting-errors");
          if (errorsElement) {
            errorsElement.innerText = errors[key].join("; ");
            errorsElement.style.display = "block";
          }
        }
      });
    });
  }

  // Show a temporary message to give the user feedback that an operation has succeeded or not.
  function showFlash(message, success) {
    const flash = document.querySelector(".js-flash");
    if (success) {
      flash.classList.add("text-success");
      flash.classList.remove("text-danger");
    } else {
      flash.classList.add("text-danger");
      flash.classList.remove("text-success");
    }
    flash.innerText = message;
    flash.style.display = "inline-block";
    dismissFlash();
  }

  // Automatically hide the flash message displaying the results of the last save operation.
  function dismissFlash() {
    if (document.querySelector(".js-flash")) {
      setTimeout(function(){
        document.querySelectorAll(".js-flash").forEach(function(element) {
          element.style.display = "none";
        });
      }, 3000);
    }
  }

  // Render a setting's history in a table.
  function renderHistoryTable(parent, payload) {
    parent.innerHTML = document.querySelector("#setting-history-table").innerHTML.trim();
    const tbody = parent.querySelector("tbody");
    let rowsHTML = "";
    payload.histories.forEach(function(history) {
      const date = (new Date(Date.parse(history.created_at))).toUTCString().replace("GMT", "UTC");
      rowsHTML += `<tr><td class="super-settings-text-nowrap">${escapeHTML(date)}</td><td>${escapeHTML(history.changed_by)}</td><td>${escapeHTML(history.value)}</td></tr>`;
    });
    tbody.insertAdjacentHTML("beforeend", rowsHTML);

    if (payload.previous_page_params || payload.next_page_params) {
      let paginationHTML = `<div class="align-center">`;
      if (payload.previous_page_params) {
        paginationHTML += `<div style="float:left;"><a href="#" class="js-show-history" title="Newer" data-offset="${payload.previous_page_params.offset}" data-limit="${payload.previous_page_params.limit}" data-key="${payload.previous_page_params.key}")>&#8592; Newer</a></div>`;
      }
      if (payload.next_page_params) {
        paginationHTML += `<div style="float:right;"><a href="#" class="js-show-history" title="Older" data-offset="${payload.next_page_params.offset}" data-limit="${payload.next_page_params.limit}" data-key="${payload.next_page_params.key}")>Older &#8594;</a></div>`;
      }
      paginationHTML += '<div style="clear:both;"></div>';
      parent.querySelector("table").insertAdjacentHTML("afterend", paginationHTML);
    }
    addListener(parent.querySelectorAll(".js-show-history"), "click", showHistoryModal);
  }

  // Show a modal window overlayed on the page.
  function showModal() {
    const modal = document.querySelector("#modal");
    const content = document.querySelector(".super-settings-modal-content");
    modal.style.display = "block";
    modal.setAttribute("aria-hidden", "false");
    modal.activator = document.activeElement;
    focusableElements(document).forEach(function(element) {
      if (!modal.contains(element)) {
        element.dataset.saveTabIndex = element.getAttribute("tabindex");
        element.setAttribute("tabindex", -1);
      }
    });
    document.querySelector("body").style.overflow = "hidden";
  }

  // Hide the modal window overlayed on the page.
  function hideModal() {
    const modal = document.querySelector("#modal");
    const content = document.querySelector(".super-settings-modal-content");
    modal.style.display = "none";
    modal.setAttribute("aria-hidden", "true");
    focusableElements(document).forEach(function(element) {
      const tabIndex = element.dataset.saveTabIndex;
      delete element.dataset.saveTabIndex;
      if (tabIndex) {
        element.setAttribute("tabindex", tabIndex);
      }
    });
    if (modal.activator) {
      modal.activator.focus();
      delete modal.activator;
    }
    content.innerHTML = "";
    document.querySelector("body").style.overflow = "visible";
  }

  // Returns a list of all focusable elements so that they can be set to not take the focus
  // when a modal is opened.
  function focusableElements(parent) {
    return parent.querySelectorAll("a[href], area[href], button, input:not([type=hidden]), select, textarea, iframe, [tabindex], [contentEditable=true]")
  }

  // Find a setting by key.
  function findSetting(id) {
    let found = null;
    id = "" + id;
    activeSettings.forEach(function(setting) {
      if ("" + setting.id === id) {
        found = setting;
        return;
      }
    });
    return found;
  }

  /*** Event Listeners ***/

  // Listener for showing the setting history modal.
  function showHistoryModal(event) {
    event.preventDefault();
    const modal = document.querySelector("#modal");
    const content = document.querySelector(".super-settings-modal-content");
    let key = event.target.dataset?.key;
    if (!key) {
      const id = event.target.closest("tr")?.dataset?.id;
      const setting = findSetting(id);
      key = setting?.key;
      if (!key) {
        return;
      }
    }
    const params = {key: key, limit: 25};
    if (event.target.dataset?.limit) {
      params["limit"] = event.target.dataset.limit;
    }
    if (event.target.dataset?.offset) {
      params["offset"] = event.target.dataset.offset;
    }
    SuperSettingsAPI.fetchHistory(params, function(settingHistory){
      renderHistoryTable(content, settingHistory);
      showModal();
    });
  }

  // Listener for closing the modal window overlay.
  function closeModal(event) {
    if (event.target.classList.contains("js-close-modal")) {
      event.preventDefault();
      hideModal();
    }
  }

  // Listener to just capture events.
  function noOp(event) {
    event.preventDefault();
  }

  // Listener for changing the setting value type select element. Different types will have
  // different input elements for the setting value.
  function changeSettingType(event) {
    event.preventDefault();
    const row = event.target.closest("tr");
    const valueType = event.target.options[event.target.selectedIndex].value;
    var setting = {
      id: row.dataset.id,
      key: row.querySelector(".super-settings-key input").value,
      value: getSettingEditValue(row),
      value_type: valueType,
      description: row.querySelector(".super-settings-description textarea").value,
      new_record: row.dataset.newrecord
    }
    const addedRow = addRowToTable(editSettingRow(setting));
    if (addedRow.querySelector(".super-settings-value .js-date-input")) {
      addedRow.querySelector(".super-settings-value .js-date-input").focus();
    } else {
      addedRow.querySelector(".super-settings-value .js-setting-value").focus();
    }
  }

  // Listener for date and time input elements the combine the values into a hidden datetime field.
  function changeDateTime(event) {
    const parentNode = event.target.closest("span")
    const dateValue = parentNode.querySelector(".js-date-input").value;
    let timeValue = parentNode.querySelector(".js-time-input").value;
    if (timeValue === "") {
      timeValue = "00:00:00";
    }
    parentNode.querySelector(".js-setting-value").value = `${dateValue}T${timeValue}Z`
  }

  // Listener for the add setting button.
  function addSetting(event) {
    event.preventDefault();
    const row = addRowToTable(newSettingRow());
    row.querySelector(".super-settings-key input").focus();
  }

  // Listener for the edit setting button.
  function editSetting(event) {
    event.preventDefault();
    const id = event.target.closest("tr").dataset.id;
    const setting = findSetting(id);
    const row = addRowToTable(editSettingRow(setting));
    if (row.querySelector(".super-settings-value .js-date-input")) {
      row.querySelector(".super-settings-value .js-date-input").focus();
    } else {
      row.querySelector(".super-settings-value .js-setting-value").focus();
    }
  }

  // Listener for the restore setting button.
  function restoreSetting(event) {
    event.preventDefault();
    const row = event.target.closest("tr");
    const id = row.dataset.id;
    const setting = findSetting(id);
    if (setting) {
      const newRow = settingRow(setting);
      bindSettingControlEvents(newRow);
      row.replaceWith(newRow);
    } else {
      row.remove();
    }
    enableSaveButton();
  }

  // Listener for the remove setting button.
  function removeSetting(event) {
    event.preventDefault();
    const settingRow = event.target.closest("tr");
    if (settingRow.dataset["id"]) {
      settingRow.querySelector("input.js-setting-deleted").value = "1";
      settingRow.dataset.edited = true;
      settingRow.dataset.deleted = true;
      settingRow.querySelector(".js-remove-setting").style.display = "none";
      settingRow.querySelector(".js-restore-setting").style.display = "inline-block";
    } else {
      settingRow.remove();
    }
    enableSaveButton();
  }

  // Update the settings via the API.
  function updateSettings(event) {
    event.preventDefault();
    event.target.disabled = true;
    const settingsData = [];
    document.querySelectorAll("#settings-table tbody tr[data-edited=true]").forEach(function(row) {
      const data = {};
      settingsData.push(data);
      data.key = row.querySelector(".js-setting-key").value;
      const deleted = row.querySelector(".js-setting-deleted");
      if (deleted && deleted.value === "1") {
        data.deleted = true;
      } else {
        if (row.querySelector(".js-setting-value")) {
          data.value = getSettingEditValue(row);
        }
        if (row.querySelector(".js-setting-value-type")) {
          const valueTypeSelect = row.querySelector(".js-setting-value-type");
          data.value_type = valueTypeSelect.options[valueTypeSelect.selectedIndex].value;
        }
        if (row.querySelector(".js-setting-description")) {
          data.description = row.querySelector(".js-setting-description").value;
        }
      }
    });

    SuperSettingsAPI.updateSettings({settings: settingsData}, function(results) {
      if (results.success) {
        fetchActiveSettings();
        showFlash("Settings saved", true)
      } else {
        event.target.disabled = false;
        showFlash("Failed to save settings", false)
        if (results.errors) {
          showValidationErrors(results.errors)
        }
      }
    });
  }

  // Listener for the filter input field.
  function filterListener(event) {
    const filter = event.target.value;
    filterSettings(filter);
    updateFilterURL(filter);
  }

  // Listener for refresh page button.
  function refreshPage(event) {
    event.preventDefault();
    let url = window.location.href.replace(/\?.*/, "");
    const filter = document.querySelector("#filter").value;
    if (filter !== "") {
      url += "?filter=" + escape(filter);
    }
    window.location = url;
  }

  // Attach event listener to one or more elements.
  function addListener(elements, event, handler) {
    if (elements.addEventListener) {
      elements = [elements];
    }
    elements.forEach(function(element) {
      if (element) {
        element.addEventListener(event, handler);
      }
    });
  }

  // Bind event listeners for setting controls on a setting table row.
  function bindSettingControlEvents(parent) {
    addListener(parent.querySelectorAll(".js-remove-setting"), "click", removeSetting);
    addListener(parent.querySelectorAll(".js-edit-setting"), "click", editSetting);
    addListener(parent.querySelectorAll(".js-restore-setting"), "click", restoreSetting);
    addListener(parent.querySelectorAll(".js-show-history"), "click", showHistoryModal);
    addListener(parent.querySelectorAll(".js-no-op"), "click", noOp);
    addListener(parent.querySelectorAll(".js-setting-value-type"), "change", changeSettingType);
    addListener(parent.querySelectorAll(".js-date-input"), "change", changeDateTime);
    addListener(parent.querySelectorAll(".js-time-input"), "change", changeDateTime);
  }

  // Initialize the table with all the settings plus any changes from a failed form submission.
  function renderSettingsTable(settings) {
    const tbody = document.querySelector("#settings-table tbody");
    tbody.innerHTML = "";
    let count = settings.length;
    settings.forEach(function(setting) {
      const randomId = "setting" + Math.floor((Math.random() * 0xFFFFFFFFFFFFFF)).toString(16);
      setting.id ||= randomId;
      const row = settingRow(setting);
      tbody.appendChild(row);
      bindSettingControlEvents(row);
    });
    document.querySelector(".js-settings-count").textContent = `${count} ${count === 1 ? "Setting" : "Settings"}`;
  }

  function promptUnsavedChanges(event) {
    if (changesCount() > 0) {
      return "Are you sure you want to leave?";
    } else {
      return undefined;
    }
  }

  // Run the supplied function when the document has been marked ready.
  function docReady(fn) {
    if (document.readyState === "complete" || document.readyState === "interactive") {
      setTimeout(fn, 1);
    } else {
      document.addEventListener("DOMContentLoaded", fn);
    }
  }

  function fetchActiveSettings() {
    SuperSettingsAPI.fetchSettings(function(settings_hash) {
      const settings = settings_hash["settings"];
      activeSettings = settings;
      renderSettingsTable(settings);
      enableSaveButton();
    });
  }

  let activeSettings = [];

  docReady(function() {
    addListener(document.querySelector("#filter"), "input", filterListener);
    addListener(document.querySelector("#add-setting"), "click", addSetting);
    addListener(document.querySelector("#discard-changes"), "click", refreshPage);
    addListener(document.querySelector("#save-settings"), "click", updateSettings);
    addListener(document.querySelector("#modal"), "click", closeModal);

    const queryParams = new URLSearchParams(window.location.search);
    applyFilter(queryParams.get("filter"));
    window.onbeforeunload = promptUnsavedChanges;

    fetchActiveSettings();
  })
})();
