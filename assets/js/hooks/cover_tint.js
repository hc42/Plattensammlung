// Tints the top of the album page in the colour of its cover (or its label).
//
// Only covers stored by the app (same origin) can be read: a remote image would
// "taint" the canvas, and getImageData throws. Then the page just stays untinted.
// The colour is cached per image, so LiveView patches re-apply it without
// loading the image again.

const tints = new Map()

export function averageColor(src) {
  if (tints.has(src)) return Promise.resolve(tints.get(src))

  return new Promise(resolve => {
    const image = new Image()
    image.onload = () => {
      try {
        const size = 24
        const canvas = document.createElement("canvas")
        canvas.width = canvas.height = size
        const context = canvas.getContext("2d", {willReadFrequently: true})
        context.drawImage(image, 0, 0, size, size)
        const color = vividAverage(context.getImageData(0, 0, size, size).data)
        tints.set(src, color)
        resolve(color)
      } catch (_tainted) {
        resolve(null)
      }
    }
    image.onerror = () => resolve(null)
    image.src = src
  })
}

// A plain average turns most covers grey; weighting each pixel by its
// saturation brings out the colour the cover is remembered by
function vividAverage(pixels) {
  let r = 0, g = 0, b = 0, total = 0

  for (let i = 0; i < pixels.length; i += 4) {
    const [pr, pg, pb] = [pixels[i], pixels[i + 1], pixels[i + 2]]
    const saturation = (Math.max(pr, pg, pb) - Math.min(pr, pg, pb)) / 255
    const weight = 0.05 + saturation * saturation
    r += pr * weight
    g += pg * weight
    b += pb * weight
    total += weight
  }

  return `rgb(${Math.round(r / total)} ${Math.round(g / total)} ${Math.round(b / total)})`
}

// The colour of an album element: its cover's (local covers only), otherwise the
// label colour the server put into data-color
async function tintOf(el) {
  const color = el.dataset.cover ? await averageColor(el.dataset.cover) : null
  return color || el.dataset.color || null
}

const HOVER_DELAY_MS = 150
const LEAVE_DELAY_MS = 400

// Album list: the page background (#list-tint) takes on the colour of the album
// under the mouse. Only after a short pause on an album, so moving across the
// grid doesn't flicker; leaving the albums fades it out. No effect on touch.
export const ListTint = {
  mounted() {
    this.el.addEventListener("pointerover", event => {
      if (event.pointerType !== "mouse") return
      const album = event.target.closest("[data-color]")
      if (!album) return

      clearTimeout(this.timer)
      this.timer = setTimeout(() => this.tint(album), HOVER_DELAY_MS)
    })

    this.el.addEventListener("pointerleave", () => {
      clearTimeout(this.timer)
      this.timer = setTimeout(() => this.target()?.removeAttribute("data-tinted"), LEAVE_DELAY_MS)
    })
  },

  destroyed() {
    clearTimeout(this.timer)
  },

  target() {
    return document.getElementById(this.el.dataset.tintTarget)
  },

  async tint(album) {
    const color = await tintOf(album)
    const target = this.target()
    if (!color || !target) return

    target.style.setProperty("--cover-tint", color)
    target.dataset.tinted = "true"
  },
}

export const CoverTint = {
  mounted() {
    this.apply()
  },

  // A LiveView patch removes the attributes the hook set
  updated() {
    this.apply()
  },

  async apply() {
    const src = this.el.dataset.cover
    const color = await tintOf(this.el)

    if (color && this.el.dataset.cover === src) {
      this.el.style.setProperty("--cover-tint", color)
      this.el.dataset.tinted = "true"
    } else {
      delete this.el.dataset.tinted
    }
  },
}
