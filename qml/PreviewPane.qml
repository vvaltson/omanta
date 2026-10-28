import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Omanta.Runtime

// The preview pane (F4): the active pane's file, picked by Space's rule — the
// one selected item, or the cursor row with nothing selected. Images, PDFs
// and anything that is not binary show their content; everything else, and
// anything not on a local disk, gets a card with its thumbnail or icon.
Rectangle {
    id: root

    objectName: "previewPane"

    property Item tab: null
    // A longer file shows its start; the header says so.
    readonly property int textLimit: 256 * 1024

    readonly property var item: {
        const row = tab ? tab.previewRow() : -1;
        if (row < 0 || row >= tab.files.count)
            return null;
        const files = tab.files;
        return {
            path: tab.actionPathAt(row),
            name: files.valueAt(row, "displayName"),
            isDir: files.valueAt(row, "isDir"),
            contentType: files.valueAt(row, "contentType"),
            typeDescription: files.valueAt(row, "typeDescription"),
            size: files.valueAt(row, "size"),
            modified: files.valueAt(row, "modified"),
            iconSource: files.valueAt(row, "iconSource"),
            itemCount: files.valueAt(row, "itemCount")
        };
    }
    readonly property bool isFile: item !== null && !item.isDir && Platform.isLocal(item.path)
    readonly property bool isImage: isFile && item.contentType.startsWith("image/")
    readonly property bool isPdf: isFile && item.contentType === "application/pdf"
    readonly property var text: isFile && !isImage && !isPdf
                                ? Platform.textPreview(item.path, textLimit) : ({})
    // What shows: "image", "pdf", "text", "card", or "" with nothing to preview.
    // An image or PDF that will not load drops to the card.
    readonly property string kind: !item ? ""
        : isImage && image.status !== Image.Error ? "image"
        : isPdf && pdfLoader.status !== Loader.Error && !(pdfLoader.item && pdfLoader.item.failed) ? "pdf"
        : text.text !== undefined ? "text"
        : "card"

    color: Colors.window

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Named like a split pane's header.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            color: Colors.chrome

            Text {
                textFormat: Text.PlainText
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: Text.AlignVCenter
                text: !root.item ? qsTr("Preview")
                    : root.kind === "text" && root.text.truncated
                      ? qsTr("%1 — first %2").arg(root.item.name).arg(Platform.formatSize(root.textLimit))
                      : root.item.name
                color: Colors.textDim
                font.pixelSize: 12
                elide: Text.ElideMiddle
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Colors.border
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Image {
                id: image

                anchors.centerIn: parent
                // Never blown up past its own size, only shrunk to fit.
                width: Math.min(implicitWidth, parent.width - 24)
                height: Math.min(implicitHeight, parent.height - 24)
                visible: root.kind === "image"
                source: root.isImage ? Platform.fileUrl(root.item.path) : ""
                // Decoded no bigger than a pane needs, not at a camera's 50 MP;
                // an SVG renders at this size instead of its tiny nominal one.
                sourceSize: Qt.size(2048, 2048)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                autoTransform: true
                mipmap: true
                cache: false
            }

            Loader {
                id: pdfLoader

                anchors.fill: parent
                active: root.isPdf
                visible: root.kind === "pdf"
                source: "PreviewPdf.qml"
                onLoaded: item.url = Qt.binding(() => root.isPdf ? Platform.fileUrl(root.item.path) : "")
            }

            ScrollView {
                id: textView

                anchors.fill: parent
                visible: root.kind === "text"
                contentWidth: availableWidth

                TextArea {
                    readOnly: true
                    // The keyboard stays with the file list, so the arrows
                    // keep stepping through files while this follows.
                    activeFocusOnPress: false
                    textFormat: TextEdit.PlainText
                    wrapMode: TextEdit.Wrap
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: Colors.text
                    background: null
                    text: root.kind === "text" ? root.text.text : ""
                    onTextChanged: textView.ScrollBar.vertical.position = 0
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 24, 384)
                visible: root.kind === "card"
                spacing: 8

                Image {
                    id: cardImage

                    // The views' thumbnail rule, so Preferences → thumbnails
                    // holds here too; a failed thumbnail falls back to the icon.
                    property string failedSource: ""
                    readonly property string thumbnailSource: root.item
                        ? Thumbnails.source(root.item.path, root.item.modified, root.item.size) : ""
                    readonly property bool wantThumbnail: root.item !== null && !root.item.isDir
                        && thumbnailSource !== failedSource
                        && Settings.showThumbnails !== "never"
                        && (Settings.showThumbnails === "always" || Platform.isLocal(root.item.path))
                        && Thumbnails.canThumbnail(root.item.contentType, root.item.size)

                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(parent.width, 384)
                    Layout.preferredHeight: Layout.preferredWidth
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize: Qt.size(512, 512)
                    source: !root.item ? ""
                        : wantThumbnail ? thumbnailSource
                        : Colors.fileIcon(root.item.iconSource,
                                          root.item.isDir ? Colors.accent : Colors.textDim, 512)
                    onStatusChanged: if (status === Image.Error && wantThumbnail) failedSource = thumbnailSource
                }

                Text {
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.item ? root.item.name : ""
                    color: Colors.text
                    font.pixelSize: 14
                    wrapMode: Text.WrapAnywhere
                }

                Text {
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: !root.item ? ""
                        : root.item.typeDescription + " · "
                          + (root.item.isDir ? Platform.formatItemCount(root.item.itemCount)
                                             : Platform.formatSize(root.item.size))
                    color: Colors.textDim
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }
            }

            Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                visible: root.kind === ""
                text: qsTr("Select a file to preview it")
                color: Colors.textDim
                font.pixelSize: 13
            }
        }
    }
}
