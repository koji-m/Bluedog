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
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import Qt.labs.platform 1.0
import QtMultimedia 5.9
import io.thp.pyotherside 1.4

MainView {
    id: root
    objectName: 'mainView'
    applicationName: 'bluedog.koji-m'
    automaticOrientation: true

    width: units.gu(45)
    height: units.gu(75)

    property bool pythonReady: false
    property string dataDir: ""

    Page {
        id: splashPage
        anchors.fill: parent
        visible: !pythonReady

        Label {
            anchors.fill: parent
            text: 'Bluedog'

            verticalAlignment: Label.AlignVCenter
            horizontalAlignment: Label.AlignHCenter
        }
    }

    Python {
        id: py

        onReceived: function (msg) {
            if (msg && msg.type === "authExpired") {
                stack.clear()
                stack.push(signInPage)
            }
        }

        onError: {
            console.log('python error: ' + traceback);
        }
    }

    PageStack {
        id: stack
        anchors.fill: parent

        Component.onCompleted: {
            py.addImportPath(Qt.resolvedUrl('../python/'));
            py.addImportPath(Qt.resolvedUrl('../src/'));
            py.importModule('backend', function () {
                var loc = StandardPaths.writableLocation(StandardPaths.AppDataLocation);
                root.dataDir = (loc && typeof loc.toLocalFile === "function") ? loc.toLocalFile() : (typeof loc === "string" ? loc : String(loc));
                py.call('backend.init', [root.dataDir], function (res) {
                    splashPage.visible = false
                    root.pythonReady = true
                    if (res.status === 'succeeded') {
                        stack.push(timelinePage, {}, {immediate: true})
                    } else {
                        stack.push(signInPage, {}, {immediate: true})
                    }
                }, function (err) {
                    console.log("backend.init error:", err)
                    stack.push(signInPage, {}, {immediate: true})
                    splashPage.visible = false
                    root.pythonReady = true
                })
            })
        }
    }

    Component {
        id: signInPage
        SignInPage {
            onSignedIn: function () {
                py.call('backend.init', [root.dataDir], function (res) {
                    splashPage.visible = false
                    stack.clear()
                    if (res.status === 'succeeded') {
                        stack.push(timelinePage, {}, {immediate: true})
                    } else {
                        stack.push(signInPage, {}, {immediate: true})
                    }
                })
            }
        }
    }
    Component {
        id: settingsPage
        SettingsPage {
            onSignOutRequested: function () {
                py.call('auth.sign_out', [])
                stack.clear()
                stack.push(signInPage)
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
                    avatarUrl: post.authorAvatar,
                    rawText: post.displayText,
                    authorHandle: post.authorHandle,
                    authorDisplayName: post.authorDisplayName,
                    postedAt: post.postedAt,
                    replyCount: post.replyCount,
                    quoteAndRepostCount: post.quoteAndRepostCount,
                    likeCount: post.likeCount,
                    uri: post.uri,
                    embed: post.embed ? JSON.parse(post.embed) : null
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
                    userHandle: authorHandle
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
                    avatarUrl: post.authorAvatar,
                    rawText: post.displayText,
                    authorHandle: post.authorHandle,
                    authorDisplayName: post.authorDisplayName,
                    authorDid: post.authorDid,
                    postedAt: post.postedAt,
                    replyCount: post.replyCount,
                    quoteAndRepostCount: post.quoteAndRepostCount,
                    likeCount: post.likeCount,
                    uri: post.uri,
                    embed: post.embed ? JSON.parse(post.embed) : null
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
                    userHandle: authorHandle
                })
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
                    avatarUrl: post.authorAvatar,
                    rawText: post.displayText,
                    authorHandle: post.authorHandle,
                    authorDisplayName: post.authorDisplayName,
                    authorDid: post.authorDid,
                    postedAt: post.postedAt,
                    replyCount: post.replyCount,
                    quoteAndRepostCount: post.quoteAndRepostCount,
                    likeCount: post.likeCount,
                    uri: post.uri,
                    embed: post.embed ? JSON.parse(post.embed) : null
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
                    userHandle: authorHandle
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
                    avatarUrl: post.authorAvatar,
                    rawText: post.displayText,
                    authorHandle: post.authorHandle,
                    authorDisplayName: post.authorDisplayName,
                    postedAt: post.postedAt,
                    replyCount: post.replyCount,
                    quoteAndRepostCount: post.quoteAndRepostCount,
                    likeCount: post.likeCount,
                    uri: post.uri,
                    embed: post.embed ? JSON.parse(post.embed) : null
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
                    userHandle: authorHandle
                })
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