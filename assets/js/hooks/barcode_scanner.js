// Barcode scanner for the import page (see docs/adr/0007-barcode-scan-and-import.md).
//
// Reads EAN/UPC codes, and QR codes with a Spotify album link, from the live
// camera or from a photo. Uses the browser's
// built-in BarcodeDetector where it supports these formats (Chrome, Android) and
// otherwise loads ZXing on demand (Safari, Firefox). A detected code is pushed to
// the LiveView as the "scanned" event.

const FORMATS = ["ean_13", "ean_8", "upc_a", "upc_e", "qr_code"]
const SCAN_INTERVAL_MS = 150
const MAX_PHOTO_SIZE = 1600

// Returns a function canvas -> code | null
async function createDetector() {
  if ("BarcodeDetector" in window) {
    const supported = await window.BarcodeDetector.getSupportedFormats()
    const formats = FORMATS.filter(format => supported.includes(format))

    if (formats.length > 0) {
      const detector = new window.BarcodeDetector({formats})
      return async canvas => (await detector.detect(canvas))[0]?.rawValue ?? null
    }
  }

  const {BrowserMultiFormatReader} = await import("@zxing/browser")
  const reader = new BrowserMultiFormatReader()

  return async canvas => {
    try {
      return reader.decodeFromCanvas(canvas).getText()
    } catch (_notFound) {
      return null
    }
  }
}

// A Spotify album link from a QR code, e.g. https://open.spotify.com/album/…
export const spotifyAlbumLink = code =>
  /^(https:\/\/open\.spotify\.com\/(intl-[a-z-]+\/)?album\/|spotify:album:)[0-9A-Za-z]{22}/.test(code)

// EAN-13, UPC-A (12) and EAN-8 carry a check digit; misreads usually fail it.
// UPC-E (8 digits, rare on records) is checked like EAN-8 and may be rejected.
export function validBarcode(code) {
  if (!/^(\d{8}|\d{12}|\d{13})$/.test(code)) return false

  const digits = code.split("").map(Number)
  const check = digits.pop()
  const sum = digits.reverse().reduce((acc, digit, i) => acc + digit * (i % 2 === 0 ? 3 : 1), 0)

  return (10 - (sum % 10)) % 10 === check
}

export const BarcodeScanner = {
  mounted() {
    this.video = this.el.querySelector("video")
    this.status = this.el.querySelector("[data-status]")
    this.photoInput = this.el.querySelector("input[type=file]")
    this.canvas = document.createElement("canvas")

    this.el.querySelector("[data-start]").addEventListener("click", () => this.start())
    this.el.querySelector("[data-stop]").addEventListener("click", () => this.stop())
    this.photoInput.addEventListener("change", () => this.scanPhoto(this.photoInput.files[0]))
  },

  destroyed() {
    this.stop()
  },

  async detector() {
    this.detect = this.detect || (await createDetector())
    return this.detect
  },

  async start() {
    if (!navigator.mediaDevices?.getUserMedia) {
      this.setStatus("Die Live-Kamera braucht HTTPS. Nimm stattdessen ein Foto auf.")
      return
    }

    try {
      await this.detector()
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: {facingMode: {ideal: "environment"}, width: {ideal: 1280}},
        audio: false,
      })
    } catch (error) {
      this.setStatus(
        error.name === "NotAllowedError"
          ? "Kamerazugriff wurde nicht erlaubt."
          : "Die Kamera konnte nicht gestartet werden."
      )
      return
    }

    this.video.srcObject = this.stream
    await this.video.play()
    this.el.dataset.active = "true"
    this.lastCode = null
    this.setStatus("Barcode in den Rahmen halten …")
    this.scanFrame()
  },

  stop() {
    clearTimeout(this.timer)
    this.stream?.getTracks().forEach(track => track.stop())
    this.stream = null
    if (this.video) this.video.srcObject = null
    this.el.dataset.active = "false"
  },

  async scanFrame() {
    if (!this.stream) return

    const {videoWidth: width, videoHeight: height} = this.video

    if (width > 0) {
      this.canvas.width = width
      this.canvas.height = height
      this.canvas.getContext("2d", {willReadFrequently: true}).drawImage(this.video, 0, 0)

      const code = await this.detect(this.canvas)
      if (code && this.confirm(code)) return
    }

    this.timer = setTimeout(() => this.scanFrame(), SCAN_INTERVAL_MS)
  },

  // A code counts once it was read twice in a row, which filters out misreads
  confirm(code) {
    if (!validBarcode(code) && !spotifyAlbumLink(code)) return false

    if (code !== this.lastCode) {
      this.lastCode = code
      return false
    }

    this.stop()
    this.found(code)
    return true
  },

  async scanPhoto(file) {
    if (!file) return
    this.setStatus("Foto wird gelesen …")

    try {
      const detect = await this.detector()
      const bitmap = await createImageBitmap(file)
      const scale = Math.min(1, MAX_PHOTO_SIZE / Math.max(bitmap.width, bitmap.height))

      this.canvas.width = Math.round(bitmap.width * scale)
      this.canvas.height = Math.round(bitmap.height * scale)
      this.canvas.getContext("2d").drawImage(bitmap, 0, 0, this.canvas.width, this.canvas.height)

      const code = await detect(this.canvas)

      if (code && (validBarcode(code) || spotifyAlbumLink(code))) {
        this.found(code)
      } else {
        this.setStatus("Kein Barcode erkannt. Bitte näher heran und scharf fotografieren.")
      }
    } catch (_error) {
      this.setStatus("Das Foto konnte nicht gelesen werden.")
    } finally {
      this.photoInput.value = ""
    }
  },

  found(code) {
    navigator.vibrate?.(80)
    this.setStatus(`Erkannt: ${code}`)
    this.pushEvent("scanned", {code})
  },

  setStatus(text) {
    this.status.textContent = text
  },
}
