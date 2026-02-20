(function() {
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

  // Helper function to pad time values with a zero for making ISO-8601 date and time formats.
  function padTimeVal(val) {
    return ("" + val).padStart(2, "0");
  }

  // Support integration into single page applications where OAuth2 access tokens are used.
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
    }
  }

  // Create the type-specific value input element from a template.
  function createValueInput(valueType) {
    let templateId = "edit-value-string";
    if (valueType === "integer") {
      templateId = "edit-value-integer";
    } else if (valueType === "float") {
      templateId = "edit-value-float";
    } else if (valueType === "datetime") {
      templateId = "edit-value-datetime";
    } else if (valueType === "boolean") {
      templateId = "edit-value-boolean";
    } else if (valueType === "array") {
      templateId = "edit-value-array";
    }
    const html = document.querySelector("#" + templateId).innerHTML.trim();
    const template = document.createElement("template");
    template.innerHTML = html;
    return template.content.firstChild;
  }

  // Set the value on a type-specific input element.
  function setValueInput(element, valueType, value) {
    if (value === null || value === undefined) {
      return;
    }

    if (valueType === "boolean") {
      const checked = ("" + value === "true" || parseInt(value) > 0);
      element.querySelector('input[type="checkbox"]').checked = checked;
    } else if (valueType === "array") {
      if (Array.isArray(value)) {
        element.value = value.join("\n");
      } else {
        element.value = value;
      }
    } else if (valueType === "datetime") {
      try {
        const datetime = new Date(Date.parse(value));
        const isoDate = datetime.getFullYear() + "-" + padTimeVal(datetime.getMonth() + 1) + "-" + padTimeVal(datetime.getDate());
        const isoTime = padTimeVal(datetime.getHours()) + ":" + padTimeVal(datetime.getMinutes()) + ":" + padTimeVal(datetime.getSeconds());
        element.querySelector(".js-date-input").value = isoDate;
        element.querySelector(".js-time-input").value = isoTime;
        element.querySelector(".js-setting-value").value = datetime.toISOString();
      } catch(e) {
        // ignore bad date format
      }
    } else if (valueType === "integer") {
      element.value = "" + parseInt("" + value, 10);
    } else if (valueType === "float") {
      element.value = "" + parseFloat("" + value);
    } else {
      element.value = value;
    }
  }

  // Get the current value from the form.
  function getEditValue() {
    const container = document.querySelector("#super-settings-edit-value-container");
    const checkbox = container.querySelector('input[type="checkbox"].js-setting-value');
    if (checkbox) {
      return checkbox.checked;
    }
    const input = container.querySelector(".js-setting-value");
    return input ? input.value : "";
  }

  // Render the value input for the given type and optionally set its value.
  function renderValueInput(valueType, value) {
    const container = document.querySelector("#super-settings-edit-value-container");
    container.innerHTML = "";
    const input = createValueInput(valueType);
    container.appendChild(input);

    if (value !== undefined && value !== null) {
      setValueInput(input, valueType, value);
    }

    // Bind datetime change handlers
    const dateInput = container.querySelector(".js-date-input");
    const timeInput = container.querySelector(".js-time-input");
    if (dateInput) {
      dateInput.addEventListener("change", changeDateTime);
    }
    if (timeInput) {
      timeInput.addEventListener("change", changeDateTime);
    }

    // Set timezone display
    const timezone = container.querySelector(".js-timezone");
    if (timezone) {
      timezone.innerText = Intl.DateTimeFormat().resolvedOptions().timeZone;
    }
  }

  // Populate the form with a setting's data.
  function populateForm(setting) {
    document.querySelector("#super-settings-edit-key").value = setting.key || "";
    document.querySelector("#super-settings-edit-description").value = setting.description || "";

    const valueType = setting.value_type || "string";
    const typeSelect = document.querySelector("#super-settings-edit-value-type");
    for (var i = 0; i < typeSelect.options.length; i++) {
      if (typeSelect.options[i].value === valueType) {
        typeSelect.selectedIndex = i;
        break;
      }
    }

    renderValueInput(valueType, setting.value);
  }

  // Event handler for the type select changing.
  function changeValueType() {
    var valueType = document.querySelector("#super-settings-edit-value-type").value;
    var currentValue = getEditValue();
    renderValueInput(valueType, currentValue);
  }

  // Event handler combining date and time inputs into the hidden datetime field.
  function changeDateTime(event) {
    const parentNode = event.target.closest("span");
    const dateValue = parentNode.querySelector(".js-date-input").value;
    let timeValue = parentNode.querySelector(".js-time-input").value;
    if (timeValue === "") {
      timeValue = "00:00:00";
    }
    const date = new Date(Date.parse(dateValue + "T" + timeValue));
    parentNode.querySelector(".js-setting-value").value = date.toISOString();
  }

  // Show a temporary flash message.
  function showFlash(message, success) {
    const flash = document.querySelector("#super-settings-edit-flash");
    flash.className = success ? "super-settings-edit-flash-success" : "super-settings-edit-flash-error";
    flash.innerText = message;
    flash.style.display = "inline";
    setTimeout(function() {
      flash.style.display = "none";
    }, 3000);
  }

  // Show validation errors below the value field.
  function showErrors(errors) {
    const errorsEl = document.querySelector("#super-settings-edit-errors");
    if (errors && Object.keys(errors).length > 0) {
      const messages = [];
      Object.keys(errors).forEach(function(key) {
        errors[key].forEach(function(msg) {
          messages.push(escapeHTML(msg));
        });
      });
      errorsEl.innerHTML = messages.join("<br>");
      errorsEl.style.display = "block";
    }
  }

  // Clear validation errors.
  function clearErrors() {
    const errorsEl = document.querySelector("#super-settings-edit-errors");
    errorsEl.innerHTML = "";
    errorsEl.style.display = "none";
  }

  // Save the setting via the existing POST /settings API.
  function saveSetting() {
    clearErrors();
    const saveButton = document.querySelector("#super-settings-edit-save");
    saveButton.disabled = true;

    const key = document.querySelector("#super-settings-edit-key").value;
    const value = getEditValue();
    const valueType = document.querySelector("#super-settings-edit-value-type").value;
    const description = document.querySelector("#super-settings-edit-description").value;

    const settingData = {key: key, value: value, value_type: valueType, description: description};

    // If we're editing an existing setting and the key changed, track the original key.
    if (currentSettingKey && currentSettingKey !== key) {
      settingData.key_was = currentSettingKey;
    }

    SuperSettingsAPI.updateSettings({settings: [settingData]}, function(result) {
      saveButton.disabled = false;
      if (result.success) {
        currentSettingKey = key;
        showFlash("Setting saved", true);
      } else {
        showFlash("Failed to save setting", false);
        if (result.errors) {
          showErrors(result.errors);
        }
      }
    });
  }

  // Initialize the edit page.
  function initEditPage() {
    // Compute the API base URL by stripping /setting/edit from the current path.
    const wrapper = document.querySelector(".super-settings-edit");
    if (!wrapper.dataset.apiBaseUrl) {
      const baseUrl = window.location.pathname.replace(/\/setting\/edit\/?$/, "") || "/";
      wrapper.dataset.apiBaseUrl = baseUrl;
    }

    const params = new URLSearchParams(window.location.search);
    const key = params.get("key") || "";
    const valueType = params.get("value_type") || "string";
    const description = params.get("description") || "";

    if (key) {
      // Try to load the existing setting.
      SuperSettingsAPI.fetchSetting(key, function(setting) {
        // Setting exists: populate form with existing data.
        currentSettingKey = setting.key;
        populateForm(setting);
      }, function(status) {
        // Setting not found: show create form with defaults.
        populateForm({key: key, value_type: valueType, description: description, value: ""});
      });
    } else {
      // No key: show blank create form with defaults.
      populateForm({key: "", value_type: valueType, description: description, value: ""});
    }
  }

  // Track the original key of the setting being edited (for key renames).
  var currentSettingKey = null;

  // Run the supplied function when the document has been marked ready.
  function docReady(fn) {
    if (document.readyState === "complete" || document.readyState === "interactive") {
      setTimeout(fn, 1);
    } else {
      document.addEventListener("DOMContentLoaded", fn);
    }
  }

  docReady(function() {
    storeAccessToken();

    document.querySelector("#super-settings-edit-value-type").addEventListener("change", changeValueType);
    document.querySelector("#super-settings-edit-save").addEventListener("click", saveSetting);

    initEditPage();
  });
})();
