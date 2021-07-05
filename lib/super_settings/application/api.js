(function() {
  // Get the URL for making an API call to the specified action and id.
  function apiURL(action, params) {
    let url = window.location.pathname;
    if (url.endsWith("/")) {
      url = url.substring(0, url.length - 1);
    }
    if (action) {
      url += action;
    }
    if (params) {
      const queryString = Object.keys(params).map(function(key) {
        return encodeURIComponent(key) + '=' + encodeURIComponent(params[key]);
      }).join('&');
      url += "?" + queryString
    }
    return url;
  }

  function callAPI(path, options, callback) {
    options ||= {};
    method = (options.method || "get");

    params = options.params
    let queryParams = null;
    const fetchOptions = {credentials: "same-origin"};
    const headers = Object.assign({"Accept": "application/json"}, SuperSettingsAPI.headers);
    if (method === "POST") {
      queryParams = Object.assign({}, SuperSettingsAPI.queryParams);
      csrfParam = document.querySelector("meta[name=csrf-param]");
      csrfToken = document.querySelector("meta[name=csrf-token]");
      if (csrfParam && csrfToken) {
        params = Object.assign({}, params || {});
        params[csrfParam.content] = csrfToken.content;
      }
      fetchOptions["method"] = "POST";
      fetchOptions["body"] = JSON.stringify(params);
      headers["Content-Type"] = "application/json";
    } else {
      queryParams = Object.assign({}, SuperSettingsAPI.queryParams, params);
    }
    fetchOptions["headers"] = new Headers(headers);
    const url = apiURL(path, queryParams);

    fetch(url, fetchOptions)
    .then(
      function(response) {
        if (response.ok) {
          return response.json();
        } else {
          throw( response.status + response.statusText)
        }
      }
    ).then(
      callback
    ).catch(
      function(error) {
        showError(error);
      }
    );
  }

  // Show an error message in an alert.
  function showError(error) {
    console.error('Error:', error)
    alert("Sorry, an error occurred. Refresh the page and try again.")
  }

  window.SuperSettingsAPI = {
    queryParams: {},
    headers: {},
    fetchSettings: function(callback) { callAPI("/settings", {}, callback) },
    fetchHistory: function(params, callback) { callAPI("/setting/history", {params: params}, callback) },
    updateSettings: function(params, callback) { callAPI("/settings", {method: "POST", params: params}, callback)}
  }
})();
