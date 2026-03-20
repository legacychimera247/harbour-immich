import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    property string albumId
    property var albumInfo   // full album details JSON
    property bool isOwner: albumInfo && albumInfo.owner && albumInfo.owner.id === authManager.userId

    // Add-user state
    property var selectedUserIds: []
    property string selectedRole: "editor"
    property bool usersLoaded: false

    // Cached full user list from server
    property var allUsers: []

    function rebuildMemberModel() {
        memberListModel.clear()
        var albumUsers = albumInfo && albumInfo.albumUsers ? albumInfo.albumUsers : []
        for (var i = 0; i < albumUsers.length; i++) {
            var au = albumUsers[i]
            var u = au.user
            if (!u) continue
            memberListModel.append({
                odUserId: u.id || "",
                odName: u.name || "",
                odEmail: u.email || "",
                odRole: au.role || "editor",
                odIsMe: (u.id || "") === authManager.userId
            })
        }
    }

    function rebuildAvailableModel() {
        userListModel.clear()
        // Build existing IDs from current albumInfo
        var existingIds = []
        var albumUsers = albumInfo && albumInfo.albumUsers ? albumInfo.albumUsers : []
        for (var i = 0; i < albumUsers.length; i++) {
            var u = albumUsers[i].user
            if (u && u.id) existingIds.push(u.id)
        }
        if (albumInfo && albumInfo.owner && albumInfo.owner.id)
            existingIds.push(albumInfo.owner.id)

        var count = 0
        for (var j = 0; j < allUsers.length; j++) {
            var user = allUsers[j]
            var userId = user.id || ""
            if (existingIds.indexOf(userId) > -1) continue
            userListModel.append({
                userId: userId,
                name: user.name || "",
                email: user.email || ""
            })
            count++
        }
        noUsersLabel.visible = (count === 0 && page.isOwner && page.usersLoaded)
    }

    function startRemoveUser(uid) {
        //% "Removing user"
        remorseItem.execute(qsTrId("editAlbumUsersDialog.removingUser"), function() {
            immichApi.removeAlbumUser(page.albumId, uid)
        })
    }

    function startLeaveAlbum() {
        //% "Leaving album"
        remorseItem.execute(qsTrId("editAlbumUsersDialog.leavingAlbum"), function() {
            immichApi.removeAlbumUser(page.albumId, authManager.userId)
        })
    }

    onAlbumInfoChanged: {
        rebuildMemberModel()
        if (usersLoaded) rebuildAvailableModel()
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: parent.width

            PageHeader {
                //% "Edit Users"
                title: qsTrId("editAlbumUsersDialog.title")
            }

            SectionHeader {
                //% "Album members"
                text: qsTrId("editAlbumUsersDialog.albumMembers")
                visible: memberListModel.count > 0
            }

            Repeater {
                model: ListModel { id: memberListModel }

                ListItem {
                    id: memberItem
                    contentHeight: Theme.itemSizeSmall
                    menu: page.isOwner ? memberContextMenu : null

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.rightMargin: Theme.horizontalPageMargin
                        spacing: Theme.paddingMedium

                        Image {
                            width: Theme.iconSizeMedium
                            height: Theme.iconSizeMedium
                            anchors.verticalCenter: parent.verticalCenter
                            source: "image://theme/icon-m-contact"
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Theme.iconSizeMedium - Theme.paddingMedium

                            Label {
                                width: parent.width
                                //% " (you)"
                                text: model.odName + (model.odIsMe ? qsTrId("editAlbumUsersDialog.you") : "")
                                color: memberItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: model.odRole === "editor"
                                    //% "Editor"
                                    ? qsTrId("editAlbumUsersDialog.roleEditor")
                                    //% "Viewer"
                                    : qsTrId("editAlbumUsersDialog.roleViewer")
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: memberItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                            }
                        }
                    }

                    Component {
                        id: memberContextMenu
                        ContextMenu {
                            MenuItem {
                                text: model.odRole === "editor"
                                    //% "Change to viewer"
                                    ? qsTrId("editAlbumUsersDialog.changeToViewer")
                                    //% "Change to editor"
                                    : qsTrId("editAlbumUsersDialog.changeToEditor")
                                onClicked: {
                                    var newRole = model.odRole === "editor" ? "viewer" : "editor"
                                    immichApi.updateAlbumUserRole(page.albumId, model.odUserId, newRole)
                                }
                            }
                            MenuItem {
                                //% "Remove from album"
                                text: qsTrId("editAlbumUsersDialog.removeFromAlbum")
                                onClicked: {
                                    page.startRemoveUser(model.odUserId)
                                }
                            }
                        }
                    }
                }
            }

            // Leave album (non-owner)
            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeSmall
                visible: !page.isOwner && memberListModel.count > 0

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.rightMargin: Theme.horizontalPageMargin
                    spacing: Theme.paddingMedium

                    Image {
                        width: Theme.iconSizeMedium
                        height: Theme.iconSizeMedium
                        anchors.verticalCenter: parent.verticalCenter
                        source: "image://theme/icon-m-dismiss"
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        //% "Leave album"
                        text: qsTrId("editAlbumUsersDialog.leaveAlbum")
                        color: Theme.errorColor
                    }
                }

                onClicked: {
                    page.startLeaveAlbum()
                }
            }

            SectionHeader {
                //% "Add users"
                text: qsTrId("editAlbumUsersDialog.addUsersSection")
                visible: page.isOwner
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                size: BusyIndicatorSize.Medium
                running: !page.usersLoaded && page.isOwner
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
                text: qsTrId("editAlbumUsersDialog.noUsers")
                visible: false
            }

            Repeater {
                model: ListModel { id: userListModel }
                visible: page.isOwner

                BackgroundItem {
                    id: userItem
                    width: parent.width
                    height: Theme.itemSizeSmall
                    visible: page.isOwner

                    property bool isSelected: page.selectedUserIds.indexOf(model.userId) > -1

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.rightMargin: Theme.horizontalPageMargin
                        spacing: Theme.paddingMedium

                        Image {
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
                            width: parent.width - Theme.iconSizeMedium - checkIcon.width - Theme.paddingMedium * 2

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
                visible: page.isOwner && page.selectedUserIds.length > 0
            }

            ComboBox {
                width: parent.width
                visible: page.isOwner && page.selectedUserIds.length > 0
                //% "Role"
                label: qsTrId("editAlbumUsersDialog.role")
                currentIndex: page.selectedRole === "editor" ? 0 : 1

                menu: ContextMenu {
                    //% "Editor"
                    MenuItem { text: qsTrId("editAlbumUsersDialog.roleEditorOption") }
                    //% "Viewer"
                    MenuItem { text: qsTrId("editAlbumUsersDialog.roleViewerOption") }
                }

                onCurrentIndexChanged: {
                    page.selectedRole = currentIndex === 0 ? "editor" : "viewer"
                }
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: page.isOwner && page.selectedUserIds.length > 0
                //% "Add selected users"
                text: qsTrId("editAlbumUsersDialog.addSelected")
                enabled: page.selectedUserIds.length > 0
                onClicked: {
                    immichApi.addUsersToAlbum(page.albumId, page.selectedUserIds, page.selectedRole)
                }
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }
        }

        VerticalScrollDecorator {}
    }

    RemorsePopup {
        id: remorseItem
    }

    Component.onCompleted: {
        rebuildMemberModel()
        if (page.isOwner) {
            immichApi.fetchUsers()
        }
    }

    Connections {
        target: immichApi
        onUsersReceived: {
            // Cache all users, then rebuild available list
            var all = []
            for (var i = 0; i < users.length; i++) {
                all.push(users[i])
            }
            page.allUsers = all
            page.usersLoaded = true
            page.rebuildAvailableModel()
        }
        onUsersAddedToAlbum: {
            if (albumId === page.albumId) {
                page.selectedUserIds = []
                immichApi.fetchAlbumDetails(page.albumId)
            }
        }
        onAlbumUserRoleUpdated: {
            if (albumId === page.albumId) {
                immichApi.fetchAlbumDetails(page.albumId)
            }
        }
        onAlbumUserRemoved: {
            if (albumId === page.albumId) {
                if (!page.isOwner) {
                    pageStack.pop(pageStack.find(function(p) {
                        return p.objectName === "albumsPage" || p.objectName === "timelinePage"
                    }))
                } else {
                    immichApi.fetchAlbumDetails(page.albumId)
                }
            }
        }
        onAlbumDetailsReceived: {
            if (details.id === page.albumId) {
                page.albumInfo = details
            }
        }
    }
}
