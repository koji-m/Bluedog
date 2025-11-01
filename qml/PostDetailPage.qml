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
import QtQuick.Layouts 1.3
import QtGraphicalEffects 1.0
import Lomiri.Components 1.3
import io.thp.pyotherside 1.4

Page {
    id: page
    property bool loading: false
    property bool hasMore: true
    property string nextCursor: ""

    property string avatarUrl: ""
    property string rawText: ""
    property string authorHandle: ""
    property string authorDisplayName: ""
    property string authorDid: ""
    property string postedAt: ""
    property int replyCount: 0
    property int quoteAndRepostCount: 0
    property int likeCount: 0
    property string uri: ""
    property var embed: null

    signal openSettings()
    signal imageClicked(string imageUrl)
    signal videoClicked(string videoUrl)
    signal postClicked(var post)
    signal avatarClicked(
        string authorDid,
        string authorAvatar,
        string authorDisplayName,
        string authorHandle
    )

    function linkify(s) {
        var re = /((https?:\/\/[^\s<>"'()]+?[A-Za-z0-9\/#]))(?=[\s'")\]]|$)/g;
        return s.replace(re, function(m){
        return "<a href=\"" + m + "\">" + m + "</a>";
        });
    }

    property string richText: linkify(rawText)

    header: PageHeader {
        id: header
        title: "Post"
        ActionBar {
            anchors {
                top: parent.top
                right: parent.right
                topMargin: units.gu(1)
                rightMargin: units.gu(1)
            }
            numberOfSlots: 1
            actions: [
                Action {
                    iconName: "settings"
                    text: i18n.tr("Settings")
                    onTriggered: page.openSettings()
                }
            ]
        }
    }

    ListView {
        id: replyPosts
        headerPositioning: ListView.InlineHeader
        anchors {
            top: header.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        spacing: units.gu(0.5)
        model: postsModel
        header: Component {
            Item {
                width: replyPosts.width
                height: root.implicitHeight + units.gu(0.5)
                Column {
                    id: root
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    leftPadding: units.gu(1)
                    rightPadding: units.gu(1)
                    spacing: units.gu(0.5)

                    RowLayout {
                        id: headerRow
                        width: root.width

                        function computeRelativeTime(iso) {
                            if (!iso) return ""
                            var postDate = new Date(iso)
                            var now = new Date()
                            var diffMs = now - postDate
                            var diffHours = diffMs / (1000 * 60 * 60)

                            if (diffHours < 1) {
                                var mins = Math.floor(diffHours * 60)
                                var unit = mins === 1 ? "min" : "mins"
                                return mins + " " + unit
                            } else if (diffHours < 24) {
                                var hrs = Math.floor(diffHours)
                                var unit = hrs === 1 ? "hour" : "hours"
                                return hrs + " " + unit
                            } else {
                                var days = Math.floor(diffHours / 24)
                                var unit = days === 1 ? "day" : "days"
                                return days + " " + unit
                            }
                        }

                        Item {
                            Layout.preferredWidth:  units.gu(5)
                            Layout.preferredHeight: units.gu(5)
                            Layout.minimumWidth:    Layout.preferredWidth
                            Layout.minimumHeight:   Layout.preferredHeight
                            Layout.maximumWidth:    Layout.preferredWidth
                            Layout.maximumHeight:   Layout.preferredHeight
                            Layout.alignment: Qt.AlignTop

                            Image {
                                id: avatar
                                anchors.fill: parent
                                source: page.avatarUrl
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
                                    page.avatarClicked(
                                        page.authorDid,
                                        page.avatarUrl,
                                        page.authorDisplayName,
                                        page.authorHandle
                                    );
                                }
                            }
                        }

                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true

                            Text {
                                id: displayName
                                text: page.authorDisplayName ? page.authorDisplayName : page.authorHandle
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                Layout.maximumHeight: avatar.height / 2
                            }
                            Text {
                                id: handle
                                text: '@' + page.authorHandle
                                font.weight: Font.Thin
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                Layout.maximumHeight: avatar.height / 2
                            }
                        }
                    }

                    Text {
                        id: body
                        width: root.width
                        height: implicitHeight
                        text: page.richText
                        textFormat: Text.RichText
                        wrapMode: Text.WordWrap
                        onLinkActivated: function(url) {
                            Qt.openUrlExternally(url)
                        }
                    }

                    Item {
                        id: imageContainer
                        width: parent.width - units.gu(2)
                        height: page.embed && page.embed.type === "images" && page.embed.thumbs.length === 1
                                ? root.width / singleImageAspectRatio
                                : page.embed && page.embed.type === "images" && page.embed.thumbs.length > 1
                                ? root.width / multiImageAspectRatio
                                : 0
                        visible: page.embed && page.embed.type === "images" && page.embed.thumbs.length > 0 ? true : false

                        property real singleImageAspectRatio: 1.0
                        property real multiImageAspectRatio: 16.0 / 9.0

                        GridLayout {
                            id: imageGrid
                            anchors.fill: parent
                            columns: page.embed && page.embed.type === "images" && page.embed.thumbs.length === 1 ? 1 : 2
                            rowSpacing: units.gu(0.3)
                            columnSpacing: units.gu(0.3)

                            Repeater {
                                model: page.embed && page.embed.type === "images" ? page.embed.thumbs : []
                                delegate: Image {
                                    source: modelData
                                    asynchronous: true
                                    fillMode: Image.PreserveAspectCrop
                                    Layout.maximumWidth: parent.width / (page.embed.thumbs.length === 1 ? 1 : 2) - imageGrid.columnSpacing
                                    Layout.maximumHeight: imageGrid.height / (page.embed.thumbs.length < 3 ? 1 : 2) - imageGrid.rowSpacing
                                    Layout.alignment: Qt.AlignLeft | Qt.AlignTop

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            page.imageClicked(modelData);
                                        }
                                    }

                                    onStatusChanged: {
                                        if (status === Image.Ready && page.embed && page.embed.thumbs.length === 1) {
                                            if (root.width === 0) {
                                                Qt.callLater(function() {
                                                    if (root.width > 0) {
                                                    imageContainer.singleImageAspectRatio = sourceSize.width / sourceSize.height;
                                                    imageContainer.height = root.width / imageContainer.singleImageAspectRatio;
                                                    }
                                                });
                                            } else {
                                                imageContainer.singleImageAspectRatio = sourceSize.width / sourceSize.height;
                                                imageContainer.height = root.width / imageContainer.singleImageAspectRatio;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: videoContainer
                        width: parent.width - units.gu(2)
                        height: page.embed && page.embed.type === "video"
                                ? root.width / aspectRatio
                                : 0
                        visible: page.embed && page.embed.type === "video" ? true : false

                        property real aspectRatio: 16.0 / 9.0

                        Image {
                            id: videoThumb
                            anchors.fill: parent
                            source: page.embed && page.embed.type === "video" ? page.embed.thumb : ""
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.videoClicked(page.embed.uri);
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: externUrlContainer
                        width: parent.width - units.gu(2)
                        implicitHeight: page.embed && page.embed.type === "external"
                                ? externUrlLayout.implicitHeight
                                : 0
                        visible: page.embed && page.embed.type === "external" ? true : false
                        border.width: 1
                        border.color: "#000000"

                        property real aspectRatio: 16.0 / 9.0

                        ColumnLayout {
                            id: externUrlLayout
                            width: parent.width
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: units.gu(0)

                            Image {
                                id: externThumb
                                source: page.embed && page.embed.type === "external" ? page.embed.thumb : ""
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                Layout.maximumWidth: externUrlContainer.width - 2
                                Layout.maximumHeight: externUrlContainer.width / externUrlContainer.aspectRatio
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignTop
                                Layout.margins: 1
                            }
                            Text {
                                id: externTitle
                                text: page.embed && page.embed.type === "external" ? page.embed.title : ""
                                font.weight: Font.Bold
                                wrapMode: Text.WordWrap
                                Layout.maximumWidth: externUrlContainer.width - 2
                                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                                Layout.margins: 1
                            }
                            Text {
                                id: externDescription
                                text: page.embed && page.embed.type === "external" ? page.embed.description : ""
                                font.weight: Font.Thin
                                wrapMode: Text.WordWrap
                                Layout.maximumWidth: externUrlContainer.width - 2
                                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                                Layout.margins: 1
                            }
                            Text {
                                id: externUri
                                text: page.embed && page.embed.type === "external" ? page.embed.uri : ""
                                font.weight: Font.Thin
                                color: "blue"
                                wrapMode: Text.WordWrap
                                Layout.maximumWidth: externUrlContainer.width - 2
                                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                                Layout.margins: 1
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                Qt.openUrlExternally(externUri.text);
                            }
                        }
                    }

                    Text {
                        id: postedAt
                        width: root.width
                        text: page.postedAt
                        font.weight: Font.Thin
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                        wrapMode: Text.NoWrap
                    }

                    RowLayout {
                        id: iconsRow
                        width: root.width

                        RowLayout {
                            id: reply
                            spacing: 1
                            Icon {
                                width: units.gu(2)
                                height: units.gu(2)
                                name: "message"
                            }
                            Text {
                                id: replyCount
                                text: page.replyCount > 0 ? page.replyCount : ""
                                font.weight: Font.Thin
                                Layout.minimumWidth: units.gu(3)
                                Layout.minimumHeight: parent.height
                            }
                        }
                        RowLayout {
                            id: quoteAndRepost
                            spacing: 1
                            Icon {
                                width: units.gu(2)
                                height: units.gu(2)
                                name: "retweet"
                            }
                            Text {
                                id: quoteAndRepostCount
                                text: page.quoteAndRepostCount > 0 ? page.quoteAndRepostCount : ""
                                font.weight: Font.Thin
                                Layout.minimumWidth: units.gu(3)
                                Layout.minimumHeight: parent.height
                            }
                        }
                        RowLayout {
                            id: like
                            spacing: 1
                            Icon {
                                width: units.gu(2)
                                height: units.gu(2)
                                name: "like"
                            }
                            Text {
                                id: likeCount
                                text: page.likeCount > 0 ? page.likeCount : ""
                                font.weight: Font.Thin
                                Layout.minimumWidth: units.gu(3)
                                Layout.minimumHeight: parent.height
                            }
                        }
                    }
                    Rectangle {
                        anchors {
                            left: root.left
                            right: root.right
                        }
                        height: 1
                        color: "gray"
                    }
                }
            }
        }
        delegate: ListItem {
            ColumnLayout {
                id: col
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }

                TimelinePost {
                    id: postContent
                    Layout.fillWidth: true
                    height: implicitHeight
                    rawText: model.displayText
                    authorHandle: model.authorHandle
                    authorDisplayName: model.authorDisplayName
                    authorAvatar: model.authorAvatar
                    authorDid: model.authorDid
                    postedAt: model.postedAt
                    replyCount: model.replyCount
                    quoteAndRepostCount: model.quoteAndRepostCount
                    likeCount: model.likeCount
                    quotePost: model.quotePost
                    embed: model.embed
                    uri: model.uri
                    onImageClicked: function(imageUrl) {
                        page.imageClicked(imageUrl)
                    }
                    onVideoClicked: function(videoUrl) {
                        page.videoClicked(videoUrl)
                    }
                    onBackgroundTapped: {
                        page.postClicked(model)
                    }
                    onAvatarClicked: function(
                        authorDid,
                        authorAvatar,
                        authorDisplayName,
                        authorHandle
                    ) {
                        page.avatarClicked(
                            authorDid,
                            authorAvatar,
                            authorDisplayName,
                            authorHandle
                        );
                    }
                }
            }
            height: col.implicitHeight
            onClicked: postContent.backgroundTapped()
        }
    }

    ListModel { id: postsModel }
    
    function fetch_replies(uri) {
        loading = true
        py.call("backend.fetch_replies", [uri], function(res) {
            postsModel.clear()
            for (var i=0; i<res.items.length; i++) {
                postsModel.append({
                    displayText: res.items[i].text,
                    authorAvatar: res.items[i].avatar,
                    authorHandle: res.items[i].authorHandle,
                    authorDisplayName: res.items[i].authorDisplayName,
                    authorDid: res.items[i].authorDid,
                    postedAt: res.items[i].postedAt,
                    replyCount: res.items[i].replyCount,
                    quoteAndRepostCount: res.items[i].quoteAndRepostCount,
                    likeCount: res.items[i].likeCount,
                    repostedBy: res.items[i].repostedBy,
                    quotePost: res.items[i].quotePost ? JSON.stringify(res.items[i].quotePost) : '',
                    embed: res.items[i].embed ? JSON.stringify(res.items[i].embed) : '',
                    uri: res.items[i].uri,
                })
            }
            loading = false
        }, function(err) {
            console.log("fetch_timeline error:", err)
            loading = false
        })
    }

    function refresh(uri) {
        fetch_replies(uri)
    }

    Component.onCompleted: {
        refresh(page.uri)
    }
}
