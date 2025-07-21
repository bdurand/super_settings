(function() {
  // Return the card element for a setting.
  function findSettingCard(id) {
    if (id) {
      return document.querySelector('#settings-container .super-settings-card[data-id="' + id + '"]');
    } else {
      return null;
    }
  }

  // Return the number of settings that have been edited.
  function changesCount() {
    return document.querySelectorAll("#settings-container .super-settings-card[data-edited=true]").length;
  }

  // Set the enabled status of the save button for submitting the form.
  function enableSaveButton() {
    const saveButton = document.querySelector("#super-settings-save-settings");
    const discardButton = document.querySelector("#super-settings-discard-changes");
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
        element.innerText = dateFormatter().format(datetime);
      } catch (e) {
        element.innerText = "" + setting.value
      }
    } else {
      element.innerText = "" + setting.value
    }
  }

  // Get the value of a setting from the edit form field.
  function getSettingEditValue(card) {
    if (card.querySelector(".super-settings-card-value input.js-setting-value[type=checkbox]")) {
      return card.querySelector(".super-settings-card-value input.js-setting-value[type=checkbox]").checked;
    } else {
      return card.querySelector(".super-settings-card-value .js-setting-value").value;
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

  // Create a card element for displaying a setting.
  function settingCard(setting) {
    const card = elementFromSettingTemplate(setting, "#setting-card-template");
    card.dataset.id = setting.id
    card.dataset.key = setting.key
    card.querySelector(".js-setting-key").value = setting.key;
    if (setting.deleted) {
      card.dataset.edited = true
      card.dataset.deleted = true
      card.querySelector(".js-setting-deleted").value = "1";
    }
    if (setting.key !== null && setting.key !== undefined) {
      card.querySelector(".super-settings-card-key .js-value-placeholder").innerText = setting.key;
    }
    if (setting.value !== null && setting.value !== undefined) {
      setSettingDisplayValue(card.querySelector(".super-settings-card-value .js-value-placeholder"), setting);
    }
    if (setting.value_type !== null && setting.value_type !== undefined) {
      card.querySelector(".super-settings-card-type .js-value-placeholder").innerText = setting.value_type;
    }
    if (setting.description !== null && setting.description !== undefined) {
      card.querySelector(".super-settings-card-description .js-value-placeholder").innerHTML = escapeHTML(setting.description).replaceAll("\n", "<br>");
    }
    if (setting.updated_at !== null && setting.updated_at !== undefined) {
      const lastModified = new Date(Date.parse(setting.updated_at));
      const lastModifiedFormatter = new Intl.DateTimeFormat(navigator.language, {month: "short", day: "numeric",  year: "numeric"});
      const lastModifiedString = lastModifiedFormatter.format(lastModified);
      const lastModifiedElement = card.querySelector(".super-settings-card-modified .js-value-placeholder")
      lastModifiedElement.innerText = lastModifiedString;
      lastModifiedElement.title = dateFormatter().format(lastModified);
    }

    return card
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
      try {
        const datetime = new Date(Date.parse(setting.value));
        const isoDate = `${datetime.getFullYear()}-${padTimeVal(datetime.getMonth() + 1)}-${padTimeVal(datetime.getDate())}`;
        const isoTime = `${padTimeVal(datetime.getHours())}:${padTimeVal(datetime.getMinutes())}:${padTimeVal(datetime.getSeconds())}`;
        element.querySelector('input[type="date"]').value = isoDate;
        element.querySelector('input[type="time"]').value = isoTime;
        element.querySelector(".js-setting-value").value = datetime.toUTCString().replace("GMT", "UTC");
      } catch(e) {
        // ignore bad date format
      }
    } else if (setting.value_type === "integer") {
      element.value = "" + parseInt("" + setting.value, 10);
    } else if (setting.value_type === "float") {
      element.value = "" + parseFloat("" + setting.value);
    } else {
      element.value = setting.value;
    }

    return element;
  }

  // Create a card with form elements for editing a setting.
  function editSettingCard(setting) {
    const card = elementFromSettingTemplate(setting, "#setting-card-edit-template");
    card.dataset.id = setting.id
    card.dataset.key = setting.key

    card.querySelector(".super-settings-card-key input").value = setting.key;
    if (setting.description) {
      card.querySelector(".super-settings-card-description textarea").value = setting.description;
    }

    const valueInput = valueInputElement(setting);
    const valuePlaceholder = card.querySelector(".super-settings-card-value .js-value-placeholder");
    valuePlaceholder.innerHTML = "";
    valuePlaceholder.appendChild(valueInput);

    const valueType = card.querySelector(".super-settings-card-type select");
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
      card.querySelector(".js-setting-errors").innerHTML = errorsHTML;
    }

    if (setting.new_record) {
      card.dataset.newrecord = "true";
    }

    const timezone = card.querySelector(".timezone");
    if (timezone) {
      tzName = Intl.DateTimeFormat().resolvedOptions().timeZone;
      timezone.innerText = tzName;
    }

    return card
  }

  // Create a card with form elements for creating a new setting.
  function newSettingCard(key, valueType) {
    if (!key) {
      key = "";
    }
    if (!valueType) {
      valueType = "string";
    }
    const randomId = "new" + Math.floor((Math.random() * 0xFFFFFFFFFFFFFF)).toString(16);
    const setting = {id: randomId, key: key, value: "", value_type: valueType, new_record: true}
    card = editSettingCard(setting);
    return card;
  }

  // Add a setting card to the container of settings.
  function addCardToContainer(card) {
    const existingCard = findSettingCard(card.dataset.id);
    if (existingCard) {
      existingCard.replaceWith(card);
    } else {
      document.querySelector("#settings-container").prepend(card);
    }
    bindSettingControlEvents(card);
    filterSettings(document.querySelector("#super-settings-filter").value);
    card.scrollIntoView({block: "nearest"});
    enableSaveButton();
    return card;
  }

  // Update the filter URL and settings count display.
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

  // Update the settings count display.
  function updateSettingsCount(count) {
    document.querySelector(".js-settings-count").textContent = `${count} ${count === 1 ? "Setting" : "Settings"}`;
  }

  // Apply the given filter to only show settings that have a key, value, or description
  // that includes the filter text. Settings that are currently being edited will also be shown.
  function filterSettings(filterText) {
    const filters = [];
    filterText.split(" ").forEach(function(filter) {
      filter = filter.toUpperCase();
      filters.push(function(card) {
        let text = "";
        const settingKey = card.querySelector(".super-settings-card-key");
        if (settingKey) {
          text += " " + settingKey.textContent.toUpperCase();
        }
        const settingValue = card.querySelector(".super-settings-card-value");
        if (settingValue) {
          text += " " + settingValue.textContent.toUpperCase();
        }
        const settingDescription = card.querySelector(".super-settings-card-description");
        if (settingDescription) {
          text += " " + settingDescription.textContent.toUpperCase();
        }
        return (text.indexOf(filter) > -1);
      });
    });

    let visibleCount = 0;
    document.querySelectorAll("#settings-container .super-settings-card").forEach(function(card) {
      let matched = true;
      if (!card.dataset.edited) {
        filters.forEach(function(filter) {
          matched = matched && filter(card);
        });
      }
      if (matched) {
        card.style.display = "";
        visibleCount++;
      } else {
        card.style.display = "none";
      }
    });

    updateFilterURL(filterText);
    updateSettingsCount(visibleCount);
  }

  // Programatically apply the filter again to keep it up to date with other changes.
  function applyFilter(value) {
    const filter = document.querySelector("#super-settings-filter");
    if (filter) {
      if (value) {
        filter.value = value;
      }
    }
  }

  // Display validation errors on settings form.
  function showValidationErrors(errors) {
    const container = document.querySelector("#settings-container");
    Object.keys(errors).forEach(function(key) {
      container.querySelectorAll(".super-settings-card-edit").forEach(function(card) {
        const settingKey = card.querySelector(".js-setting-key");
        if (settingKey && settingKey.value === key) {
          const errorsElement = card.querySelector(".js-setting-errors");
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
      flash.classList.add("super-settings-text-success");
      flash.classList.remove("super-settings-text-danger");
    } else {
      flash.classList.add("tsuper-settings-ext-danger");
      flash.classList.remove("super-settings-text-success");
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

  function dateFormatter() {
    return new Intl.DateTimeFormat(navigator.language, {
      month: "short",
      day: "numeric",
      year: "numeric",
      hour: "numeric",
      minute: "numeric",
      second: "numeric",
      timeZoneName: "short"
    });
  }
  // Render a setting's history in a table.
  function renderHistoryTable(parent, payload) {
    parent.innerHTML = document.querySelector("#setting-history-table").innerHTML.trim();
    parent.querySelector(".super-settings-history-key").innerText = payload.key;
    const historyItems = parent.querySelector("#super-settings-history");
    let itemsHTML = "";
    payload.histories.forEach(function(history) {
      const date = new Date(Date.parse(history.created_at));
      const dateString = dateFormatter().format(date);
      const value = (history.deleted ? '<em class="super-settings-text-danger">deleted</em>' : escapeHTML(history.value));
      itemsHTML += `<div class="super-settings-history-item">
        <div class="super-settings-history-time">${escapeHTML(dateString)}</div>
        <div class="super-settings-history-user">${escapeHTML(history.changed_by)}</div>
        <div class="super-settings-history-value">${value}</div>
      </div>`;
    });
    historyItems.insertAdjacentHTML("beforeend", itemsHTML);

    if (payload.previous_page_params || payload.next_page_params) {
      let paginationHTML = `<div class="super-settings-align-center">`;
      if (payload.previous_page_params) {
        paginationHTML += `<div style="float:left;"><a href="#" class="js-show-history" title="Newer" data-offset="${payload.previous_page_params.offset}" data-limit="${payload.previous_page_params.limit}" data-key="${payload.previous_page_params.key}")>&#8592; Newer</a></div>`;
      }
      if (payload.next_page_params) {
        paginationHTML += `<div style="float:right;"><a href="#" class="js-show-history" title="Older" data-offset="${payload.next_page_params.offset}" data-limit="${payload.next_page_params.limit}" data-key="${payload.next_page_params.key}")>Older &#8594;</a></div>`;
      }
      paginationHTML += '<div style="clear:both;"></div>';
      parent.querySelector(".super-settings-history-container").insertAdjacentHTML("afterend", paginationHTML);
    }
    addListener(parent.querySelectorAll(".js-show-history"), "click", showHistoryModal);
  }

  // Show a modal window overlayed on the page.
  function showModal() {
    const modal = document.querySelector("#super-settings-modal");
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
    const modal = document.querySelector("#super-settings-modal");
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

  // Find a setting by key.
  function findSettingByKey(key) {
    let found = null;
    activeSettings.forEach(function(setting) {
      if (setting.key === key) {
        found = setting;
        return;
      }
    });
    return found;
  }

  // Add a new setting.
  function addSetting(key, valueType) {
    const card = addCardToContainer(newSettingCard(key, valueType));
    card.querySelector(".super-settings-card-key input").focus();
  }

  function editSetting(setting) {
    const card = addCardToContainer(editSettingCard(setting));
    if (card.querySelector(".super-settings-card-value .js-date-input")) {
      card.querySelector(".super-settings-card-value .js-date-input").focus();
    } else {
      card.querySelector(".super-settings-card-value .js-setting-value").focus();
    }
  }

  /*** Event Listeners ***/

  // Listener for showing the setting history modal.
  function showHistoryModal(event) {
    event.preventDefault();
    if (!event.target.dataset) {
      return;
    }

    const modal = document.querySelector("#super-settings-modal");
    const content = document.querySelector(".super-settings-modal-content");
    let key = event.target.dataset.key;
    if (!key) {
      const card = event.target.closest(".super-settings-card");
      if (card) {
        const id = card.dataset.id;
        const setting = findSetting(id);
        if (setting) {
          key = setting.key;
          if (!key) {
            return;
          }
        }
      }
    }
    const params = {key: key, limit: 25};
    if (event.target.dataset.limit) {
      params["limit"] = event.target.dataset.limit;
    }
    if (event.target.dataset.offset) {
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
    const card = event.target.closest(".super-settings-card");
    const valueType = event.target.options[event.target.selectedIndex].value;
    var setting = {
      id: card.dataset.id,
      key: card.querySelector(".super-settings-card-key input").value,
      value: getSettingEditValue(card),
      value_type: valueType,
      description: card.querySelector(".super-settings-card-description textarea").value,
      new_record: card.dataset.newrecord
    }
    const addedCard = addCardToContainer(editSettingCard(setting));
    if (addedCard.querySelector(".super-settings-card-value .js-date-input")) {
      addedCard.querySelector(".super-settings-card-value .js-date-input").focus();
    } else {
      addedCard.querySelector(".super-settings-card-value .js-setting-value").focus();
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
    const date = new Date(Date.parse(dateValue + "T" + timeValue));
    parentNode.querySelector(".js-setting-value").value = date.toISOString();
  }

  // Listener for the add setting button.
  function addSettingListener(event) {
    event.preventDefault();
    addSetting();
  }

  // Listener for the edit setting button.
  function editSettingListener(event) {
    event.preventDefault();
    const id = event.target.closest(".super-settings-card").dataset.id;
    setting = findSetting(id);
    editSetting(setting);
  }

  // Listener for the restore setting button.
  function restoreSetting(event) {
    event.preventDefault();
    const card = event.target.closest(".super-settings-card");
    const id = card.dataset.id;
    const setting = findSetting(id);
    if (setting) {
      const newCard = settingCard(setting);
      bindSettingControlEvents(newCard);
      card.replaceWith(newCard);
    } else {
      card.remove();
    }
    enableSaveButton();
  }

  // Listener for the remove setting button.
  function removeSetting(event) {
    event.preventDefault();
    const settingCard = event.target.closest(".super-settings-card");
    if (settingCard.dataset["id"]) {
      settingCard.querySelector("input.js-setting-deleted").value = "1";
      settingCard.dataset.edited = true;
      settingCard.dataset.deleted = true;
      settingCard.querySelector(".js-remove-setting").style.display = "none";
      settingCard.querySelector(".js-restore-setting").style.display = "inline-block";
    } else {
      settingCard.remove();
    }
    enableSaveButton();
  }

  // Update the settings via the API.
  function updateSettings(event) {
    event.preventDefault();
    event.target.disabled = true;
    const settingsData = [];
    document.querySelectorAll("#settings-container .super-settings-card[data-edited=true]").forEach(function(card) {
      const data = {};
      settingsData.push(data);

      data.key = card.querySelector(".js-setting-key").value;
      if (data.key != card.dataset.key) {
        data.key_was = card.dataset.key;
      }

      const deleted = card.querySelector(".js-setting-deleted");
      if (deleted && deleted.value === "1") {
        data.deleted = true;
      } else {
        if (card.querySelector(".js-setting-value")) {
          data.value = getSettingEditValue(card);
        }
        if (card.querySelector(".js-setting-value-type")) {
          const valueTypeSelect = card.querySelector(".js-setting-value-type");
          data.value_type = valueTypeSelect.options[valueTypeSelect.selectedIndex].value;
        }
        if (card.querySelector(".super-settings-card-description textarea")) {
          data.description = card.querySelector(".super-settings-card-description textarea").value;
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
    const filter = document.querySelector("#super-settings-filter").value;
    if (filter !== "") {
      url += "?filter=" + escape(filter);
    }
    window.location = url;
  }

  // Parse URL hash looking for URL-style parameters like #edit=setting&type=string.
  function fetchURLHash() {
    const hash = window.location.hash;
    if (hash.length <= 1) {
      return {};
    }

    // Remove the # and check if it looks like URL parameters
    const hashParams = hash.substring(1);
    if (!hashParams.includes('=')) {
      return {};
    }

    const params = {};
    hashParams.split('&').forEach(function(param) {
      const [key, value] = param.split('=', 2);
      if (key && value) {
        params[decodeURIComponent(key)] = decodeURIComponent(value);
      }
    });

    window.location.hash = "";
    return params;
  }

  // Support integration into single page applications where OAuth2 access tokens are used.
  // The access token can be passed either in the access_token query parameter per the
  // OAuth2 standard, or in the URL hash. Passing it in the hash will prevent it from ever
  // being sent to the backend and is a bit more secure since there's no chance a web server
  // will accidentally log it with the request URL.
  function storeAccessToken() {
    let accessToken = null;
    const params = new URLSearchParams(window.location.search);
    if (params.get("access_token")) {
      accessToken = params.get("access_token");
    }
    if (window.location.hash.startsWith("#access_token=")) {
      accessToken = window.location.hash.replace("#access_token=", "");
    }
    if (accessToken) {
      window.sessionStorage.setItem("super_settings_access_token", accessToken);
      const params = new URLSearchParams(window.location.search);
      params.delete("access_token");
      window.location.hash = null;
      window.history.replaceState("", document.title, window.location.pathname + "?" + params.toString());
    }
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
    addListener(parent.querySelectorAll(".js-edit-setting"), "click", editSettingListener);
    addListener(parent.querySelectorAll(".js-restore-setting"), "click", restoreSetting);
    addListener(parent.querySelectorAll(".js-show-history"), "click", showHistoryModal);
    addListener(parent.querySelectorAll(".js-no-op"), "click", noOp);
    addListener(parent.querySelectorAll(".js-setting-value-type"), "change", changeSettingType);
    addListener(parent.querySelectorAll(".js-date-input"), "change", changeDateTime);
    addListener(parent.querySelectorAll(".js-time-input"), "change", changeDateTime);
  }

  // Initialize the container with all the settings plus any changes from a failed form submission.
  function renderSettingsContainer(settings) {
    const container = document.querySelector("#settings-container");
    container.innerHTML = "";
    let count = settings.length;

    sortSettings(settings).forEach(function(setting) {
      const randomId = "setting" + Math.floor((Math.random() * 0xFFFFFFFFFFFFF)).toString(16);
      setting.id = (setting.id || randomId);
      const card = settingCard(setting);
      container.appendChild(card);
      bindSettingControlEvents(card);
    });
    updateSettingsCount(count);

    const filter = document.querySelector("#super-settings-filter");
    if (filter) {
      filter.dispatchEvent(new Event("input"));
    }
  }

  function sortOrder() {
    const selectedSort = document.querySelector(".super-settings-sort-control[data-selected=true]");
    const field = selectedSort.dataset.field;
    const order = selectedSort.dataset.order;
    return {field: field, order: order};
  }

  // Sort settings by the selected sort option.
  function sortSettings(settings) {
    const sort = sortOrder();
    return settings.sort(function(a, b) {
      let aValue = a[sort.field];
      let bValue = b[sort.field];
      if (sort.field == "updated_at") {
        aValue = new Date(Date.parse(aValue));
        bValue = new Date(Date.parse(bValue));
      }

      if (aValue === bValue) {
        return 0;
      } else if (sort.order === "asc") {
        return (aValue < bValue) ? -1 : 1;
      } else {
        return (aValue > bValue) ? -1 : 1;
      }
    })
  }

  function setSortOrder(event) {
    event.preventDefault();

    const target = event.target.closest(".super-settings-sort-control");
    let prevSelection = document.querySelector(".super-settings-sort-control[data-selected=true]");

    if (prevSelection == target) {
      selectSortElement(prevSelection, false);
      target.querySelector(`[data-order=${target.dataset.order}]`).style.display = "none";
      target.dataset.order = (target.dataset.order === "asc" ? "desc" : "asc");
      target.querySelector(`[data-order=${target.dataset.order}]`).style.display = "inline-block";
    } else {
      selectSortElement(prevSelection, false);
    }

    selectSortElement(target, true);

    renderSettingsContainer(activeSettings);
  }

  function selectSortElement(element, selected) {
    element.dataset.selected = selected;

    const svg = element.querySelector(`[data-order=${element.dataset.order}]`).querySelector("svg");
    if (selected) {
      svg.style.backgroundColor = getComputedStyle(document.querySelector(".super-settings")).getPropertyValue("--primary-color");
      svg.style.fill = "white";
    } else {
      svg.style.backgroundColor = null;
      svg.style.fill = null;
    }
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

  function fetchActiveSettings(hashParams) {
    SuperSettingsAPI.fetchSettings(function(settings_hash) {
      const settings = settings_hash["settings"];
      activeSettings = settings;
      renderSettingsContainer(settings);
      if (hashParams && hashParams.edit) {
        const setting = findSettingByKey(hashParams.edit);
        if (setting) {
          editSetting(setting);
        } else {
          addSetting(hashParams.edit, hashParams.type);
        }
      }
      enableSaveButton();
    });
  }

  let activeSettings = [];

  docReady(function() {
    storeAccessToken();

    addListener(document.querySelector("#super-settings-filter"), "input", filterListener);
    addListener(document.querySelector("#super-settings-add-setting"), "click", addSettingListener);
    addListener(document.querySelector("#super-settings-discard-changes"), "click", refreshPage);
    addListener(document.querySelector("#super-settings-save-settings"), "click", updateSettings);
    addListener(document.querySelector("#super-settings-modal"), "click", closeModal);
    addListener(document.querySelectorAll(".super-settings-sort-control"), "click", setSortOrder);

    const hashParams = fetchURLHash();

    const queryParams = new URLSearchParams(window.location.search);
    applyFilter(queryParams.get("filter"));

    selectSortElement(document.querySelector(".super-settings-sort-control[data-selected=true]"), true);

    fetchActiveSettings(hashParams);

    window.onbeforeunload = promptUnsavedChanges;
  })
})();
