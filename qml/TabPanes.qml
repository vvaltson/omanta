import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Omanta.Runtime

// One tab slot: a single Tab, or two side by side while split view (F3) is
// on. The window's chrome talks to `activePane` — whichever pane last took a
// press or was handed the keyboard with F6 — so the toolbar, path bar, status
// line, shortcuts and menus all follow the split without knowing about it.
FocusScope {
    id: slot

    property string initialPath: ""
    property string initialSelection: ""

    property bool split: false
    // The two panes swap roles: `primary` is the one left when the split
    // closes and always sits on the left; `secondary` loads on the right.
    property PaneLoader primary: firstLoader
    readonly property PaneLoader secondary: primary === firstLoader ? secondLoader : firstLoader
    property Item activePane: primary.item ? primary.item.tab : null
    readonly property int activePaneIndex: split && secondary.item
                                           && activePane === secondary.item.tab ? 1 : 0

    signal contextMenuRequested()
    signal mountNeeded(string location)
    signal transferRequested(var sources, string destination, bool isMove)
    signal previewUnavailable()

    function setActive(pane) {
        if (activePane !== pane)
            activePane = pane;
    }

    function toggleSplit() {
        if (!split) {
            // The second pane opens where the user is now — a snapshot, not a
            // binding: from here the two navigate independently.
            secondary.spawnPath = activePane.path;
            secondary.spawnSelection = "";
            split = true;
        } else {
            // The pane being worked in stays, history and all; the other closes.
            if (secondary.item && activePane === secondary.item.tab) {
                splitView.moveItem(1, 0);
                primary = secondary;
            }
            split = false;
        }
        activePane.forceActiveFocus();
    }

    function cyclePane() {
        if (!split || !secondary.item)
            return;
        activePane = activePane === primary.item.tab ? secondary.item.tab
                                                     : primary.item.tab;
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

    component PaneLoader: Loader {
        id: loader

        property string spawnPath: ""
        property string spawnSelection: ""

        SplitView.fillWidth: slot.primary === loader
        SplitView.preferredWidth: slot.width / 2
        SplitView.minimumWidth: 220
        active: slot.split || slot.primary === loader
        visible: active
        sourceComponent: PaneCell {
            focus: true
            startPath: loader.spawnPath
            startSelection: loader.spawnSelection
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

        PaneLoader {
            id: firstLoader

            focus: true
            spawnPath: slot.initialPath
            spawnSelection: slot.initialSelection
        }

        PaneLoader {
            id: secondLoader
        }
    }
}
