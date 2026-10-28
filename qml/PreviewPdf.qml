import QtQuick
import QtQuick.Pdf

// Its own file, loaded by URL: QtQuick.Pdf ships with qt6-webengine, an
// optional dependency, and a missing import then fails only this Loader
// rather than the whole preview pane.
PdfMultiPageView {
    id: view

    property url url
    readonly property bool failed: pdf.status === PdfDocument.Error

    // A whole page always in view, at any pane size. The margins leave room
    // for the view's scrollbar and keep the page's edges visible.
    function fit() {
        if (pdf.status !== PdfDocument.Ready || width <= 24 || height <= 12)
            return;
        const page = pdf.pagePointSize(0);
        renderScale = Math.min((width - 24) / page.width, (height - 12) / page.height);
    }

    onWidthChanged: fit()
    onHeightChanged: fit()

    document: PdfDocument {
        id: pdf
        source: view.url
        onStatusChanged: view.fit()
    }
}
