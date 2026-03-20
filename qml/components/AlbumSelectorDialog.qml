import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: albumDialog
    property string selectedAlbumId: ""
    property bool createNew: false
    property string newAlbumName: ""
    property string activeAlbumFilter: "all"

    function applyAlbumFilter() {
        if (activeAlbumFilter === "shared") {
            immichApi.fetchAlbums("true")
        } else if (activeAlbumFilter === "mine") {
            immichApi.fetchAlbums("false")
        } else {
            immichApi.fetchAlbums()
        }
    }

    Component.onCompleted: applyAlbumFilter()

    canAccept: selectedAlbumId !== "" || (createNew && newAlbumName.length > 0)

    onAccepted: {
        if (createNew && newAlbumName.length > 0) {
            immichApi.createAlbum(newAlbumName, "")
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: albumColumn.height

        Column {
            id: albumColumn
            width: parent.width

            DialogHeader {
                //% "Select or create album"
                title: qsTrId("albumSelectorDialog.selectOrCreate")
            }

            // Create new album section
            SectionHeader {
                //% "Create new album"
                text: qsTrId("albumSelectorDialog.createNew")
            }

            TextField {
                id: newAlbumField
                width: parent.width
                //% "Album name"
                placeholderText: qsTrId("albumSelectorDialog.albumName")
                //% "New album name"
                label: qsTrId("albumSelectorDialog.newAlbumName")
                onTextChanged: {
                    albumDialog.newAlbumName = text
                    if (text.length > 0) {
                        albumDialog.createNew = true
                        albumDialog.selectedAlbumId = ""
                    } else {
                        albumDialog.createNew = false
                    }
                }
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: {
                    if (text.length > 0) {
                        albumDialog.accept()
                    }
                }
            }

            // Existing albums section
            SectionHeader {
                //% "Existing albums"
                text: qsTrId("albumSelectorDialog.existingAlbums")
                visible: albumModel.rowCount() > 0
            }

            // Album type filter row
            Item {
                width: parent.width
                height: Theme.itemSizeExtraSmall + Theme.paddingMedium
                visible: albumModel.rowCount() > 0

                Row {
                    id: selectorFilterRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.rightMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.paddingSmall

                    Repeater {
                        model: [
                            //% "All"
                            { id: "all", label: qsTrId("albumSelectorDialog.filterAll"), icon: "image://theme/icon-m-folder" },
                            //% "Shared with me"
                            { id: "shared", label: qsTrId("albumSelectorDialog.filterSharedWithMe"), icon: "image://theme/icon-m-share" },
                            //% "My albums"
                            { id: "mine", label: qsTrId("albumSelectorDialog.filterMyAlbums"), icon: "image://theme/icon-m-person" }
                        ]

                        BackgroundItem {
                            width: (selectorFilterRow.width - 2 * Theme.paddingSmall) / 3
                            height: Theme.itemSizeExtraSmall
                            highlighted: albumDialog.activeAlbumFilter === modelData.id

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.paddingSmall
                                color: albumDialog.activeAlbumFilter === modelData.id ? Theme.rgba(Theme.highlightBackgroundColor, 0.4) : Theme.rgba(Theme.highlightBackgroundColor, 0.1)
                                border.width: albumDialog.activeAlbumFilter === modelData.id ? 1 : 0
                                border.color: Theme.highlightColor
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.paddingSmall

                                Icon {
                                    source: modelData.icon
                                    width: Theme.iconSizeSmall
                                    height: Theme.iconSizeSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: albumDialog.activeAlbumFilter === modelData.id ? Theme.highlightColor : Theme.primaryColor
                                }

                                Label {
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    color: albumDialog.activeAlbumFilter === modelData.id ? Theme.highlightColor : Theme.primaryColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            onClicked: {
                                if (albumDialog.activeAlbumFilter !== modelData.id) {
                                    albumDialog.activeAlbumFilter = modelData.id
                                    albumDialog.applyAlbumFilter()
                                }
                            }
                        }
                    }
                }
            }

            Repeater {
                model: albumModel

                ListItem {
                    contentHeight: Theme.itemSizeMedium
                    highlighted: down || albumDialog.selectedAlbumId === albumId

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.paddingMedium

                        Icon {
                            source: "image://theme/icon-m-folder"
                            width: Theme.iconSizeMedium
                            height: Theme.iconSizeMedium
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            Label {
                                text: albumName
                                color: highlighted ? Theme.highlightColor : Theme.primaryColor
                            }

                            Label {
                                text: assetCount === 1
                                    //% "1 asset"
                                    ? qsTrId("albumSelectorDialog.asset")
                                    //% "%1 assets"
                                    : qsTrId("albumSelectorDialog.assets").arg(assetCount || 0)
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.secondaryColor
                            }
                        }
                    }

                    onClicked: {
                        albumDialog.selectedAlbumId = albumId
                        albumDialog.createNew = false
                        newAlbumField.text = ""
                        albumDialog.accept()
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                //% "No albums yet"
                text: qsTrId("albumSelectorDialog.noAlbums")
                color: Theme.secondaryColor
                visible: albumModel.rowCount() === 0
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }
        }

        VerticalScrollDecorator {}
    }
}
