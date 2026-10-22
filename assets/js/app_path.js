// Paths in JavaScript need the optional prefix (PHX_PATH, ADR 0018), which the
// root layout puts into <meta name="base-path">: "" or e.g. "/plattensammlung".
export const appPath = path => {
  const base = document.querySelector("meta[name='base-path']")?.getAttribute("content") || ""
  return base + path
}
