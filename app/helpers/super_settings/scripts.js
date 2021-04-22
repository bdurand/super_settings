// function() {
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

  function enableSaveButton() {
    var saveButton = document.querySelector("#save-settings");
    if (saveButton) {
      var disabled = true;
      document.querySelectorAll("#settings-table tbody tr").forEach(function(element) {
        if (element.dataset.edited) {
          disabled = false;
          return;
        }
      });
      document.querySelector("#save-settings").disabled = disabled;
    }
  }

  function getFieldValueInput(settingRow) {
    var input = settingRow.querySelector(".js-setting-value input");
    if (!input) {
      input = settingRow.querySelector(".js-setting-value textarea");
    }
    return input;
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

    input.remove();
    settingRow.querySelector(".js-setting-value").innerHTML = html;
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
      addListener(settingRow.querySelector(".js-cancel-setting"), "click", restoreSetting);
      addListener(settingRow.querySelector(".js-edit-setting"), "click", editSetting);
    } else {
      var tableBody = document.querySelector("#settings-table tbody");
      tableBody.insertAdjacentHTML("afterbegin", html);
      settingRow = tableBody.querySelector("tbody tr");
      settingRow.querySelector("input").focus();
    }
    addListener(settingRow.querySelector(".js-remove-setting"), "click", removeSetting);
    addListener(settingRow.querySelector(".js-setting-value-type"), "change", changeSettingType);
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
    if (!settingRow.dataset["id"]) {
      settingRow.remove();
    } else {
      s = settingRow
      var deletedField = settingRow.querySelector("input.js-setting-deleted")
      if (deletedField.value) {
        deletedField.value = "";
        settingRow.dataset.edited = "";
        settingRow.style.color = "inherit";
        settingRow.querySelectorAll("td").forEach(function(element) { element.style.backgroundColor = "inherit" });
        settingRow.querySelector("td").style.textDecoration = "inherit";
      } else {
        deletedField.value = "1";
        settingRow.dataset.edited = true;
        settingRow.style.color = "darkred";
        settingRow.querySelectorAll("td").forEach(function(element) { element.style.backgroundColor = "lightpink" });
        settingRow.querySelector("td").style.textDecoration = "line-through";
      }
    }
    enableSaveButton();
  }

  function filterSettings(event) {
    var filters = [];
    event.target.value.split(" ").forEach(function(filter) {
      filter = filter.toUpperCase();
      filters.push(function(tr) {
        var val = tr.dataset.key;
        if (!val) {
          var input = tr.querySelector("td input")?.value
        }
        return (val && val.toUpperCase().indexOf(filter) > -1);
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

  function addFilterParam(event) {
    var filter = document.querySelector("#filter").value;
    if (filter == "") {
      return;
    }

    var url = this.href;
    var targetParts = url.split("#", 2);
    url = targetParts[0];
    var target = targetParts[1];
    var queryParts = url.split("?", 2);
    var url = queryParts[0];
    var query = queryParts[1];
    var params = (query ? query.split("&") : []);

    url += "?filter=" + escape(filter);
    params.forEach(function(p) {
      if (!p.startsWith("filter=")) {
        url += "&" + p;
      }
    });
    if (target) {
      url += "#" + target;
    }

    this.href = url
  }

  docReady(function() {
    addListener(document.querySelector("#filter"), "input", filterSettings);
    addListener(document.querySelector("#add-setting"), "click", addSetting);
    addListeners(document.querySelectorAll(".js-remove-setting"), "click", removeSetting);
    addListeners(document.querySelectorAll(".js-edit-setting"), "click", editSetting);
    addListeners(document.querySelectorAll(".js-cancel-setting"), "click", restoreSetting);
    addListeners(document.querySelectorAll(".js-setting-info"), "click", addFilterParam);
    applyFilter();
    dismissFlash();
    enableSaveButton();
  })
// }();
