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
        votes: Number(r.NumVotes) || 0
      })
    }
  } catch (e) {}
  return out
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
// opts: { catalog, categories, category, filter, repo, repoIndex, installed,
//         explicit, aurEnabled, aurResults, limit }
function build(opts) {
  var out = []
  var seen = {}
  var q = String(opts.filter || "").toLowerCase().replace(/^\s+|\s+$/g, "")

  function push(item) {
    if (seen[item.p]) return
    seen[item.p] = true
    item.installed = !!opts.installed[item.p]
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
        push({ n: a.n, label: a.n, p: a.p, c: "", d: a.d, r: "aur", v: a.v, s: 0, votes: a.votes })
      }
    }
    return out
  }

  if (opts.category === "Installed") {
    var names = Object.keys(opts.explicit).sort()
    for (var x = 0; x < names.length; x++) {
      var idx = opts.repoIndex[names[x]]
      var r = idx !== undefined ? opts.repo[idx] : null
      push({ n: names[x], label: names[x], p: names[x], c: "", d: r ? r.d : "Installed from outside the repositories",
             r: r ? r.r : "local", v: r ? r.v : "", s: r ? r.s : 0 })
    }
    return out
  }

  for (var y = 0; y < opts.catalog.length; y++) {
    var c = opts.catalog[y]
    if (opts.category !== "Featured" && c.c !== opts.category) continue
    var it = fromCatalog(c)
    if (it) push(it)
  }
  return out
}
