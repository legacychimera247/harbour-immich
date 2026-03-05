import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    property string albumId
    property var existingUserIds: []
    property var selectedUserIds: []

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            PageHeader {
                //% "Add Users"
                title: qsTrId("userPickerPage.title")
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                size: BusyIndicatorSize.Large
                running: userListModel.count === 0 && !noUsersLabel.visible
                visible: running
            }

            Label {
                id: noUsersLabel
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - Theme.horizontalPageMargin * 2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Theme.secondaryHighlightColor
                //% "No users available to add"
                text: qsTrId("userPickerPage.noUsers")
                visible: false
            }

            Repeater {
                id: userRepeater
                model: ListModel { id: userListModel }

                BackgroundItem {
                    id: userItem
                    width: parent.width
                    height: Theme.itemSizeMedium

                    property bool isSelected: page.selectedUserIds.indexOf(model.userId) > -1

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.rightMargin: Theme.horizontalPageMargin
                        spacing: Theme.paddingMedium

                        Image {
                            id: avatarIcon
                            width: Theme.iconSizeMedium
                            height: Theme.iconSizeMedium
                            anchors.verticalCenter: parent.verticalCenter
                            source: "image://theme/icon-m-contact"

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "transparent"
                                border.width: userItem.isSelected ? 2 : 0
                                border.color: Theme.highlightColor
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - avatarIcon.width - checkIcon.width - Theme.paddingMedium * 2

                            Label {
                                width: parent.width
                                text: model.name
                                color: userItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: model.email
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                                truncationMode: TruncationMode.Fade
                            }
                        }

                        Icon {
                            id: checkIcon
                            width: Theme.iconSizeSmall
                            height: Theme.iconSizeSmall
                            anchors.verticalCenter: parent.verticalCenter
                            source: "image://theme/icon-s-installed"
                            visible: userItem.isSelected
                        }
                    }

                    onClicked: {
                        var idx = page.selectedUserIds.indexOf(model.userId)
                        if (idx > -1) {
                            page.selectedUserIds.splice(idx, 1)
                        } else {
                            page.selectedUserIds.push(model.userId)
                        }
                        page.selectedUserIds = page.selectedUserIds
                    }
                }
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                //% "Add selected users"
                text: qsTrId("userPickerPage.addSelected")
                enabled: page.selectedUserIds.length > 0
                onClicked: {
                    immichApi.addUsersToAlbum(page.albumId, page.selectedUserIds)
                }
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }
        }

        VerticalScrollDecorator {}
    }

    Component.onCompleted: {
        immichApi.fetchUsers()
    }

    Connections {
        target: immichApi
        onUsersReceived: {
            userListModel.clear()
            var count = 0
            for (var i = 0; i < users.length; i++) {
                var user = users[i]
                var userId = user.id || ""
                // Skip users already in album
                if (page.existingUserIds.indexOf(userId) > -1) {
                    continue
                }
                userListModel.append({
                    userId: userId,
                    name: user.name || "",
                    email: user.email || ""
                })
                count++
            }
            noUsersLabel.visible = (count === 0)
        }
        onUsersAddedToAlbum: {
            if (albumId === page.albumId) {
                pageStack.pop()
            }
        }
    }
}
