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
import Lomiri.Components 1.3
import io.thp.pyotherside 1.4

Item {
    id: root
    property string rawText: ""
    property string authorHandle: ""
    property string authorDisplayName: ""
    property string authorDid: ""
    property string postedAt: ""
    property int replyCount: 0
    property int quoteAndRepostCount: 0
    property int likeCount: 0
    property var quotePost: null
    property var embed: null
    property string uri: ""

    signal imageClicked(string imageUrl)
    signal videoClicked(string videoUrl)

    implicitWidth: contentColumn.implicitWidth
    implicitHeight: contentColumn.implicitHeight + units.gu(0.5)

    function linkify(s) {
        var re = /((https?:\/\/[^\s<>"'()]+?[A-Za-z0-9\/#]))(?=[\s'")\]]|$)/g;
        return s.replace(re, function(m) {
            return "<a href=\"" + m + "\">" + m + "</a>";
        });
    }

    property string richText: linkify(rawText)

    Column {
        id: contentColumn
        width: parent.width
        spacing: units.gu(0.5)

        RowLayout {
            id: headerRow
            width: root.width

            function computeRelativeTime(iso) {
                if (!iso) return "";
                var postDate = new Date(iso);
                var now = new Date();
                var diffMs = now - postDate;
                var diffHours = diffMs / (1000 * 60 * 60);

                if (diffHours < 1) {
                    var mins = Math.floor(diffHours * 60);
                    var unit = mins === 1 ? "min" : "mins";
                    return mins + " " + unit;
                } else if (diffHours < 24) {
                    var hrs = Math.floor(diffHours);
                    var unit = hrs === 1 ? "hour" : "hours";
                    return hrs + " " + unit;
                } else {
                    var days = Math.floor(diffHours / 24);
                    var unit = days === 1 ? "day" : "days";
                    return days + " " + unit;
                }
            }

            Text {
                id: displayName
                text: authorDisplayName ? authorDisplayName : authorHandle
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            Text {
                id: handle
                text: '@' + authorHandle
                font.weight: Font.Thin
                elide: Text.ElideRight
            }
            Text {
                id: postDatetime
                text: headerRow.computeRelativeTime(postedAt)
                wrapMode: Text.NoWrap
                Layout.fillWidth: true
            }
        }

        Text {
            id: body
            width: root.width
            height: implicitHeight
            text: root.richText
            textFormat: Text.RichText
            wrapMode: Text.WordWrap
            onLinkActivated: function(url) {
                Qt.openUrlExternally(url);
            }
        }

        Item {
            id: imageContainer
            width: root.width
            height: embed && embed.type === "images" && embed.thumbs.length === 1
                ? root.width / singleImageAspectRatio
                : embed && embed.type === "images" && embed.thumbs.length > 1
                ? root.width / multiImageAspectRatio
                : 0
            visible: embed && embed.type === "images" && embed.thumbs.length > 0 ? true : false

            property real singleImageAspectRatio: 1.0
            property real multiImageAspectRatio: 16.0 / 9.0

            GridLayout {
                id: imageGrid
                anchors.fill: parent
                columns: embed && embed.type === "images" && embed.thumbs.length === 1 ? 1 : 2
                rowSpacing: units.gu(0.3)
                columnSpacing: units.gu(0.3)

                Repeater {
                    model: embed && embed.type === "images" ? embed.thumbs : []
                    delegate: Image {
                        source: modelData
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        Layout.maximumWidth: parent.width / (embed.thumbs.length === 1 ? 1 : 2) - imageGrid.columnSpacing
                        Layout.maximumHeight: imageGrid.height / (embed.thumbs.length < 3 ? 1 : 2) - imageGrid.rowSpacing
                        Layout.alignment: Qt.AlignLeft | Qt.AlignTop

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.imageClicked(modelData);
                            }
                        }

                        onStatusChanged: {
                            if (status === Image.Ready && embed && embed.thumbs.length === 1) {
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
            width: root.width
            height: embed && embed.type === "video"
                ? root.width / aspectRatio
                : 0
            visible: embed && embed.type === "video" ? true : false

            property real aspectRatio: 16.0 / 9.0

            Image {
                id: videoThumb
                anchors.fill: parent
                source: embed && embed.type === "video" ? embed.thumb : ""
                asynchronous: true
                fillMode: Image.PreserveAspectCrop

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.videoClicked(embed.uri);
                    }
                }
            }
        }

        Rectangle {
            id: externUrlContainer
            width: root.width
            implicitHeight: embed && embed.type === "external"
                ? externUrlLayout.implicitHeight
                : 0
            visible: embed && embed.type === "external" ? true : false
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
                    source: embed && embed.type === "external" && embed.thumb ? embed.thumb : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    Layout.maximumWidth: externUrlContainer.width - 2
                    Layout.maximumHeight: externUrlContainer.width / externUrlContainer.aspectRatio
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignTop
                    Layout.margins: 1
                }
                Text {
                    id: externTitle
                    text: embed && embed.type === "external" ? embed.title : ""
                    font.weight: Font.Bold
                    wrapMode: Text.WordWrap
                    Layout.maximumWidth: externUrlContainer.width - 2
                    Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                    Layout.margins: 1
                }
                Text {
                    id: externDescription
                    text: embed && embed.type === "external" ? embed.description : ""
                    font.weight: Font.Thin
                    wrapMode: Text.WordWrap
                    Layout.maximumWidth: externUrlContainer.width - 2
                    Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                    Layout.margins: 1
                }
                Text {
                    id: externUri
                    text: embed && embed.type === "external" ? embed.uri : ""
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

        Rectangle {
            id: borderRect
            width: root.width
            height: quotedPost.visible ? quotedPost.height + units.gu(2) : 0
            color: "transparent"
            border.color: "#cccccc"
            border.width: 1

            QuotePost {
                id: quotedPost
                width: parent.width
                height: implicitHeight
                visible: root.quotePost != null

                avatarUrl: root.quotePost ? root.quotePost.avatar : ""
                rawText: root.quotePost ? root.quotePost.text : ""
                authorHandle: root.quotePost ? root.quotePost.authorHandle : ""
                authorDisplayName: root.quotePost ? root.quotePost.authorDisplayName : ""
                authorDid: root.quotePost ? root.quotePost.authorDid : ""
                postedAt: root.quotePost ? root.quotePost.postedAt : ""
                embeds: root.quotePost ? root.quotePost.embeds : []
                onImageClicked: function(imageUrl) {
                  root.imageClicked(imageUrl);
                }
            }
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
                    text: root.replyCount > 0 ? root.replyCount : ""
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
                    text: root.quoteAndRepostCount > 0 ? root.quoteAndRepostCount : ""
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
                    text: root.likeCount > 0 ? root.likeCount : ""
                    font.weight: Font.Thin
                    Layout.minimumWidth: units.gu(3)
                    Layout.minimumHeight: parent.height
                }
            }
        }
    }
}
