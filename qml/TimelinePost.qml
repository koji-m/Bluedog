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
import QtQuick.Layouts 1.3
import QtGraphicalEffects 1.0
import Lomiri.Components 1.3

RowLayout {
    id: root
    property string rawText: ""
    property string authorHandle: ""
    property string authorDisplayName: ""
    property string authorAvatar: ""
    property string authorDid: ""
    property string postedAt: ""
    property int replyCount: 0
    property int quoteAndRepostCount: 0
    property int likeCount: 0
    property var quotePost: null
    property var embed: null
    property string uri: ""
    property string cid: ""
    property string viewerLikeUri: ""

    signal imageClicked(string imageUrl)
    signal videoClicked(string videoUrl)
    signal backgroundTapped()
    signal quotePostClicked(string postUri)
    signal avatarClicked(
        string authorDid,
        string authorAvatar,
        string authorDisplayName,
        string authorHandle
    )

    spacing: units.gu(1)

    Item {
        Layout.preferredWidth:  units.gu(5)
        Layout.preferredHeight: units.gu(5)
        Layout.minimumWidth: Layout.preferredWidth
        Layout.minimumHeight: Layout.preferredHeight
        Layout.maximumWidth: Layout.preferredWidth
        Layout.maximumHeight: Layout.preferredHeight
        Layout.alignment: Qt.AlignTop
        Layout.leftMargin: units.gu(1)

        Image {
            id: avatar
            anchors.fill: parent
            source: authorAvatar ? authorAvatar : Qt.resolvedUrl("../assets/avatar_none.svg")
            visible: false

            
        }
        OpacityMask {
            anchors.fill: avatar
            source: avatar
            maskSource: Rectangle {
                width: avatar.width
                height: avatar.height
                radius: width / 2
                color: "white"
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                avatarClicked(
                    authorDid,
                    authorAvatar,
                    authorDisplayName,
                    authorHandle
                );
            }
        }
    }
    TimelinePostContent {
        Layout.fillWidth: true
        Layout.rightMargin: units.gu(1)
        height: implicitHeight
        rawText: root.rawText
        authorHandle: root.authorHandle
        authorDisplayName: root.authorDisplayName
        authorDid: root.authorDid
        postedAt: root.postedAt
        replyCount: root.replyCount
        quoteAndRepostCount: root.quoteAndRepostCount
        likeCount: root.likeCount
        quotePost: root.quotePost ? JSON.parse(root.quotePost) : null
        embed: root.embed ? JSON.parse(root.embed) : null
        uri: root.uri
        cid: root.cid
        viewerLikeUri: root.viewerLikeUri
        onImageClicked: function(imageUrl) {
            root.imageClicked(imageUrl)
        }
        onVideoClicked: function(videoUrl) {
            root.videoClicked(videoUrl)
        }
        onQuotePostClicked: function(postUri) {
            root.quotePostClicked(postUri);
        }
    }
}
