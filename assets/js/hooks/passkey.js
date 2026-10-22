// Passkey sign-in and registration (see docs/adr/0005-passkey-login.md).
//
// Both flows ask the server for WebAuthn options, let the browser create or use
// a passkey, and send the result back. Binary values travel as base64url.

const toBuffer = base64url => {
  const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/")
  const binary = atob(base64.padEnd(Math.ceil(base64.length / 4) * 4, "="))
  return Uint8Array.from(binary, char => char.charCodeAt(0)).buffer
}

const toBase64url = buffer =>
  btoa(String.fromCharCode(...new Uint8Array(buffer)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "")

import {appPath} from "../app_path"

const csrfToken = () => document.querySelector("meta[name='csrf-token']").getAttribute("content")

async function request(method, path, body) {
  const response = await fetch(appPath(path), {
    method,
    headers: {"content-type": "application/json", "x-csrf-token": csrfToken()},
    body: body && JSON.stringify(body),
  })
  const data = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(data.error || "Unbekannter Fehler")
  return data
}

export const passkeysSupported = () =>
  window.isSecureContext && typeof window.PublicKeyCredential === "function"

// Errors the user caused (cancelled dialog, timeout) are not worth a red message
const message = error =>
  error.name === "NotAllowedError" || error.name === "AbortError"
    ? "Abgebrochen."
    : error.message

// <button phx-hook="PasskeySignIn" data-status="#id-of-status-element">
export const PasskeySignIn = {
  mounted() {
    if (!passkeysSupported()) {
      this.el.disabled = true
      this.el.title = "Passkeys brauchen HTTPS oder localhost"
      return
    }

    this.el.addEventListener("click", async () => {
      const status = document.querySelector(this.el.dataset.status)
      this.el.disabled = true
      status.textContent = ""

      try {
        const options = await request("GET", "/auth/passkey/sign-in-options")
        const credential = await navigator.credentials.get({
          publicKey: {...options, challenge: toBuffer(options.challenge)},
        })
        const {redirect_to} = await request("POST", "/auth/passkey/sign-in", {
          rawId: toBase64url(credential.rawId),
          authenticatorData: toBase64url(credential.response.authenticatorData),
          clientDataJSON: toBase64url(credential.response.clientDataJSON),
          signature: toBase64url(credential.response.signature),
        })
        window.location.assign(redirect_to)
      } catch (error) {
        status.textContent = message(error)
        this.el.disabled = false
      }
    })
  },
}

// <form phx-hook="PasskeyRegister"> with an input named "name"; tells the
// LiveView "passkey_registered" or "passkey_failed" when done
export const PasskeyRegister = {
  mounted() {
    if (!passkeysSupported()) {
      this.el.querySelectorAll("input, button").forEach(el => (el.disabled = true))
      this.pushEvent("passkey_failed", {error: "Passkeys brauchen HTTPS oder localhost."})
      return
    }

    this.el.addEventListener("submit", async event => {
      event.preventDefault()
      const name = new FormData(this.el).get("name")

      try {
        const options = await request("GET", "/auth/passkey/register-options")
        const credential = await navigator.credentials.create({
          publicKey: {
            ...options,
            challenge: toBuffer(options.challenge),
            user: {...options.user, id: toBuffer(options.user.id)},
            excludeCredentials: options.excludeCredentials.map(c => ({...c, id: toBuffer(c.id)})),
          },
        })
        await request("POST", "/auth/passkey/register", {
          name,
          rawId: toBase64url(credential.rawId),
          attestationObject: toBase64url(credential.response.attestationObject),
          clientDataJSON: toBase64url(credential.response.clientDataJSON),
        })
        this.el.reset()
        this.pushEvent("passkey_registered", {})
      } catch (error) {
        this.pushEvent("passkey_failed", {error: message(error)})
      }
    })
  },
}
