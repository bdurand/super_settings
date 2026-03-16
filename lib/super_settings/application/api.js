// Functions for using the Super Settngs REST API.
//
// The functions are exposed through the `window.SuperSettingsAPI` object.
//
// You can set the `baseUrl` property on this object to specify the API endpoint.
// If not set, it will fall back to using `window.location.pathname`.
//
// You can add custom headers or query string parameters to the API requests
// by adding key/values to the `headers` and `queryParams` hashes on this object.
// You can use these to add authorization credentials or access tokens to the
// requests so they will be accepted by the back end.
(function() {
  // Get the URL for making an API call to the specified action and id.
  function apiURL(action, params) {
    let url = SuperSettingsAPI.baseUrl || window.location.pathname;
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
      if (queryString.length > 0) {
        url += "?" + queryString
      }
    }
    return url;
  }

  function callAPI(path, options, callback, errorCallback) {
    if (!options) {
      options = {};
    }
    method = (options.method || "get");

    params = options.params
    let queryParams = null;
    const headers = new Headers();
    const fetchOptions = {credentials: "same-origin", headers: headers};
    const accessToken = window.sessionStorage.getItem("super_settings_access_token");

    headers.set("Accept", "application/json");
    if (accessToken) {
      headers.set("Authorization", "Bearer " + accessToken);
    }
    Object.entries(SuperSettingsAPI.headers).forEach(function(entry) {
      const [key, value] = entry;
      headers.set(key, value);
    });

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
      headers.set("Content-Type", "application/json");
    } else {
      queryParams = Object.assign({}, SuperSettingsAPI.queryParams, params);
    }
    const url = apiURL(path, queryParams);

    fetch(url, fetchOptions)
    .then(
      function(response) {
        if (response.ok) {
          return response.json();
        } else if ((response.status === 401 || response.status === 403) && SuperSettingsAPI.authenticationUrl) {
          window.location = SuperSettingsAPI.authenticationUrl;
        } else if (errorCallback) {
          errorCallback(response.status + " " + response.statusText);
          return null;
        } else {
          throw(response.status + " " + response.statusText)
        }
      }
    ).then(
      function(data) {
        if (data !== null && data !== undefined && callback) {
          callback(data);
        }
      }
    ).catch(
      function(error) {
        if (errorCallback) {
          errorCallback(error);
        } else {
          showError(error);
        }
      }
    );
  }

  // Show an error message in an alert.
  function showError(error) {
    console.error('Error:', error)
    const _i18n = window.__superSettingsI18n || {};
    alert(_i18n["error.generic"] || "Sorry, an error occurred. Refresh the page and try again.")
  }

  window.SuperSettingsAPI = {
    baseUrl: null,
    queryParams: {},
    headers: {},
    authorized: function(callback, errorCallback) {
      callAPI("/authorized", {}, function(data) { callback(data.permission); }, function(error) {
        if (typeof error === "string" && (error.startsWith("401") || error.startsWith("403"))) {
          callback("none");
        } else if (errorCallback) {
          errorCallback(error);
        } else {
          showError(error);
        }
      });
    },
    fetchSettings: function(callback, errorCallback) { callAPI("/settings", {}, callback, errorCallback) },
    fetchHistory: function(params, callback, errorCallback) { callAPI("/setting/history", {params: params}, callback, errorCallback) },
    updateSettings: function(params, callback, errorCallback) { callAPI("/settings", {method: "POST", params: params}, callback, errorCallback) },
    fetchSetting: function(key, callback, errorCallback) { callAPI("/setting", {params: {key: key}}, callback, errorCallback) }
  }
})();
