// Tints the top of the album page in the average colour of its cover.
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

// List view: on hover a row takes on its cover's colour (CSS .row-tint fades it in).
// Sits on the list container; the colour of a row is computed on its first hover.
export const RowTint = {
  mounted() {
    this.el.addEventListener("pointerover", async event => {
      const row = event.target.closest("[data-cover]")
      if (!row || row.style.getPropertyValue("--row-tint")) return

      const color = await averageColor(row.dataset.cover)
      if (color) row.style.setProperty("--row-tint", color)
    })
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
    const src = this.el.dataset.src
    const color = src ? await averageColor(src) : null

    if (color && this.el.dataset.src === src) {
      this.el.style.setProperty("--cover-tint", color)
      this.el.dataset.tinted = "true"
    } else {
      delete this.el.dataset.tinted
    }
  },
}
