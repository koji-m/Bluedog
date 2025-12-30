/*
 * Copyright (C) 2025  Koji Matsumoto
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * bluedog is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
import QtQuick 2.7
import QtQuick.Controls 2.2
import Lomiri.Components 1.3
import Lomiri.Content 1.1
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import Qt.labs.platform 1.0
import QtMultimedia 5.9
import Backend 1.0

MainView {
    id: root
    objectName: 'mainView'
    applicationName: 'bluedog.koji-m'
    automaticOrientation: true

    width: units.gu(45)
    height: units.gu(75)
    visible: true

    property bool backendReady: false
    property string dataDir: ""
    property string myDid: ""
    property string myHandle: ""
    property string myDisplayName: ""
    property string myAvatar: ""

    Backend {
        id: backend
        dataDir: root.dataDir
        onAgentInitialized: function(did) {
            getMyProfile(did)
        }
        onAgentInitializationFailed: function() {
            stack.push(signInPage, {}, {immediate: true})
        }
        onSignedIn: function(prof) {
            root.myDid = prof.did
            root.myHandle = prof.handle
            root.myDisplayName = prof.displayName
            root.myAvatar = prof.avatar
            signInSuccess()
            stack.clear()
            stack.push(timelinePage, {}, {immediate: true})
        }
        onMyProfileFetched: function(prof) {
            root.myDid = prof.did
            root.myHandle = prof.handle
            root.myDisplayName = prof.displayName
            root.myAvatar = prof.avatar
            stack.push(timelinePage, {}, {immediate: true})
        }
        onSignedOut: function() {
            root.myDid = ""
            root.myHandle = ""
            root.myDisplayName = ""
            root.myAvatar = ""
            stack.clear()
            stack.push(signInPage, {}, {immediate: true})
        }
        Component.onCompleted: {
            root.backendReady = true
        }
    }

    Page {
        id: splashPage
        anchors.fill: parent
        visible: !backendReady

        Rectangle {
            anchors.fill: parent
            color: "#1386DC"

            // Image {
            //     id: splashLogo
            //     anchors.centerIn: parent
            //     source: Qt.resolvedUrl('../assets/icon_splash.svg')
            //     width: parent.width * 0.3
            //     height: width
            //     fillMode: Image.PreserveAspectFit
            // }
        }
    }

    PageStack {
        id: stack
        anchors.fill: parent

        Component.onCompleted: {
            var loc = StandardPaths.writableLocation(StandardPaths.AppDataLocation);
            backend.dataDir = (loc && typeof loc.toLocalFile === "function") ? loc.toLocalFile() : (typeof loc === "string" ? loc : String(loc));
            backend.init()
        }
    }

    Component {
        id: signInPage
        SignInPage {
        }
    }
    Component {
        id: settingsPage
        SettingsPage {
            onSignOutRequested: function () {
                py.call('backend.sign_out', [], function (res) {
                    root.myDid = ""
                    root.myHandle = ""
                    root.myDisplayName = ""
                    root.myAvatar = ""
                    stack.clear()
                    stack.push(signInPage)
                }, function (err) {
                    errorLabel.text = "" + err
                })
            }
        }
    }
    Component {
        id: searchPage
        SearchPage {
            onImageClicked: function(imageUrl) {
                popupImage.source = imageUrl
                imagePopupBackground.visible = true
            }
            onVideoClicked: function(videoUrl) {
                popupVideo.source = videoUrl
                videoPopupBackground.visible = true
            }
            onPostClicked: function(post) {
                stack.push(postDetailPage, {
                    uri: post.uri,
                })
            }
            onAvatarClicked: function(
                authorDid,
                authorAvatar,
                authorDisplayName,
                authorHandle
            ) {
                stack.push(userProfilePage, {
                    userDid: authorDid,
                    userAvatar: authorAvatar,
                    userDisplayName: authorDisplayName,
                    userHandle: authorHandle,
                    me: authorDid === root.myDid
                })
            }
        }
    }
    Component {
        id: timelinePage

        TimelinePage {
            onOpenSettings: function() {
                stack.push(settingsPage)
            }
            onOpenSearch: function() {
                stack.push(searchPage)
            }
            onOpenProfile: function(
                authorDid,
                authorAvatar,
                authorDisplayName,
                authorHandle
            ) {
                stack.push(userProfilePage, {
                    userDid: root.myDid,
                    userAvatar: root.myAvatar,
                    userDisplayName: root.myDisplayName,
                    userHandle: root.myHandle,
                    me: true
                })
            }
            onImageClicked: function(imageUrl) {
                popupImage.source = imageUrl
                imagePopupBackground.visible = true
            }
            onVideoClicked: function(videoUrl) {
                popupVideo.source = videoUrl
                videoPopupBackground.visible = true
            }
            onPostClicked: function(post) {
                stack.push(postDetailPage, {
                    uri: post.uri,
                })
            }
            onQuotePostClicked: function(postUri) {
                stack.push(postDetailPage, {
                    uri: postUri,
                })
            }
            onAvatarClicked: function(
                authorDid,
                authorAvatar,
                authorDisplayName,
                authorHandle
            ) {
                stack.push(userProfilePage, {
                    userDid: authorDid,
                    userAvatar: authorAvatar,
                    userDisplayName: authorDisplayName,
                    userHandle: authorHandle,
                    me: authorDid === root.myDid
                })
            }
            onOpenPostClicked: function() {
                stack.push(postPage)
            }
        }
    }
    Component {
        id: postDetailPage
        PostDetailPage {
            id: postDetail
            onOpenSettings: function() {
                stack.push(settingsPage)
            }
            onImageClicked: function(imageUrl) {
                popupImage.source = imageUrl
                imagePopupBackground.visible = true
            }
            onVideoClicked: function(videoUrl) {
                popupVideo.source = videoUrl
                videoPopupBackground.visible = true
            }
            onPostClicked: function(post) {
                stack.push(postDetailPage, {
                    uri: post.uri,
                })
            }
            onAvatarClicked: function(
                authorDid,
                authorAvatar,
                authorDisplayName,
                authorHandle
            ) {
                stack.push(userProfilePage, {
                    userDid: authorDid,
                    userAvatar: authorAvatar,
                    userDisplayName: authorDisplayName,
                    userHandle: authorHandle,
                    me: authorDid === root.myDid
                })
            }
            onQuotePostClicked: function(postUri) {
                stack.push(postDetailPage, {
                    uri: postUri,
                })
            }
        }
    }
    Component {
        id: userProfilePage
        UserProfilePage {
            onImageClicked: function(imageUrl) {
                popupImage.source = imageUrl
                imagePopupBackground.visible = true
            }
            onVideoClicked: function(videoUrl) {
                popupVideo.source = videoUrl
                videoPopupBackground.visible = true
            }
            onPostClicked: function(post) {
                stack.push(postDetailPage, {
                    uri: post.uri,
                })
            }
            onAvatarClicked: function(
                authorDid,
                authorAvatar,
                authorDisplayName,
                authorHandle
            ) {
                stack.push(userProfilePage, {
                    userDid: authorDid,
                    userAvatar: authorAvatar,
                    userDisplayName: authorDisplayName,
                    userHandle: authorHandle,
                    me: authorDid === root.myDid
                })
            }
        }
    }
    Component {
        id: postPage
        PostPage {
            onFinished: function() {
                stack.pop()
            }
            onOpenImagePicker: function() {
                stack.push(imagePickerPage, {postPage: this})
            }
        }
    }
    Component {
        id: imagePickerPage
        MediaPickerPage {
            property var postPage
            contentType: ContentType.Pictures
            handler: ContentHandler.Source

            onImported: function(fileUrls) {
                console.log("Imported file URL:", fileUrls)
                postPage.setImages(fileUrls)
                stack.pop()
            }
            onFinished: function() {
                stack.pop()
            }
        }
    }

    Rectangle {
        id: imagePopupBackground
        anchors.fill: parent
        color: "#000000"
        visible: false

        Image {
            id: popupImage
            anchors.fill: parent
            source: ""
            fillMode: Image.PreserveAspectFit
        }
        Button {
            id: backFromImageButton
            anchors {
                top: parent.top
                left: parent.left
                topMargin: units.gu(1)
                leftMargin: units.gu(1)
            }
            text: "x"
            onClicked: imagePopupBackground.visible = false
        }
    }
    Rectangle {
        id: videoPopupBackground
        anchors.fill: parent
        color: "#000000"
        visible: false

        Video {
            id: popupVideo
            anchors.fill: parent
            source: ""
            autoPlay: true
            loops: MediaPlayer.Infinite
        }
        Button {
            id: backFromVideoButton
            anchors {
                top: parent.top
                left: parent.left
                topMargin: units.gu(1)
                leftMargin: units.gu(1)
            }
            text: "x"
            onClicked: {
                videoPopupBackground.visible = false
            }
        }
        onVisibleChanged: {
            if (visible) {
                popupVideo.play()
            } else {
                popupVideo.stop()
            }
        }
    }
}
