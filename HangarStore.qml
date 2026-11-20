import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Catalog.js" as Catalog
import "Model.js" as Model

// Hangar Store: a themed overlay for finding, installing and removing packages.
// Colours, fonts, corner radius and borders all come from the [menu] tokens of
// the current Omarchy theme, so it follows theme switches live.
Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property bool showAbout: false
  property string filterText: ""
  property string category: "Featured"
  property int selectedIndex: 0
  property bool cursorActive: true

  property var repo: []
  property var repoIndex: ({})
  property bool repoLoaded: false
  property var installed: ({})
  property var explicit: ({})
  property var basket: ({})
  property int basketCount: 0

  property bool aurEnabled: false
  property var aurResults: []
  property bool aurBusy: false
  property string aurQuery: ""

  readonly property string here: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/+$/, "")

  property var items: []

  // Desktop entries of installed packages: { pkg: { id, icon, launch } }.
  property var desktops: ({})
  property int desktopsFor: -1

  property string sortMode: "Default"

  property var updates: ({})
  property int updatesCount: 0
  property bool updatesBusy: false
  property double updatesChecked: 0

  property bool showDetail: false
  property var detailItem: null
  property var detailInfo: null
  property bool detailBusy: false
  property var detailPending: null

  readonly property bool updateMode: root.category === "Updates" && root.filterText === ""
                                     && root.updatesCount > 0 && root.basketCount === 0

  readonly property var categoryNames: ["Featured", "Bundles"].concat(Catalog.categories).concat(["Updates", "Installed"])

  // Theme tokens (shared with the Omarchy menu).
  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color accent: Commons.Color.menu.selectedText
  property color border: Commons.Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Commons.Color.menu.scrim
  property color selectedBackground: Commons.Color.menu.selectedBackground
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int pad: Style.spacing.panelPadding

  property int cardWidth: Math.min(Style.space(1000), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(680), panel.height - Style.gapsOut * 2)
  property int columns: cardWidth >= Style.space(860) ? 3 : 2

  // ------------------------------------------------------------------ state

  function open(payloadJson) {
    root.opened = true
    root.showAbout = false
    root.showDetail = false
    root.filterText = ""
    root.category = "Featured"
    root.selectedIndex = 0
    root.cursorActive = true
    root.basket = ({})
    root.basketCount = 0
    root.aurResults = []
    root.refreshInstalled()
    root.refreshUpdates(false)
    if (!root.repoLoaded && !repoProc.running) repoProc.running = true
    root.rebuild()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() { root.opened = false }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "peter.hangar-store")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function refreshInstalled() {
    if (!queryProc.running) queryProc.running = true
  }

  function rebuild() {
    var rows = Model.build({
      catalog: Catalog.apps,
      bundles: Catalog.bundles,
      desktops: root.desktops,
      category: root.category,
      filter: root.filterText,
      repo: root.repo,
      repoIndex: root.repoIndex,
      installed: root.installed,
      explicit: root.explicit,
      updates: root.updates,
      sort: root.sortMode,
      aurEnabled: root.aurEnabled,
      aurResults: root.aurResults,
      limit: 150
    })
    root.items = rows
    if (root.selectedIndex >= rows.length) root.selectedIndex = Math.max(0, rows.length - 1)
  }

  function setFilter(text) {
    root.filterText = text
    root.selectedIndex = 0
    root.rebuild()
    root.scheduleAur()
  }

  function setCategory(name) {
    root.category = name
    root.filterText = ""
    root.selectedIndex = 0
    root.rebuild()
  }

  function cycleCategory(delta) {
    var i = root.categoryNames.indexOf(root.category)
    var next = (i + delta + root.categoryNames.length) % root.categoryNames.length
    root.setCategory(root.categoryNames[next])
  }

  function toggleAur() {
    root.aurEnabled = !root.aurEnabled
    root.aurResults = []
    root.rebuild()
    root.scheduleAur()
  }

  function cycleSort() {
    var modes = Model.sortModes
    root.sortMode = modes[(modes.indexOf(root.sortMode) + 1) % modes.length]
    root.selectedIndex = 0
    root.rebuild()
  }

  function categoryLabel(name) {
    if (name !== "Updates") return name
    if (root.updatesCount > 0) return "Updates " + root.updatesCount
    return root.updatesBusy ? "Updates …" : "Updates"
  }

  // -------------------------------------------------------------- updates

  function refreshUpdates(force) {
    if (updProc.running) return
    if (!force && root.updatesChecked > 0 && Date.now() - root.updatesChecked < 300000) return
    root.updatesBusy = true
    updProc.running = true
  }

  // Arch does not support partial upgrades, so updating is always the full
  // Omarchy update, never a single package.
  function runUpdate() {
    root.updatesChecked = 0
    root.run("omarchy-update")
  }

  // --------------------------------------------------------------- details

  function openDetails(item) {
    if (!item || !Model.validName(item.p)) return
    root.detailItem = item
    root.detailInfo = null
    root.showDetail = true
    root.loadDetails(item)
  }

  function closeDetails() {
    root.showDetail = false
    root.detailPending = null
  }

  function loadDetails(item) {
    if (detailProc.running) { root.detailPending = item; return }
    root.detailBusy = true
    root.detailPending = null
    if (item.r === "aur")
      detailProc.command = ["curl", "-sf", "--proto", "=https", "--max-time", "8", "--max-filesize", "1048576",
        "https://aur.archlinux.org/rpc/v5/info?arg[]=" + encodeURIComponent(item.p)]
    else
      detailProc.command = ["bash", "-c", "LC_ALL=C pacman -Si -- \"$1\" 2>/dev/null || LC_ALL=C pacman -Qi -- \"$1\"", "hangar", item.p]
    detailProc.running = true
  }

  function openHomepage() {
    var url = root.detailInfo && root.detailInfo.url
    if (url) Quickshell.execDetached(["xdg-open", url])
  }

  function detailAction() {
    var item = root.detailItem
    if (!item) return
    if (item.upd) root.runUpdate()
    else root.installOne(item)
  }

  // Label/value rows for the detail view, merged from the item and fetched info.
  function detailRows() {
    var it = root.detailItem
    var info = root.detailInfo
    var rows = []
    if (!it) return rows
    function add(k, v) { if (v !== undefined && v !== null && String(v) !== "") rows.push({ k: k, v: String(v) }) }
    var src = info || it
    add("Source", it.r === "aur" ? "AUR" : (info && info.r) || it.r)
    add("Version", (info && info.v) || it.v)
    if (it.upd) add("Update", it.upd)
    add("License", info && info.license)
    if (info && info.dsize) add("Download", info.dsize)
    if (info && info.isize) add("Installed size", info.isize)
    else if (it.s) add("Installed size", Model.formatSize(it.s))
    if (info && info.maintainer !== undefined) add("Maintainer", info.maintainer || "none (orphaned)")
    if (info && info.votes !== undefined) add("Votes", "★ " + info.votes + "   popularity " + info.popularity.toFixed(2))
    if (info && info.updated) add("Last updated", Model.formatDate(info.updated) + "  (" + Model.ago(info.updated) + " ago)")
    if (info && info.first) add("First submitted", Model.formatDate(info.first))
    if (info && info.built) add("Built", info.built)
    if (info && info.arch) add("Architecture", info.arch)
    add("Homepage", info && info.url)
    add("Depends", info && Model.clip(info.depends, 260))
    add("Optional", info && Model.clip(info.optdepends, 260))
    return rows
  }

  // ------------------------------------------------------------- selection

  function move(delta) {
    if (root.items.length === 0) return
    root.cursorActive = true
    root.selectedIndex = Math.max(0, Math.min(root.items.length - 1, root.selectedIndex + delta))
    grid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
  }

  function currentItem() {
    return root.cursorActive && root.selectedIndex < root.items.length ? root.items[root.selectedIndex] : null
  }

  // ---------------------------------------------------------------- basket

  // Members of a bundle that are not installed yet.
  function pendingMembers(item) {
    var out = []
    var members = (item && item.members) || []
    for (var i = 0; i < members.length; i++) if (!members[i].installed) out.push(members[i])
    return out
  }

  function isMarked(item) {
    if (!item) return false
    if (!item.bundle) return !!root.basket[item.p]
    var pending = root.pendingMembers(item)
    for (var i = 0; i < pending.length; i++) if (!root.basket[pending[i].p]) return false
    return pending.length > 0
  }

  function toggleMark(item) {
    if (!item || item.installed) return
    var next = Object.assign({}, root.basket)
    if (item.bundle) {
      var pending = root.pendingMembers(item)
      var all = root.isMarked(item)
      for (var i = 0; i < pending.length; i++) {
        if (all) delete next[pending[i].p]
        else next[pending[i].p] = pending[i].r === "aur" ? "aur" : "repo"
      }
    } else if (next[item.p]) delete next[item.p]
    else next[item.p] = item.r === "aur" ? "aur" : "repo"
    root.basket = next
    root.basketCount = Object.keys(next).length
  }

  // --------------------------------------------------------------- actions

  function run(command) {
    root.dismiss()
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", command])
  }

  function installItems(entries) {
    var repoPkgs = []
    var aurPkgs = []
    for (var i = 0; i < entries.length; i++) {
      if (!Model.validName(entries[i].p)) continue
      if (entries[i].r === "aur") aurPkgs.push(entries[i].p)
      else repoPkgs.push(entries[i].p)
    }
    var parts = []
    if (repoPkgs.length) parts.push("omarchy-pkg-add " + repoPkgs.join(" "))
    if (aurPkgs.length) parts.push("omarchy-pkg-aur-add " + aurPkgs.join(" "))
    if (parts.length) root.run(parts.join("; "))
  }

  function installOne(item) {
    if (!item || item.installed) return
    if (item.bundle) root.installItems(root.pendingMembers(item))
    else root.installItems([item])
  }

  function resolveIcon(src) {
    if (src.indexOf("image://icon/") !== 0) return src
    var path = Quickshell.iconPath(src.slice(13), true)
    return path ? String(path) : ""
  }

  // Starts an installed app through its desktop entry. The id comes from a
  // .desktop file name and is checked again here before it reaches a command.
  function launchItem(item) {
    if (!item || !item.launch || !/^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$/.test(item.launch)) return
    root.dismiss()
    Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", item.launch])
  }

  function installBasketOrCurrent() {
    if (root.updateMode) {
      root.runUpdate()
    } else if (root.basketCount > 0) {
      var picked = []
      for (var p in root.basket) picked.push({ p: p, r: root.basket[p] })
      root.installItems(picked)
    } else {
      root.installOne(root.currentItem())
    }
  }

  function removeItem(item) {
    if (!item || !item.installed || !Model.validName(item.p)) return
    root.run("omarchy-pkg-drop " + item.p)
  }

  // ------------------------------------------------------------- data feeds

  function scheduleAur() {
    aurTimer.stop()
    if (root.aurEnabled && root.filterText.length >= 3) aurTimer.restart()
  }

  Timer {
    id: aurTimer
    interval: 450
    onTriggered: {
      if (aurProc.running) { aurTimer.restart(); return }
      root.aurQuery = root.filterText
      root.aurBusy = true
      aurProc.command = ["curl", "-sf", "--proto", "=https", "--max-time", "8", "--max-filesize", "1048576",
        "https://aur.archlinux.org/rpc/v5/search/" + encodeURIComponent(root.filterText) + "?by=name-desc"]
      aurProc.running = true
    }
  }

  Process {
    id: aurProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.aurBusy = false
        if (root.aurQuery === root.filterText) {
          root.aurResults = Model.parseAur(text, root.repoIndex)
          root.rebuild()
        }
      }
    }
    onExited: function(code) { if (code !== 0) root.aurBusy = false }
  }

  Process {
    id: updProc
    command: ["bash", "-c", "timeout 90 checkupdates 2>/dev/null; echo ---; if command -v yay >/dev/null; then timeout 45 yay -Qua 2>/dev/null; fi"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.updates = Model.parseUpdates(text)
        root.updatesCount = Object.keys(root.updates).length
        root.updatesChecked = Date.now()
        root.updatesBusy = false
        root.rebuild()
      }
    }
    onExited: root.updatesBusy = false
  }

  Process {
    id: detailProc
    stdout: StdioCollector {
      onStreamFinished: {
        var item = root.detailItem
        var info = item && item.r === "aur" ? Model.parseAurInfo(text) : Model.parseInfo(text)
        if (info && item && info.n === item.p) root.detailInfo = info
        root.detailBusy = false
      }
    }
    onExited: {
      root.detailBusy = false
      if (root.detailPending) root.loadDetails(root.detailPending)
    }
  }

  Process {
    id: repoProc
    command: ["expac", "-S", "%n\t%r\t%v\t%m\t%d"]
    stdout: StdioCollector {
      onStreamFinished: {
        var parsed = Model.parseRepo(text)
        root.repo = parsed.list
        root.repoIndex = parsed.index
        root.repoLoaded = true
        root.rebuild()
      }
    }
  }

  // One pass over the .desktop files of all installed packages gives icons and
  // launch ids. Re-run only when the number of installed packages changes.
  Process {
    id: desktopProc
    command: [root.here + "/desktop-entries"]
    stdout: StdioCollector {
      onStreamFinished: {
        var parsed = Model.parseDesktops(text)
        // Drop theme icons the system cannot find, so they do not show as a
        // placeholder; the letter tile is used instead.
        for (var pkg in parsed) parsed[pkg].icon = root.resolveIcon(parsed[pkg].icon)
        root.desktops = parsed
        root.rebuild()
      }
    }
  }

  Process {
    id: queryProc
    command: ["bash", "-c", "pacman -Qq; echo ---; pacman -Qqe"]
    stdout: StdioCollector {
      onStreamFinished: {
        var parsed = Model.parseQuery(text)
        root.installed = parsed.all
        root.explicit = parsed.explicit
        var total = Object.keys(parsed.all).length
        if (total !== root.desktopsFor && !desktopProc.running) {
          root.desktopsFor = total
          desktopProc.running = true
        }
        var next = {}
        var count = 0
        for (var p in root.basket) if (!parsed.all[p]) { next[p] = root.basket[p]; count++ }
        root.basket = next
        root.basketCount = count
        root.rebuild()
      }
    }
  }

  // Picks up installs and removals finished in the floating terminal.
  Timer {
    interval: 4000
    repeat: true
    running: root.opened
    onTriggered: root.refreshInstalled()
  }

  // ------------------------------------------------------------------- view

  OverlayWindow {
    id: panel
    shown: root.opened
    WlrLayershell.namespace: "peter.hangar-store"

    Rectangle {
      anchors.fill: parent
      color: root.scrim
      opacity: panel.contentRevealed ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.pad

      opacity: panel.contentRevealed ? 1 : 0
      scale: panel.contentRevealed ? 1 : 0.97
      Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: Style.duration(180); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
          var key = event.key
          if (key === Qt.Key_Escape) {
            if (root.showAbout) root.showAbout = false
            else if (root.showDetail) root.closeDetails()
            else if (root.filterText) root.setFilter("")
            else root.dismiss()
          } else if (root.showAbout) {
            if (key === Qt.Key_Return || key === Qt.Key_Enter) root.showAbout = false
          } else if (root.showDetail) {
            if (key === Qt.Key_Return || key === Qt.Key_Enter) root.detailAction()
            else if (key === Qt.Key_Delete) root.removeItem(root.detailItem)
            else if (ctrl && key === Qt.Key_O) root.openHomepage()
            else if (ctrl && key === Qt.Key_L) root.launchItem(root.detailItem)
          } else if (ctrl && key === Qt.Key_A) {
            root.toggleAur()
          } else if (ctrl && key === Qt.Key_S) {
            root.cycleSort()
          } else if (ctrl && key === Qt.Key_R) {
            root.refreshUpdates(true)
          } else if (ctrl && key === Qt.Key_L) {
            root.launchItem(root.currentItem())
          } else if (ctrl && key === Qt.Key_I) {
            root.openDetails(root.currentItem())
          } else if (key === Qt.Key_Backtab || (key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
            root.cycleCategory(-1)
          } else if (key === Qt.Key_Tab) {
            root.cycleCategory(1)
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
          } else if (Util.readingKey(event) === Qt.Key_Left) {
            root.move(-1)
          } else if (Util.readingKey(event) === Qt.Key_Right) {
            root.move(1)
          } else if (key === Qt.Key_Up) {
            root.move(-root.columns)
          } else if (key === Qt.Key_Down) {
            root.move(root.columns)
          } else if (key === Qt.Key_PageUp) {
            root.move(-root.columns * 3)
          } else if (key === Qt.Key_PageDown) {
            root.move(root.columns * 3)
          } else if (key === Qt.Key_Insert || (ctrl && key === Qt.Key_Space)) {
            root.toggleMark(root.currentItem())
          } else if (key === Qt.Key_Delete) {
            root.removeItem(root.currentItem())
          } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
            root.installBasketOrCurrent()
          } else if (event.text && event.text.length === 1 && !ctrl
                     && !(event.modifiers & (Qt.AltModifier | Qt.MetaModifier))
                     && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
          } else {
            return
          }
          event.accepted = true
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Style.spacing.lg

        // Search field
        Rectangle {
          width: parent.width
          height: Math.max(Style.space(44), Style.font.heading + Style.spacing.lg * 2)
          radius: root.cornerRadius
          color: Util.alpha(root.foreground, 0.06)
          border.width: 1
          border.color: Util.alpha(root.accent, root.filterText ? 0.7 : 0.25)

          Text {
            id: searchGlyph
            anchors.left: parent.left
            anchors.leftMargin: Style.spacing.lg + 2
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "⌕"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
          }

          Text {
            anchors.left: searchGlyph.right
            anchors.leftMargin: Style.spacing.md
            anchors.right: sortBadge.left
            anchors.rightMargin: Style.spacing.md
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.filterText || (root.repoLoaded ? "Search " + root.repo.length + " packages…" : "Loading packages…")
            color: root.foreground
            opacity: root.filterText ? 1 : 0.55
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
          }

          Rectangle {
            id: sortBadge
            anchors.right: aurBadge.left
            anchors.rightMargin: Style.spacing.md
            anchors.verticalCenter: parent.verticalCenter
            width: sortLabel.implicitWidth + Style.spacing.lg * 2
            height: Style.font.body + Style.spacing.md * 2
            radius: height / 2
            color: root.sortMode !== "Default" ? Util.alpha(root.accent, 0.2) : "transparent"
            border.width: 1
            border.color: Util.alpha(root.sortMode !== "Default" ? root.accent : root.foreground, root.sortMode !== "Default" ? 0.9 : 0.3)

            Text {
              id: sortLabel
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: "Sort: " + root.sortMode
              color: root.sortMode !== "Default" ? root.accent : root.foreground
              opacity: root.sortMode !== "Default" ? 1 : 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.cycleSort()
            }
          }

          Rectangle {
            id: aurBadge
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.lg
            anchors.verticalCenter: parent.verticalCenter
            width: aurLabel.implicitWidth + Style.spacing.lg * 2
            height: Style.font.body + Style.spacing.md * 2
            radius: height / 2
            color: root.aurEnabled ? Util.alpha(root.accent, 0.2) : "transparent"
            border.width: 1
            border.color: Util.alpha(root.aurEnabled ? root.accent : root.foreground, root.aurEnabled ? 0.9 : 0.3)

            Text {
              id: aurLabel
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: root.aurBusy ? "AUR …" : (root.aurEnabled ? "AUR on" : "AUR off")
              color: root.aurEnabled ? root.accent : root.foreground
              opacity: root.aurEnabled ? 1 : 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleAur()
            }
          }
        }

        // Category chips
        Flow {
          width: parent.width
          spacing: Style.spacing.md

          Repeater {
            model: root.categoryNames

            delegate: Rectangle {
              required property string modelData
              readonly property bool active: root.filterText === "" && root.category === modelData

              width: chipText.implicitWidth + Style.spacing.lg * 2.5
              height: Style.font.body + Style.spacing.md * 2 + 2
              radius: height / 2
              color: active ? Util.alpha(root.accent, 0.2) : (chipMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent")
              border.width: 1
              border.color: Util.alpha(active ? root.accent : root.foreground, active ? 0.9 : 0.22)
              Behavior on color { ColorAnimation { duration: Style.duration(120) } }

              Text {
                id: chipText
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: root.categoryLabel(parent.modelData)
                color: parent.active ? root.accent : (parent.modelData === "Updates" && root.updatesCount > 0 ? root.accent : root.foreground)
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: parent.active || (parent.modelData === "Updates" && root.updatesCount > 0)
              }

              MouseArea {
                id: chipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setCategory(parent.modelData)
              }
            }
          }
        }

        // Results
        Item {
          id: results
          width: parent.width
          height: parent.height - y - footer.height - Style.spacing.lg

          GridView {
            id: grid
            anchors.fill: parent
            clip: true
            model: root.items
            cellWidth: Math.floor(width / root.columns)
            cellHeight: Style.space(128)
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
              id: cell
              required property int index
              required property var modelData

              readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex
              readonly property bool isBundle: !!modelData.bundle
              readonly property bool marked: root.isMarked(modelData)
              readonly property bool showInstalled: !!modelData.installed && !modelData.upd
              readonly property bool canLaunch: !!modelData.launch && showInstalled
              readonly property var warns: Model.warnings(modelData)

              width: grid.cellWidth
              height: grid.cellHeight

              Rectangle {
                id: tile
                anchors.fill: parent
                anchors.margins: Style.spacing.sm
                radius: root.cornerRadius
                color: cell.hasCursor ? root.selectedBackground : Util.alpha(root.foreground, 0.04)
                border.width: cell.marked || cell.hasCursor ? 1 : 0
                border.color: Util.alpha(root.accent, cell.marked ? 1 : 0.5)
                Behavior on color { ColorAnimation { duration: Style.duration(120) } }

                // App icon (from the icon theme when it exists), else a letter
                Rectangle {
                  id: icon
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.margins: Style.spacing.lg + 2
                  width: Style.space(44)
                  height: width
                  radius: Math.max(root.cornerRadius, Style.space(8))
                  color: Util.alpha(root.accent, 0.14)

                  Image {
                    id: iconImage
                    anchors.fill: parent
                    anchors.margins: Style.space(6)
                    source: cell.modelData.icon || ""
                    sourceSize: Qt.size(64, 64)
                    fillMode: Image.PreserveAspectFit
                    visible: status === Image.Ready
                  }

                  Rectangle {
                    visible: cell.warns.length > 0
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: -Style.space(4)
                    width: Style.space(18)
                    height: width
                    radius: width / 2
                    color: Commons.Color.urgent
                    z: 2

                    Text {
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: "!"
                      color: root.background
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                    }
                  }

                  Text {
                    anchors.centerIn: parent
                    visible: iconImage.status !== Image.Ready
                    textFormat: Text.PlainText
                    text: String(cell.modelData.label || cell.modelData.n).charAt(0).toUpperCase()
                    color: root.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.display
                    font.bold: true
                  }
                }

                Text {
                  id: nameText
                  anchors.left: icon.right
                  anchors.leftMargin: Style.spacing.lg
                  anchors.right: actionPill.left
                  anchors.rightMargin: Style.spacing.md
                  anchors.top: icon.top
                  textFormat: Text.PlainText
                  text: cell.modelData.label || cell.modelData.n
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  anchors.left: nameText.left
                  anchors.right: cell.canLaunch ? launchPill.left : parent.right
                  anchors.rightMargin: cell.canLaunch ? Style.spacing.md : Style.spacing.lg + 2
                  anchors.verticalCenter: cell.canLaunch ? launchPill.verticalCenter : undefined
                  anchors.top: cell.canLaunch ? undefined : actionPill.bottom
                  anchors.topMargin: Style.spacing.sm
                  textFormat: Text.PlainText
                  text: {
                    if (cell.modelData.meta) return cell.modelData.meta
                    var bits = []
                    if (cell.warns.length) bits.push("⚠ " + cell.warns.join(", "))
                    if (cell.modelData.upd) {
                      bits.push(cell.modelData.upd.replace(/(^|\s)\d+:/g, "$1"))
                      return bits.join("  ·  ")
                    }
                    // Launchable cards share this line with the Launch pill, so keep it short.
                    if (!cell.canLaunch) bits.push(cell.modelData.r)
                    if (cell.modelData.v) bits.push(cell.modelData.v.replace(/^\d+:/, ""))
                    if (cell.canLaunch) return bits.join("  ·  ")
                    var size = Model.formatSize(cell.modelData.s)
                    if (size) bits.push(size)
                    if (cell.modelData.votes) bits.push("★ " + cell.modelData.votes)
                    if (!cell.warns.length && cell.modelData.updated) bits.push(Model.ago(cell.modelData.updated))
                    return bits.join("  ·  ")
                  }
                  color: cell.warns.length ? Commons.Color.urgent : root.foreground
                  opacity: cell.warns.length ? 0.9 : 0.5
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }

                Text {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  anchors.margins: Style.spacing.lg + 2
                  textFormat: Text.PlainText
                  text: cell.modelData.d
                  color: root.foreground
                  opacity: 0.78
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  wrapMode: Text.WordWrap
                  maximumLineCount: 2
                  elide: Text.ElideRight
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  acceptedButtons: Qt.LeftButton | Qt.RightButton
                  cursorShape: Qt.PointingHandCursor
                  onContainsMouseChanged: if (containsMouse) {
                    root.cursorActive = true
                    root.selectedIndex = cell.index
                  }
                  onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) root.openDetails(cell.modelData)
                    else root.toggleMark(cell.modelData)
                  }
                }

                // Action pill: Install, Installed (turns into Remove on hover)
                Rectangle {
                  id: actionPill
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: Style.spacing.lg + 2
                  width: pillText.implicitWidth + Style.spacing.lg * 2
                  height: Style.font.bodySmall + Style.spacing.md * 2
                  radius: height / 2
                  color: {
                    if (cell.showInstalled)
                      return pillMouse.containsMouse && !cell.isBundle ? Util.alpha(Commons.Color.urgent, 0.25) : "transparent"
                    return pillMouse.containsMouse ? root.accent : Util.alpha(root.accent, cell.marked ? 0.45 : 0.18)
                  }
                  border.width: 1
                  border.color: cell.showInstalled
                    ? Util.alpha(pillMouse.containsMouse && !cell.isBundle ? Commons.Color.urgent : root.foreground, 0.5)
                    : Util.alpha(root.accent, 0.8)
                  Behavior on color { ColorAnimation { duration: Style.duration(120) } }

                  Text {
                    id: pillText
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: cell.showInstalled
                      ? (pillMouse.containsMouse && !cell.isBundle ? "Remove" : "Installed")
                      : (cell.modelData.upd ? "Update" : (cell.marked ? "Queued" : (cell.isBundle ? "Install all" : "Install")))
                    color: cell.showInstalled
                      ? (pillMouse.containsMouse && !cell.isBundle ? Commons.Color.urgent : root.foreground)
                      : (pillMouse.containsMouse ? root.background : root.accent)
                    opacity: cell.showInstalled && !(pillMouse.containsMouse && !cell.isBundle) ? 0.65 : 1
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                  }

                  MouseArea {
                    id: pillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (cell.modelData.upd) root.runUpdate()
                      else if (cell.modelData.installed) root.removeItem(cell.modelData)
                      else root.installOne(cell.modelData)
                    }
                  }
                }

                // Launch pill for installed apps that have a desktop entry
                Rectangle {
                  id: launchPill
                  visible: cell.canLaunch
                  anchors.right: parent.right
                  anchors.rightMargin: Style.spacing.lg + 2
                  anchors.top: actionPill.bottom
                  anchors.topMargin: Style.spacing.sm
                  width: launchText.implicitWidth + Style.spacing.lg * 2
                  height: Style.font.bodySmall + Style.spacing.md * 2
                  radius: height / 2
                  color: launchMouse.containsMouse ? root.accent : Util.alpha(root.accent, 0.18)
                  border.width: 1
                  border.color: Util.alpha(root.accent, 0.8)
                  Behavior on color { ColorAnimation { duration: Style.duration(120) } }

                  Text {
                    id: launchText
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: "Launch"
                    color: launchMouse.containsMouse ? root.background : root.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                  }

                  MouseArea {
                    id: launchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.launchItem(cell.modelData)
                  }
                }
              }
            }
          }

          // Empty and loading states
          Column {
            anchors.centerIn: parent
            spacing: Style.spacing.md
            visible: root.items.length === 0

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              textFormat: Text.PlainText
              text: !root.repoLoaded ? "Reading package databases…"
                  : (root.category === "Updates" && root.filterText === ""
                     ? (root.updatesBusy ? "Checking for updates…" : "Everything is up to date")
                     : "No matches")
              color: root.foreground
              opacity: 0.75
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              visible: root.repoLoaded && root.filterText !== "" && !root.aurEnabled
              textFormat: Text.PlainText
              text: "Press Ctrl+A to include the AUR"
              color: root.accent
              opacity: 0.85
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
          }
        }

        // Footer: key hints and the install queue
        Item {
          id: footer
          width: parent.width
          height: Math.max(Style.font.body + Style.spacing.md * 2, Style.space(30))

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: aboutButton.left
            anchors.rightMargin: Style.spacing.lg
            textFormat: Text.PlainText
            text: root.updateMode
              ? "↵ update all   ^I details   ^R recheck   ^S sort   ⇥ category   esc close"
              : "↵ install   Ins queue   Del remove   ^L launch   ^I details   ^S sort   ^A AUR   ⇥ category   esc close"
            color: root.foreground
            opacity: 0.5
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }

          Text {
            id: aboutButton
            anchors.right: queueButton.visible ? queueButton.left : parent.right
            anchors.rightMargin: Style.spacing.lg
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "About"
            color: root.accent
            opacity: aboutMouse.containsMouse ? 1 : 0.75
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true

            MouseArea {
              id: aboutMouse
              anchors.fill: parent
              anchors.margins: -Style.spacing.md
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.showAbout = true
            }
          }

          Rectangle {
            id: queueButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.basketCount > 0 || root.updateMode
            width: queueText.implicitWidth + Style.spacing.lg * 3
            height: parent.height
            radius: height / 2
            color: queueMouse.containsMouse ? root.accent : Util.alpha(root.accent, 0.25)
            Behavior on color { ColorAnimation { duration: Style.duration(120) } }

            Text {
              id: queueText
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: root.updateMode ? "Update all " + root.updatesCount
                                    : "Install " + root.basketCount + (root.basketCount === 1 ? " app" : " apps")
              color: queueMouse.containsMouse ? root.background : root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            MouseArea {
              id: queueMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.installBasketOrCurrent()
            }
          }
        }
      }

      // Detail view
      Rectangle {
        anchors.fill: parent
        anchors.margins: -root.pad
        radius: root.cornerRadius
        color: root.background
        visible: opacity > 0
        opacity: root.showDetail ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Style.duration(150); easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent; onClicked: root.closeDetails() }

        Column {
          id: detailColumn
          anchors.centerIn: parent
          spacing: Style.spacing.lg
          width: Math.min(parent.width - root.pad * 4, Style.space(680))

          Row {
            spacing: Style.spacing.lg
            width: parent.width

            Rectangle {
              id: detailIcon
              width: Style.space(56)
              height: width
              radius: Math.max(root.cornerRadius, Style.space(10))
              color: Util.alpha(root.accent, 0.16)
              border.width: 1
              border.color: Util.alpha(root.accent, 0.6)

              Image {
                id: detailImage
                anchors.fill: parent
                anchors.margins: Style.space(8)
                source: root.detailItem && root.detailItem.icon ? root.detailItem.icon : ""
                sourceSize: Qt.size(96, 96)
                fillMode: Image.PreserveAspectFit
                visible: status === Image.Ready
              }

              Text {
                anchors.centerIn: parent
                visible: detailImage.status !== Image.Ready
                textFormat: Text.PlainText
                text: root.detailItem ? String(root.detailItem.label || root.detailItem.n).charAt(0).toUpperCase() : ""
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.displayLarge
                font.bold: true
              }
            }

            Column {
              width: parent.width - detailIcon.width - Style.spacing.lg
              anchors.verticalCenter: detailIcon.verticalCenter
              spacing: Style.spacing.sm

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: root.detailItem ? (root.detailItem.label || root.detailItem.n) : ""
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.displayLarge
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: root.detailItem ? root.detailItem.p + (root.detailItem.installed ? "   ·   installed" : "") : ""
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }
            }
          }

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: root.detailItem ? ((root.detailInfo && root.detailInfo.d) || root.detailItem.d) : ""
            color: root.foreground
            opacity: 0.85
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          // AUR trust signals
          Rectangle {
            readonly property var warns: Model.warnings(root.detailInfo || root.detailItem)
            visible: warns.length > 0
            width: parent.width
            height: warnText.implicitHeight + Style.spacing.lg * 2
            radius: root.cornerRadius
            color: Util.alpha(Commons.Color.urgent, 0.12)
            border.width: 1
            border.color: Util.alpha(Commons.Color.urgent, 0.6)

            Text {
              id: warnText
              anchors.fill: parent
              anchors.margins: Style.spacing.lg
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: {
                var w = parent.warns
                var bits = []
                if (w.indexOf("out of date") >= 0) bits.push("flagged out of date by users")
                if (w.indexOf("orphaned") >= 0) bits.push("has no maintainer")
                if (w.indexOf("stale") >= 0) bits.push("not updated for over two years")
                return "⚠ Be careful: this AUR package is " + bits.join(", ") + ". Read its PKGBUILD before installing."
              }
              color: Commons.Color.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          Column {
            width: parent.width
            spacing: Style.spacing.sm

            Text {
              visible: root.detailBusy && !root.detailInfo
              textFormat: Text.PlainText
              text: "Loading details…"
              color: root.foreground
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            Repeater {
              model: root.showDetail ? root.detailRows() : []

              delegate: Row {
                required property var modelData
                width: detailColumn.width
                spacing: Style.spacing.lg

                Text {
                  width: Style.space(130)
                  textFormat: Text.PlainText
                  text: parent.modelData.k
                  color: root.foreground
                  opacity: 0.5
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Text {
                  width: parent.width - Style.space(130) - Style.spacing.lg
                  wrapMode: Text.WordWrap
                  maximumLineCount: 3
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  text: parent.modelData.v
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: (root.detailItem && root.detailItem.upd ? "↵ update all   " : (root.detailItem && !root.detailItem.installed ? "↵ install   " : ""))
                  + (root.detailItem && root.detailItem.installed ? "Del remove   " : "")
                  + (root.detailItem && root.detailItem.launch ? "^L launch   " : "")
                  + (root.detailInfo && root.detailInfo.url ? "^O homepage   " : "") + "esc back"
            color: root.foreground
            opacity: 0.5
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      // About view
      Rectangle {
        anchors.fill: parent
        anchors.margins: -root.pad
        radius: root.cornerRadius
        color: Util.alpha(root.background, 0.96)
        visible: opacity > 0
        opacity: root.showAbout ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Style.duration(150); easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent; onClicked: root.showAbout = false }

        Column {
          anchors.centerIn: parent
          spacing: Style.spacing.lg
          width: Math.min(parent.width - root.pad * 4, Style.space(460))

          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(72)
            height: width
            radius: Math.max(root.cornerRadius, Style.space(14))
            color: Util.alpha(root.accent, 0.16)
            border.width: 1
            border.color: Util.alpha(root.accent, 0.6)

            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: "H"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge + 8
              font.bold: true
            }
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: "Hangar Store"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: "Version " + ((root.manifest && root.manifest.version) || "1.2.1")
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: "A themed app store for Omarchy. Browse, search and install apps from your repositories and, if you choose, the AUR."
            color: root.foreground
            opacity: 0.8
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: "Made by Peter Vinter"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: "MIT License  ·  Esc to go back"
            color: root.foreground
            opacity: 0.5
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
