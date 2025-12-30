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

Column {
    id: root
    property string avatarUrl: ""
    property string rawText: ""
    property string authorHandle: ""
    property string authorDisplayName: ""
    property string authorDid: ""
    property string postedAt: ""
    property var embeds: []

    signal imageClicked(string imageUrl)

    function linkify(s) {
        var re = /((https?:\/\/[^\s<>"'()]+?[A-Za-z0-9\/#]))(?=[\s'")\]]|$)/g;
        return s.replace(re, function(m){
            return "<a href=\"" + m + "\">" + m + "</a>";
        });
    }

    property string richText: linkify(rawText)

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
            Layout.preferredWidth:  units.gu(2)
            Layout.preferredHeight: units.gu(2)
            Layout.minimumWidth: Layout.preferredWidth
            Layout.minimumHeight: Layout.preferredHeight
            Layout.maximumWidth: Layout.preferredWidth
            Layout.maximumHeight: Layout.preferredHeight
            Layout.alignment: Qt.AlignTop
            Layout.leftMargin: units.gu(1)

            Image {
                id: avatar
                anchors.fill: parent
                source: avatarUrl
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

        RowLayout {
            Layout.fillWidth: true
            Text {
                id: displayName
                text: authorDisplayName ? authorDisplayName : authorHandle
                font.weight: Font.Bold
                elide: Text.ElideRight
                Layout.minimumWidth: units.gu(7)
                Layout.minimumHeight: parent.height
            }
            Text {
                id: handle
                text: authorHandle
                font.weight: Font.Thin
                elide: Text.ElideRight
                Layout.minimumWidth: units.gu(7)
                Layout.minimumHeight: parent.height
            }
        }
        Text {
            id: postDatetime
            text: headerRow.computeRelativeTime(postedAt)
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.NoWrap
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
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
          Qt.openUrlExternally(url)
        }
    }

    function getImages(embeds) {
        for (var i = 0; i < embeds.length; i++) {
            if (embeds[i].type === 'images') {
                return embeds[i].thumbs;
            }
        }
        return null;
    }

    property var images: getImages(root.embeds)

    Item {
        id: imageContainer
        width: root.width
        height: images && images.length === 1
            ? root.width / singleImageAspectRatio
            : images && images.length > 1
            ? root.width / multiImageAspectRatio
            : 0
        visible: images && images.length > 0 ? true : false

        property real singleImageAspectRatio: 1.0
        property real multiImageAspectRatio: 16.0 / 9.0

        GridLayout {
            id: imageGrid
            anchors.fill: parent
            columns: images && images.length === 1 ? 1 : 2
            rowSpacing: units.gu(0.3)
            columnSpacing: units.gu(0.3)

            Repeater {
                model: images ? images : []
                delegate: Image {
                    source: modelData
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    Layout.maximumWidth: parent.width / (images.length === 1 ? 1 : 2) - imageGrid.columnSpacing
                    Layout.maximumHeight: parent.height / (images.length < 3 ? 1 : 2) - imageGrid.rowSpacing
                    Layout.alignment: Qt.AlignLeft | Qt.AlignTop

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.imageClicked(modelData)
                        }
                    }

                    onStatusChanged: {
                        if (status === Image.Ready && images && images.length === 1) {
                            if (root.width === 0) {
                                Qt.callLater(function() {
                                    if (root.width > 0) {
                                        imageContainer.singleImageAspectRatio = sourceSize.width / sourceSize.height
                                        imageContainer.height = root.width / imageContainer.singleImageAspectRatio
                                    }
                                })
                            } else {
                                imageContainer.singleImageAspectRatio = sourceSize.width / sourceSize.height
                                imageContainer.height = root.width / imageContainer.singleImageAspectRatio
                            }
                        }
                    }
                }
            }
        }
    }
}
