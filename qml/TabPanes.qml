import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Omanta.Runtime

// One tab slot: a single Tab, or two side by side while split view (F3) is
// on. The window's chrome talks to `activePane` — whichever pane last took a
// press or was handed the keyboard with F6 — so the toolbar, path bar, status
// line, shortcuts and menus all follow the split without knowing about it.
// The preview (F4) shows the active pane's file in the other half: in place
// of the inactive pane while split, else on the right.
FocusScope {
    id: slot

    property string initialPath: ""
    property string initialSelection: ""

    property bool split: false
    // The two panes swap roles: `primary` is the one left when the split
    // closes and always sits on the left; `secondary` loads on the right.
    property PaneColumn primary: firstColumn
    readonly property PaneColumn secondary: primary === firstColumn ? secondColumn : firstColumn
    property Item activePane: primary.tab
    readonly property int activePaneIndex: split && secondary.tab
                                           && activePane === secondary.tab ? 1 : 0
    property bool preview: false
    readonly property PaneColumn previewColumn: split && activePane === secondary.tab ? primary : secondary

    signal contextMenuRequested()
    signal mountNeeded(string location)
    signal transferRequested(var sources, string destination, bool isMove)
    signal previewUnavailable()

    function setActive(pane) {
        if (activePane !== pane)
            activePane = pane;
    }

    function toggleSplit() {
        // Over the preview, F3 means the split instead: the preview gives way
        // to the pane it was covering, or to a new one.
        const replacingPreview = preview;
        preview = false;
        if (!split) {
            // The second pane opens where the user is now — a snapshot, not a
            // binding: from here the two navigate independently.
            secondary.spawnPath = activePane.path;
            secondary.spawnSelection = "";
            split = true;
        } else if (!replacingPreview) {
            // The pane being worked in stays, history and all; the other closes.
            if (secondary.tab && activePane === secondary.tab) {
                splitView.moveItem(1, 0);
                primary = secondary;
            }
            split = false;
        }
        activePane.forceActiveFocus();
    }

    function cyclePane() {
        if (!split || !secondary.tab)
            return;
        activePane = activePane === primary.tab ? secondary.tab : primary.tab;
        activePane.forceActiveFocus();
    }

    function togglePreview() {
        preview = !preview;
        activePane.forceActiveFocus();
    }

    // A pane: the Tab plus, while split, a slim header naming its folder.
    // With one shared path bar the headers are what tell the panes apart —
    // the accent underline marks the one the chrome acts on.
    component PaneCell: FocusScope {
        id: cell

        property alias tab: tab
        property string startPath: ""
        property string startSelection: ""
        readonly property bool isActive: slot.activePane === tab

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 26 : 0
                visible: slot.split
                color: Colors.chrome

                Text {
                    textFormat: Text.PlainText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: cell.tab.title
                    color: cell.isActive ? Colors.text : Colors.textDim
                    font.pixelSize: 12
                    elide: Text.ElideMiddle
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: cell.isActive ? 2 : 1
                    color: cell.isActive ? Colors.accent : Colors.border
                }
            }

            Tab {
                id: tab

                Layout.fillWidth: true
                Layout.fillHeight: true
                focus: true
                path: cell.startPath
                pendingSelection: cell.startSelection
                onContextMenuRequested: slot.contextMenuRequested()
                onMountNeeded: location => slot.mountNeeded(location)
                onTransferRequested: (sources, destination, isMove) =>
                    slot.transferRequested(sources, destination, isMove)
                onPreviewUnavailable: slot.previewUnavailable()
            }
        }

        // Any press in a pane makes it the one the chrome acts on, before
        // whatever was pressed handles the event. Declined presses fall
        // through untouched — clicks, drags and the rubber band never see
        // this MouseArea (the same overlay pattern as the rubber band).
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            z: 10
            onPressed: mouse => {
                slot.setActive(cell.tab);
                cell.tab.forceActiveFocus();
                mouse.accepted = false;
            }
        }
    }

    // One half of the slot: its pane, or the preview standing in for it. A
    // pane the preview covers stays loaded underneath and comes back as it was.
    component PaneColumn: FocusScope {
        id: column

        property string spawnPath: ""
        property string spawnSelection: ""
        readonly property Item tab: paneLoader.item ? paneLoader.item.tab : null
        readonly property bool showsPreview: slot.preview && slot.previewColumn === column

        SplitView.fillWidth: slot.primary === column
        SplitView.preferredWidth: slot.width / 2
        SplitView.minimumWidth: 220
        visible: paneLoader.active || showsPreview

        Loader {
            id: paneLoader

            anchors.fill: parent
            focus: true
            active: slot.split || slot.primary === column
            visible: !column.showsPreview
            sourceComponent: PaneCell {
                focus: true
                startPath: column.spawnPath
                startSelection: column.spawnSelection
            }
        }

        Loader {
            anchors.fill: parent
            active: column.showsPreview
            sourceComponent: PreviewPane {
                tab: slot.activePane
            }
        }
    }

    SplitView {
        id: splitView

        anchors.fill: parent
        orientation: Qt.Horizontal

        handle: Rectangle {
            id: splitHandle
            implicitWidth: 5
            color: Colors.chrome

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: splitHandle.SplitHandle.pressed ? 2 : 1
                height: parent.height
                color: splitHandle.SplitHandle.pressed || splitHandle.SplitHandle.hovered
                       ? Colors.accent : Colors.border
            }
        }

        PaneColumn {
            id: firstColumn

            focus: true
            spawnPath: slot.initialPath
            spawnSelection: slot.initialSelection
        }

        PaneColumn {
            id: secondColumn
        }
    }
}
