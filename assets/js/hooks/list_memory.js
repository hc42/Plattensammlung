// "Back to the list" returns to the list the user came from, with its view,
// order and search (e.g. /?sort=artist&view=list), not just the plain page.
//
// RememberList sits on the album list and keeps its URL and title in the tab's
// sessionStorage. BackLink on the album page uses them; without a remembered
// list (album opened directly) it keeps the link the server rendered.
//
// It also keeps the chosen view and order: app.js sends them as connect params
// (listPreferences), so every list without ?view= / ?sort= opens the same way.

const KEY = "plattensammlung:last-list"
const PREFS = "plattensammlung:list-prefs"

function read(key = KEY) {
  try {
    return JSON.parse(sessionStorage.getItem(key))
  } catch (_error) {
    return null
  }
}

export const listPreferences = () => read(PREFS) || {}

export const RememberList = {
  mounted() {
    this.remember()
  },

  updated() {
    this.remember()
  },

  remember() {
    try {
      const {url, label, view, sort} = this.el.dataset
      sessionStorage.setItem(KEY, JSON.stringify({url, label}))
      sessionStorage.setItem(PREFS, JSON.stringify({view, sort}))
    } catch (_error) {
      // Storage unavailable (private mode): the back link keeps its default
    }
  },
}

export const BackLink = {
  mounted() {
    this.apply()
  },

  // A LiveView patch restores the server's href and label
  updated() {
    this.apply()
  },

  apply() {
    const list = read()
    if (!list?.url || !list?.label) return

    this.el.setAttribute("href", list.url)
    this.el.querySelector("[data-label]").textContent = list.label
  },
}
