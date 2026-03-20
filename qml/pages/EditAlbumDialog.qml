import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
  id: dialog

  property string albumId
  property string albumName
  property string albumDescription
  property bool isActivityEnabled: true
  property string albumThumbnailAssetId: ""
  property var albumAssets: []
  property string selectedThumbnailAssetId: albumThumbnailAssetId
  // 3 and half images on the line so that it points to allowed horizontal scrolling
  property real thumbnailSize: Math.max(Theme.itemSizeLarge, Math.floor((width - 2 * Theme.horizontalPageMargin) / 3.5))

  canAccept: nameField.text.length > 0

  onAccepted: {
      immichApi.updateAlbum(albumId, nameField.text, descriptionField.text, activitySwitch.checked, selectedThumbnailAssetId)
  }

  SilicaFlickable {
      anchors.fill: parent
      contentHeight: column.height

      Column {
          id: column
          width: parent.width

          DialogHeader {
              //% "Edit Album"
              title: qsTrId("editAlbumDialog.editAlbum")
              //% "Save"
              acceptText: qsTrId("editAlbumDialog.save")
          }

          TextField {
              id: nameField
              width: parent.width
              //% "Album name"
              label: qsTrId("editAlbumDialog.albumName")
              placeholderText: label
              text: dialog.albumName

              EnterKey.iconSource: "image://theme/icon-m-enter-next"
              EnterKey.onClicked: descriptionField.focus = true
          }

          TextArea {
              id: descriptionField
              width: parent.width
              //% "Description"
              label: qsTrId("editAlbumDialog.description")
              placeholderText: label
              text: dialog.albumDescription
          }

          TextSwitch {
              id: activitySwitch
              //% "Comments and likes"
              text: qsTrId("editAlbumDialog.commentsAndLikes")
              //% "Allow comments and likes on this album"
              description: qsTrId("editAlbumDialog.commentsAndLikesInfo")
              checked: dialog.isActivityEnabled
          }

          Label {
              x: Theme.horizontalPageMargin
              width: parent.width - 2 * Theme.horizontalPageMargin
              //% "Album thumbnail"
              text: qsTrId("editAlbumDialog.albumThumbnail")
              font.pixelSize: Theme.fontSizeLarge
              visible: dialog.albumAssets.length > 0
          }

          ListView {
              id: thumbnailList
              x: Theme.horizontalPageMargin
              width: parent.width - 2 * Theme.horizontalPageMargin
              height: dialog.albumAssets.length > 0 ? dialog.thumbnailSize : 0
              orientation: ListView.Horizontal
              spacing: Theme.paddingSmall
              clip: true
              model: dialog.albumAssets
              visible: dialog.albumAssets.length > 0

              delegate: BackgroundItem {
                  width: dialog.thumbnailSize
                  height: dialog.thumbnailSize
                  highlighted: dialog.selectedThumbnailAssetId === (modelData && modelData.id ? modelData.id : "")

                  onClicked: {
                      if (modelData && modelData.id) {
                          dialog.selectedThumbnailAssetId = modelData.id
                      }
                  }

                  Image {
                      id: thumbnailImage
                      anchors.fill: parent
                      fillMode: Image.PreserveAspectCrop
                      source: modelData && modelData.id ? "image://immich/thumbnail/" + modelData.id : ""
                      asynchronous: true

                      Rectangle {
                          anchors.fill: parent
                          color: Theme.rgba(Theme.highlightBackgroundColor, 0.2)
                          visible: thumbnailImage.status !== Image.Ready
                      }

                      Image {
                          anchors.centerIn: parent
                          source: "image://theme/icon-m-image"
                          visible: thumbnailImage.status !== Image.Ready
                      }
                  }

                  Rectangle {
                      anchors.fill: parent
                      color: "transparent"
                      border.width: dialog.selectedThumbnailAssetId === (modelData && modelData.id ? modelData.id : "") ? 2 : 0
                      border.color: Theme.highlightColor
                  }
              }
          }
      }

      VerticalScrollDecorator {}
  }
}
