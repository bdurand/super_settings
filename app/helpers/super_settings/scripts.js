(function() {
  function docReady(fn) {
    if (document.readyState === "complete" || document.readyState === "interactive") {
      setTimeout(fn, 1);
    } else {
      document.addEventListener("DOMContentLoaded", fn);
    }
  }

  function addListener(element, event, handler) {
    if (element) {
      element.addEventListener(event, handler);
    }
  }

  function addListeners(elements, event, handler) {
    elements.forEach(function(element) { addListener(element, event, handler) });
  }

  function findSettingElement(id) {
    if (id) {
      return document.querySelector("#settings-table tr[id=setting-" + id + "]")
    } else {
      return null;
    }
  }

  function showError(error) {
    console.error('Error:', error)
    alert("Sorry, an error occurred. Refresh the page and try again.")
  }

  function changesCount() {
    var changes = 0;
    document.querySelectorAll("#settings-table tbody tr").forEach(function(element) {
      if (element.dataset.edited) {
        changes += 1;
      }
    });
    return changes;
  }

  function enableSaveButton() {
    var saveButton = document.querySelector("#save-settings");
    var discardButton = document.querySelector("#discard-changes");
    if (saveButton) {
      var count = changesCount();
      var countSpan = saveButton.querySelector(".count");
      if (count == 0) {
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

  function getFieldValueInput(settingRow) {
    var input = settingRow.querySelector(".js-setting-value input");
    if (!input) {
      input = settingRow.querySelector(".js-setting-value textarea");
    }
    return input;
  }

  function settingInputHTML(type, fieldId, fieldName) {
    var html = null;
    if (type === "array") {
      html = '<textarea name="' + fieldName + '" id="' + fieldId + '" rows="8" class="form-control"></textarea>';
    } else if (type === "boolean") {
      html = '<div class="form-check checkbox">'
      html += '<input type="checkbox" name="' + fieldName + '" id="' + fieldId + '" value="true">'
      html += '<label for="' + fieldId + '">Enabled</label>'
      html += '</div>'
    } else {
      html = '<input name="' + fieldName + '" id="' + fieldId + '" value="" class="form-control" '
      if (type === "float") {
        html += 'type="number" step="any"';
      } else if (type === "integer") {
        html += 'type="number" step="1"';
      } else if (type === "datetime") {
        html += 'type="datetime-local"';
      } else {
        html += 'type="text"';
      }
      html += ">";
    }
    return html;
  }

  function changeSettingType(event) {
    var valueTypeMenu = event.target;
    var settingRow = valueTypeMenu.closest("tr");
    var type = valueTypeMenu.options[valueTypeMenu.selectedIndex].value;
    var input = getFieldValueInput(settingRow)
    var fieldName = input.name;
    var fieldValue = input.value;
    if (input.type === "checkbox") {
      if (input.checked) {
        fieldValue = input.value;
      } else {
        fieldValue = null;
      }
    }
    var fieldId = fieldName.replace(/[\[\]]+/g, "_").replace(/_$/, "");

    input.remove();
    settingRow.querySelector(".js-setting-value").innerHTML = settingInputHTML(type, fieldId, fieldName);
    input = getFieldValueInput(settingRow);
    if (type === "boolean") {
      input.checked = fieldValue;
    } else {
      input.value = fieldValue;
    }
  }

  function addSettingToTable(id, html) {
    var settingRow = findSettingElement(id);
    if (settingRow) {
      settingRow.id = null;
      settingRow.innerHTML = "";
      settingRow.insertAdjacentHTML("afterend", html);
      settingRow.remove();
      settingRow = findSettingElement(id);
      bindSettingControlEvents(settingRow);
    } else {
      var tableBody = document.querySelector("#settings-table tbody");
      tableBody.insertAdjacentHTML("afterbegin", html);
      settingRow = tableBody.querySelector("tbody tr");
      settingRow.querySelector("input").focus();
    }
    settingRow.scrollIntoView({block: "nearest"});
    enableSaveButton();
  }

  function apiURL(action, id) {
    var url = document.location.pathname;
    if (url.endsWith("/")) {
      url = url.substring(0, url.length - 1);
    }
    if (id) {
      url += "/" + id;
    }
    if (action) {
      url += "/" + action;
    }
    return url;
  }

  function fetchSetting(action, id) {
    fetch(apiURL(action, id), {credentials: "same-origin", headers: new Headers({"Accept": "text/html"})})
    .then(
      function(response) {
        if (response.ok) {
          return response.text();
        } else {
          throw( response.status + response.statusText)
        }
      }
    ).then(
      function(html) { addSettingToTable(id, html) }
    ).catch(
      function(error) {
        showError(error);
      }
    );
  }

  function addSetting(event) {
    event.preventDefault();
    fetchSetting("new");
  }

  function editSetting(event) {
    event.preventDefault();
    var id = event.target.closest("tr").dataset.id;
    fetchSetting("edit", id);
  }

  function restoreSetting(event) {
    event.preventDefault();
    var id = event.target.closest("tr").dataset.id;
    tr = event.target.closest("tr");
    fetchSetting(null, id);
  }

  function removeSetting(event) {
    event.preventDefault();
    var settingRow = event.target.closest("tr");
    if (settingRow.dataset["id"]) {
      settingRow.querySelector("input.js-setting-deleted").value = "1";
      settingRow.dataset.edited = true;
      settingRow.style.color = "darkred";
      settingRow.querySelectorAll("td").forEach(function(element) { element.style.backgroundColor = "#ffd1d8" });
      settingRow.querySelector("td").style.textDecoration = "line-through";
      settingRow.querySelector(".js-remove-setting").style.display = "none";
      settingRow.querySelector(".js-cancel-remove-setting").style.display = "inline-block";
    } else {
      settingRow.remove();
    }
    enableSaveButton();
  }

  function cancelRemoveSetting(event) {
    event.preventDefault();
    var settingRow = event.target.closest("tr");
    settingRow.querySelector("input.js-setting-deleted").value = "";
    settingRow.dataset.edited = "";
    settingRow.style.color = "inherit";
    settingRow.querySelectorAll("td").forEach(function(element) { element.style.backgroundColor = "inherit" });
    settingRow.querySelector("td").style.textDecoration = "inherit";
    settingRow.querySelector(".js-cancel-remove-setting").style.display = "none";
    settingRow.querySelector(".js-remove-setting").style.display = "inline-block";
    enableSaveButton();
  }

  function filterSettings(event) {
    var filters = [];
    event.target.value.split(" ").forEach(function(filter) {
      filter = filter.toUpperCase();
      filters.push(function(tr) {
        text = "";
        var settingKey = tr.querySelector(".super-settings-key");
        if (settingKey) {
          text += " " + settingKey.textContent.toUpperCase();
        }
        var settingValue = tr.querySelector(".super-settings-value");
        if (settingValue) {
          text += " " + settingValue.textContent.toUpperCase();
        }
        var settingDescription = tr.querySelector(".setting-description");
        if (settingDescription) {
          text += " " + settingDescription.textContent.toUpperCase();
        }
        return (text.indexOf(filter) > -1);
      });
    });

    document.querySelectorAll("#settings-table tbody tr").forEach(function(tr) {
      matched = true;
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

  function dismissFlash() {
    if (document.querySelector(".js-flash")) {
      setTimeout(function(){
        document.querySelectorAll(".js-flash").forEach(function(element) {
          element.style.display = "none";
        });
      }, 3000);
    }
  }

  function applyFilter() {
    var filter = document.querySelector("#filter");
    if (filter) {
      filter.dispatchEvent(new Event("input"));
    }
  }

  function promptUnsavedChanges(event) {
    var form = document.querySelector("#settings-form");
    if (form && !form.dataset.submitting && changesCount() > 0) {
      return "Are you sure you want to leave?";
    } else {
      return undefined;
    }
  }

  function disableLeavePage(event) {
    document.querySelector("#settings-form").dataset.submitting = true;
  }

  function refreshPage(event) {
    event.preventDefault();
    var url = window.location.href.replace(/\?.*/, "");
    filter = document.querySelector("#filter").value;
    if (filter !== "") {
      url += "?filter=" + escape(filter);
    }
    window.location = url;
  }

  function showModal(event) {
    event.preventDefault();
    var modal = document.querySelector("#modal");
    var content = document.querySelector(".super-settings-modal-content");
    fetch(this.href, {credentials: "same-origin", headers: new Headers({"Accept": "text/html"})})
    .then(
      function(response) {
        if (response.ok) {
          return response.text();
        } else {
          throw( response.status + response.statusText)
        }
      }
    ).then(
      function(html) {
        content.innerHTML = html;
        modal.style.display = "block";
        modal.setAttribute("aria-hidden", "false");
        modal.activator = document.activeElement;
        focusableElements(document).forEach(function(element) {
          if (!modal.contains(element)) {
            element.dataset.saveTabIndex = element.getAttribute("tabindex");
            element.setAttribute("tabindex", -1);
          }
        });
        modalFocusables = null;
        document.querySelector("body").style.overflow = "hidden";
        addListeners(content.querySelectorAll(".js-modal-link"), "click", showModal);
      }
    ).catch(
      function(error) {
        showError(error);
      }
    );
  }

  function closeModal(event) {
    if (event.target.classList.contains("js-close-modal")) {
      event.preventDefault();
      var modal = document.querySelector("#modal");
      var content = document.querySelector(".super-settings-modal-content");
      modal.style.display = "none";
      modal.setAttribute("aria-hidden", "true");
      focusableElements(document).forEach(function(element) {
        var tabIndex = element.dataset.saveTabIndex;
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
  }

  function focusableElements(parent) {
    return parent.querySelectorAll("a[href], area[href], button, input:not([type=hidden]), select, textarea, iframe, [tabindex], [contentEditable=true]")
  }

  function bindSettingControlEvents(parent) {
    addListeners(parent.querySelectorAll(".js-remove-setting"), "click", removeSetting);
    addListeners(parent.querySelectorAll(".js-cancel-remove-setting"), "click", cancelRemoveSetting);
    addListeners(parent.querySelectorAll(".js-edit-setting"), "click", editSetting);
    addListeners(parent.querySelectorAll(".js-cancel-setting"), "click", restoreSetting);
    addListeners(parent.querySelectorAll(".js-modal-link"), "click", showModal);
    addListeners(parent.querySelectorAll(".js-setting-value-type"), "change", changeSettingType);
  }

  docReady(function() {
    addListener(document.querySelector("#filter"), "input", filterSettings);
    addListener(document.querySelector("#add-setting"), "click", addSetting);
    addListener(document.querySelector("#discard-changes"), "click", refreshPage);
    addListener(document.querySelector("#settings-form"), "submit", disableLeavePage);
    addListener(document.querySelector("#modal"), "click", closeModal);

    bindSettingControlEvents(document);

    applyFilter();
    dismissFlash();
    enableSaveButton();
    window.onbeforeunload = promptUnsavedChanges;
  })
})();
