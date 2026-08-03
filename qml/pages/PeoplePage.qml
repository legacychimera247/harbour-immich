import QtQuick 2.0
import Sailfish.Silica 1.0
import QtGraphicalEffects 1.0
import "../components"
import "../components/FilterHelper.js" as FilterHelper

Page {
    id: page

    property var peopleModel: []
    property bool loading: true
    property string filterText: ""
    property int initialLimit: 12
    property bool expanded: false

    property var filteredModel: FilterHelper.filterByField(peopleModel, filterText, "name")

    property var displayModel: {
        if (expanded || filteredModel.length <= initialLimit) return filteredModel
        return filteredModel.slice(0, initialLimit)
    }

    signal requestViewportCheck()

    function refresh() {
        loading = true
        immichApi.fetchPeople()
    }

    Timer {
        id: viewportCheckTimer
        interval: 50
        onTriggered: page.requestViewportCheck()
    }

    SilicaFlickable {
        id: flickable
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                //% "Refresh"
                text: qsTrId("pullDownMenu.refresh")
                onClicked: page.refresh()
            }
        }

        Column {
            id: column
            width: parent.width

            PageHeader {
                //% "People"
                title: qsTrId("peoplePage.people")
            }

            SearchField {
                width: parent.width
                visible: peopleModel.length > 6
                //% "Filter by name..."
                placeholderText: qsTrId("peoplePage.filter")

                onTextChanged: {
                    page.filterText = text
                    viewportCheckTimer.restart()
                }

                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }

            // People grid
            Flow {
                id: peopleGrid
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                spacing: Theme.paddingMedium
                visible: !page.loading

                property int itemSize: (width - 2 * Theme.paddingMedium) / 3

                Repeater {
                    id: peopleRepeater
                    model: page.displayModel

                    BackgroundItem {
                        id: personDelegate
                        width: peopleGrid.itemSize
                        height: peopleGrid.itemSize + Theme.paddingMedium + Theme.fontSizeSmall

                        property bool thumbnailTriggered: false

                        function checkViewport() {
                            if (thumbnailTriggered || !visible) return
                            var mapped = mapToItem(flickable.contentItem, 0, 0)
                            var itemY = mapped.y
                            if (itemY + height > flickable.contentY - height && itemY < flickable.contentY + flickable.height + height) {
                                thumbnailTriggered = true
                            }
                        }

                        Connections {
                            target: flickable
                            onContentYChanged: personDelegate.checkViewport()
                        }

                        Connections {
                            target: page
                            onRequestViewportCheck: personDelegate.checkViewport()
                        }

                        onVisibleChanged: if (visible) checkViewport()

                        Column {
                            anchors.fill: parent
                            spacing: Theme.paddingSmall

                            Item {
                                width: peopleGrid.itemSize
                                height: peopleGrid.itemSize

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Theme.secondaryColor
                                    radius: width / 2
                                }

                                Image {
                                    id: personImage
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: personDelegate.thumbnailTriggered && modelData.id ? "image://immich/person/" + modelData.id : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Item {
                                            width: personImage.width
                                            height: personImage.height
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: width / 2
                                            }
                                        }
                                    }
                                }

                                Label {
                                    anchors.centerIn: parent
                                    text: ((modelData.name || "?").charAt(0)).toUpperCase()
                                    font.pixelSize: Theme.fontSizeHuge
                                    color: Theme.secondaryColor
                                    visible: !modelData.thumbnailPath
                                }
                            }

                            Label {
                                width: peopleGrid.itemSize
                                //% "Unknown"
                                text: modelData.name || qsTrId("peoplePage.unknown")
                                font.pixelSize: Theme.fontSizeExtraSmall
                                truncationMode: TruncationMode.Fade
                                horizontalAlignment: Text.AlignHCenter
                                color: parent.parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                            }
                        }

                        onClicked: {
                            pageStack.push(Qt.resolvedUrl("PersonDetailPage.qml"), {
                                personId: modelData.id,
                                personName: modelData.name || "",
                                personBirthDate: modelData.birthDate || "",
                                thumbnailPath: modelData.thumbnailPath || ""
                            })
                        }
                    }
                }
            }

            // Show more / Show less button
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: page.filteredModel.length > page.initialLimit
                text: page.expanded
                    //% "Show less"
                    ? qsTrId("peoplePage.showLess")
                    //% "Show more (%1 more)"
                    : qsTrId("peoplePage.showMore").arg(page.filteredModel.length - page.initialLimit)
                onClicked: {
                    page.expanded = !page.expanded
                    viewportCheckTimer.restart()
                }
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }
        }

        VerticalScrollDecorator {}
    }

    // Loading
    LoadingIndicator {
        anchors.fill: flickable
        loading: page.loading && peopleModel.length === 0
        //% "Loading people..."
        message: qsTrId("peoplePage.loading")
    }

    // Empty state
    EmptyState {
        anchors.fill: flickable
        visible: !page.loading && peopleModel.length === 0
        iconSource: "image://theme/icon-m-people"
        //% "No people found"
        message: qsTrId("peoplePage.noPeople")
    }

    Component.onCompleted: page.refresh()

    Connections {
        target: immichApi
        onPersonUpdated: page.refresh()
        onPeopleReceived: {
            var result = []
            for (var i = 0; i < people.length; i++) {
                var p = people[i]
                result.push({
                    id: p.id || "",
                    name: p.name || "",
                    birthDate: p.birthDate || "",
                    thumbnailPath: p.thumbnailPath || ""
                })
            }
            // Sort named first, then unnamed
            result.sort(function(a, b) {
                if (a.name && !b.name) return -1
                if (!a.name && b.name) return 1
                return (a.name || "").localeCompare(b.name || "")
            })
            page.peopleModel = result
            page.loading = false
            viewportCheckTimer.restart()
        }
    }
}
