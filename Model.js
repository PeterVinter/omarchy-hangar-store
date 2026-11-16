.pragma library

// Parses `expac -S '%n\t%r\t%v\t%m\t%d'` into a list and a name index.
function parseRepo(text) {
  var list = []
  var index = {}
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var f = lines[i].split("\t")
    if (f.length < 5 || !/^[a-z0-9@._+-]+$/.test(f[0])) continue
    var item = { n: f[0], r: f[1], v: f[2], s: Number(f[3]) || 0, d: f.slice(4).join(" ") }
    index[item.n] = list.length
    list.push(item)
  }
  return { list: list, index: index }
}

function parseNames(text) {
  var set = {}
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) if (lines[i]) set[lines[i]] = true
  return set
}

function parseQuery(text) {
  var parts = String(text || "").split("---\n")
  return { all: parseNames(parts[0]), explicit: parseNames(parts[1] || "") }
}

function formatSize(bytes) {
  if (!bytes) return ""
  var mb = bytes / 1048576
  if (mb >= 1024) return (mb / 1024).toFixed(1) + " GB"
  if (mb >= 10) return Math.round(mb) + " MB"
  return mb.toFixed(1) + " MB"
}

function validName(n) {
  return typeof n === "string" && /^[a-z0-9@._+-]{1,100}$/.test(n)
}

// Validates and bounds an AUR RPC response. Returns [] for anything odd.
function parseAur(text, repoIndex) {
  var out = []
  try {
    var data = JSON.parse(text)
    var rows = data && data.results
    if (!Array.isArray(rows)) return out
    rows.sort(function(a, b) { return (Number(b.NumVotes) || 0) - (Number(a.NumVotes) || 0) })
    for (var i = 0; i < rows.length && out.length < 40; i++) {
      var r = rows[i]
      if (!validName(r.Name) || repoIndex[r.Name] !== undefined) continue
      out.push({
        n: r.Name,
        p: r.Name,
        r: "aur",
        v: String(r.Version || "").slice(0, 40),
        s: 0,
        d: String(r.Description || "").slice(0, 200),
        votes: Number(r.NumVotes) || 0,
        updated: Number(r.LastModified) || 0,
        ood: Number(r.OutOfDate) || 0,
        orphan: !r.Maintainer
      })
    }
  } catch (e) {}
  return out
}


// ---- AUR trust signals ------------------------------------------------------

var STALE_SECONDS = 2 * 365 * 86400

// Short warnings for an AUR row or detail record: "orphaned", "out of date", "stale".
function warnings(it, nowSec) {
  var out = []
  if (!it || it.r !== "aur") return out
  var now = nowSec || Math.floor(Date.now() / 1000)
  if (it.ood) out.push("out of date")
  if (it.orphan) out.push("orphaned")
  if (it.updated && now - it.updated > STALE_SECONDS) out.push("stale")
  return out
}

// Compact age: 5d, 3mo, 2y.
function ago(epoch, nowSec) {
  if (!epoch) return ""
  var now = nowSec || Math.floor(Date.now() / 1000)
  var d = Math.max(0, Math.floor((now - epoch) / 86400))
  if (d < 1) return "today"
  if (d < 60) return d + "d"
  if (d < 730) return Math.round(d / 30) + "mo"
  return Math.floor(d / 365) + "y"
}

function formatDate(epoch) {
  if (!epoch) return ""
  var d = new Date(epoch * 1000)
  var m = d.getMonth() + 1
  var day = d.getDate()
  return d.getFullYear() + "-" + (m < 10 ? "0" : "") + m + "-" + (day < 10 ? "0" : "") + day
}

// ---- Details ----------------------------------------------------------------

function clip(text, max) {
  text = String(text || "")
  return text.length > max ? text.slice(0, max - 1) + "…" : text
}

function safeUrl(u) {
  return typeof u === "string" && /^https?:\/\/[^\s'"`$\\]{1,300}$/.test(u) ? u : ""
}

// Parses `pacman -Si` / `pacman -Qi` output into a normalized detail record.
function parseInfo(text) {
  var map = {}
  var key = null
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var m = /^([A-Za-z][A-Za-z ]*?)\s*:\s?(.*)$/.exec(lines[i])
    if (m && lines[i].charAt(0) !== " ") { key = m[1]; map[key] = m[2] }
    else if (key && /^\s+\S/.test(lines[i])) map[key] += " " + lines[i].replace(/^\s+/, "")
  }
  function g(k) { var v = map[k]; return v && v !== "None" ? v : "" }
  if (!map.Name) return null
  return {
    n: g("Name"), v: g("Version"), r: g("Repository") || "local", d: g("Description"),
    url: safeUrl(g("URL")), license: g("Licenses"),
    depends: g("Depends On"), optdepends: g("Optional Deps"),
    dsize: g("Download Size"), isize: g("Installed Size"),
    packager: g("Packager"), built: g("Build Date"), arch: g("Architecture")
  }
}

// Parses an AUR RPC `info` response into the same record shape.
function parseAurInfo(text) {
  try {
    var data = JSON.parse(text)
    var r = data && data.results && data.results[0]
    if (!r || !validName(r.Name)) return null
    function list(a) { return Array.isArray(a) ? a.map(function(x) { return String(x).replace(/[<>=].*$/, "") }).join("  ") : "" }
    return {
      n: r.Name, v: String(r.Version || "").slice(0, 40), r: "aur", d: clip(r.Description, 300),
      url: safeUrl(r.URL), license: Array.isArray(r.License) ? r.License.join(", ") : "",
      depends: clip(list(r.Depends), 300), optdepends: clip(list(r.OptDepends), 300),
      maintainer: r.Maintainer ? String(r.Maintainer).slice(0, 60) : "",
      votes: Number(r.NumVotes) || 0, popularity: Number(r.Popularity) || 0,
      updated: Number(r.LastModified) || 0, first: Number(r.FirstSubmitted) || 0,
      ood: Number(r.OutOfDate) || 0, orphan: !r.Maintainer
    }
  } catch (e) { return null }
}

// ---- Updates ----------------------------------------------------------------

// Parses `checkupdates; echo ---; yay -Qua` into { name: {from, to, aur} }.
function parseUpdates(text) {
  var out = {}
  var parts = String(text || "").split("---\n")
  for (var p = 0; p < parts.length && p < 2; p++) {
    var lines = parts[p].split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = /^(\S+)\s+(\S+)\s+->\s+(\S+)/.exec(lines[i])
      if (m && validName(m[1])) out[m[1]] = { from: m[2], to: m[3], aur: p === 1 }
    }
  }
  return out
}

// ---- Desktop entries: icons and launching ------------------------------------

// Turns an `Icon=` value into an image source, or "" when it looks wrong.
// Theme names go through the icon provider, absolute paths must be image files
// under /usr or /opt.
function iconSource(icon) {
  icon = String(icon || "")
  if (/^[A-Za-z0-9][A-Za-z0-9._+-]{0,99}$/.test(icon)) return "image://icon/" + icon
  if (/^\/(usr|opt)\/[A-Za-z0-9._+\/-]{1,250}\.(png|svg|xpm)$/.test(icon) && icon.indexOf("..") < 0) return "file://" + icon
  return ""
}

// Parses `pkg \t desktop-id \t Icon \t terminal(0|1)` lines into
// { pkg: { id, icon, launch } }. `launch` is empty for terminal apps, which
// gtk-launch cannot start properly. A package with several entries keeps the one
// named like the package, otherwise the first.
function parseDesktops(text) {
  var out = {}
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var f = lines[i].split("\t")
    if (f.length < 4 || !validName(f[0]) || !/^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$/.test(f[1])) continue
    if (out[f[0]] && !(f[1] === f[0] && out[f[0]].id !== f[0])) continue
    out[f[0]] = { id: f[1], icon: iconSource(f[2]), launch: f[3] === "1" ? "" : f[1] }
  }
  return out
}

// ---- Bundles ----------------------------------------------------------------

// Resolves a bundle definition against this machine. Members that are not in the
// repositories (and not AUR with AUR search on) are counted but left out.
function resolveBundle(b, opts) {
  var byPkg = {}
  for (var i = 0; i < opts.catalog.length; i++) byPkg[opts.catalog[i].p] = opts.catalog[i]
  var members = []
  var unavailable = 0
  for (var j = 0; j < b.apps.length; j++) {
    var p = b.apps[j]
    var c = byPkg[p]
    var ri = opts.repoIndex[p]
    if (!validName(p) || (ri === undefined && !(c && c.a && opts.aurEnabled))) { unavailable++; continue }
    var repo = ri !== undefined ? opts.repo[ri] : null
    members.push({ p: p, label: c ? c.n : p, r: repo ? repo.r : "aur", s: repo ? repo.s : 0, installed: !!opts.installed[p] })
  }
  return { members: members, unavailable: unavailable }
}

function bundleRow(b, opts) {
  var res = resolveBundle(b, opts)
  if (!res.members.length) return null
  var todo = 0
  var size = 0
  for (var i = 0; i < res.members.length; i++) {
    if (!res.members[i].installed) { todo++; size += res.members[i].s }
  }
  var bits = [todo ? todo + " to install" : "all " + res.members.length + " installed"]
  if (size) bits.push(formatSize(size))
  return {
    n: b.n, label: b.n, p: "bundle:" + b.id, c: "", r: "bundle", v: "", s: size,
    d: res.members.map(function(m) { return m.label }).join(", "),
    bundle: true, members: res.members, pending: todo, meta: bits.join("  ·  ")
  }
}

// ---- Sorting ----------------------------------------------------------------

var sortModes = ["Default", "Name", "Size", "Votes"]

function sortRows(rows, mode) {
  if (mode === "Name") rows.sort(function(a, b) { return String(a.label || a.n).toLowerCase() < String(b.label || b.n).toLowerCase() ? -1 : 1 })
  else if (mode === "Size") rows.sort(function(a, b) { return (b.s || 0) - (a.s || 0) })
  else if (mode === "Votes") rows.sort(function(a, b) { return (b.votes || 0) - (a.votes || 0) })
  return rows
}

function score(item, q) {
  var n = item.n.toLowerCase()
  var label = (item.label || item.n).toLowerCase()
  if (n === q || label === q) return 100
  if (n.indexOf(q) === 0 || label.indexOf(q) === 0) return 80
  if (n.indexOf(q) >= 0 || label.indexOf(q) >= 0) return 60
  if ((item.d || "").toLowerCase().indexOf(q) >= 0) return 30
  return 0
}

// Builds the visible rows.
// opts: { catalog, bundles, desktops, categories, category, filter, repo, repoIndex,
//         installed, explicit, updates, aurEnabled, aurResults, sort, limit }
function build(opts) {
  var out = []
  var seen = {}
  var q = String(opts.filter || "").toLowerCase().replace(/^\s+|\s+$/g, "")

  function push(item) {
    if (seen[item.p]) return
    seen[item.p] = true
    item.installed = !!opts.installed[item.p]
    var desk = item.installed && opts.desktops ? opts.desktops[item.p] : null
    if (desk) { item.icon = desk.icon; item.launch = desk.launch }
    out.push(item)
  }

  function fromCatalog(c) {
    var ri = opts.repoIndex[c.p]
    if (ri === undefined && !(c.a && opts.aurEnabled)) return null
    var repo = ri !== undefined ? opts.repo[ri] : null
    return {
      n: c.n, label: c.n, p: c.p, c: c.c, d: c.d,
      r: repo ? repo.r : "aur", v: repo ? repo.v : "", s: repo ? repo.s : 0,
      featured: true
    }
  }

  if (q) {
    var scored = []
    for (var i = 0; i < opts.catalog.length; i++) {
      var ci = fromCatalog(opts.catalog[i])
      if (ci) { var s = score(ci, q); if (s > 0) scored.push({ s: s + 15, item: ci }) }
    }
    for (var j = 0; j < opts.repo.length; j++) {
      var rp = opts.repo[j]
      var rs = score(rp, q)
      if (rs > 0) scored.push({ s: rs, item: { n: rp.n, label: rp.n, p: rp.n, c: "", d: rp.d, r: rp.r, v: rp.v, s: rp.s } })
    }
    scored.sort(function(a, b) { return b.s - a.s || a.item.n.length - b.item.n.length })
    for (var k = 0; k < scored.length && out.length < opts.limit; k++) push(scored[k].item)
    if (opts.aurEnabled) {
      for (var m = 0; m < opts.aurResults.length && out.length < opts.limit + 40; m++) {
        var a = opts.aurResults[m]
        push({ n: a.n, label: a.n, p: a.p, c: "", d: a.d, r: "aur", v: a.v, s: 0, votes: a.votes,
               updated: a.updated, ood: a.ood, orphan: a.orphan })
      }
    }
    return sortRows(out, opts.sort)
  }

  if (opts.category === "Bundles") {
    var bundles = opts.bundles || []
    for (var bi = 0; bi < bundles.length; bi++) {
      var brow = bundleRow(bundles[bi], opts)
      if (brow) { push(brow); brow.installed = brow.pending === 0 }
    }
    return sortRows(out, opts.sort)
  }

  if (opts.category === "Updates") {
    var upd = opts.updates || {}
    var unames = Object.keys(upd).sort()
    for (var u = 0; u < unames.length; u++) {
      var ui = opts.repoIndex[unames[u]]
      var ur = ui !== undefined ? opts.repo[ui] : null
      push({ n: unames[u], label: unames[u], p: unames[u], c: "", d: ur ? ur.d : (upd[unames[u]].aur ? "AUR package" : ""),
             r: upd[unames[u]].aur ? "aur" : (ur ? ur.r : "repo"), v: upd[unames[u]].to, s: ur ? ur.s : 0,
             upd: upd[unames[u]].from + " → " + upd[unames[u]].to })
    }
    return sortRows(out, opts.sort)
  }

  if (opts.category === "Installed") {
    var names = Object.keys(opts.explicit).sort()
    for (var x = 0; x < names.length; x++) {
      var idx = opts.repoIndex[names[x]]
      var r = idx !== undefined ? opts.repo[idx] : null
      push({ n: names[x], label: names[x], p: names[x], c: "", d: r ? r.d : "Installed from outside the repositories",
             r: r ? r.r : "local", v: r ? r.v : "", s: r ? r.s : 0 })
    }
    return sortRows(out, opts.sort)
  }

  for (var y = 0; y < opts.catalog.length; y++) {
    var c = opts.catalog[y]
    if (opts.category !== "Featured" && c.c !== opts.category) continue
    var it = fromCatalog(c)
    if (it) push(it)
  }
  return sortRows(out, opts.sort)
}
