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

Page {
    id: root

    signal finished()
    signal openImagePicker()
    signal setImages(var fileUrls)

    header: PageHeader {
        id: header

        Row {
            anchors {
                top: parent.top
                right: parent.right
                topMargin: units.gu(1)
                rightMargin: units.gu(1)
            }
            spacing: 8

            ActivityIndicator {
                id: activity
            }

            Button {
                id: postButton

                text: "Post"
                color: "#1386DC"
                enabled: editor.text.length > 0 || imageModel.count > 0

                signal enable()

                onEnable: {
                    editor.text.length > 0 ? enabled = true : enabled = false
                }

                onClicked: {
                    errorLabel.text = ""
                    enabled = false
                    root.post(editor.text)
                }
            }
        }
    }

    ListModel {
        id: imageModel
    }
    ColumnLayout {
        anchors {
            left: parent.left
            top: header.bottom
            right: parent.right
            topMargin: units.gu(2)
        }

        TextArea {
            id: editor
            Layout.fillWidth: true
            Layout.leftMargin: units.gu(1)
            Layout.rightMargin: units.gu(1)
            wrapMode: TextEdit.Wrap
            placeholderText: "What's on your mind?"
            width: parent.width
            focus: true

            signal reset()

            onReset: {
                text = ""
            }
        }

        Row {
            Layout.alignment: Qt.AlignTop
            Layout.leftMargin: units.gu(1)
            spacing: 8
            Icon {
                width: units.gu(4)
                height: units.gu(4)
                color: "#1386DC"
                name: "stock_image"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        errorLabel.text = ""
                        root.openImagePicker()
                    }
                }
            }
        }

        Row {
            id: imageRow
            Layout.leftMargin: units.gu(1)
            spacing: units.gu(0.3)

            Repeater {
                model: imageModel
                delegate: Rectangle {
                    width: (root.width - units.gu(1) * 2) / 4 - imageRow.spacing
                    height: width
                    border.width: 1
                    Image {
                        anchors {
                            fill: parent
                            margins: 1
                        }
                        source: url
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop

                        onStatusChanged: {
                            if (status === Image.Error) {
                                console.log("Error loading image:", source)
                            }
                            if (status === Image.Ready) {
                                console.log("Image loaded:", source)
                            }
                        }
                    }
                }
            }
        }

        Label {
            id: errorLabel
            Layout.alignment: Qt.AlignTop
            Layout.leftMargin: units.gu(1)
            wrapMode: Text.Wrap
            text: ""
            color: "red"
            visible: text.length > 0
            Layout.fillWidth: true
        }
    }

    onSetImages: function(fileUrls) {
        console.log("Adding image URL:", fileUrls)
        imageModel.clear()
        if (fileUrls.length > 4) {
            errorLabel.text = "You can select up to 4 images."
            return
        }
        for (var i = 0; i < fileUrls.length; i++) {
            imageModel.append({url: fileUrls[i]})
            console.log("Appended image URL:", fileUrls[i])
        }
    }

    function post(text) {
        activity.running = true
        var imageUrls = []
        for (var i = 0; i < imageModel.count; i++) {
            imageUrls.push(imageModel.get(i).url)
        }
        backend.post(text, imageUrls)
    }

    Connections {
        target: backend

        onPostSucceeded: function() {
            editor.reset()
            activity.running = false
            root.finished()
        }

        onPostFailed: function(error) {
            errorLabel.text = "Error: " + error
            activity.running = false
            postButton.enable()
        }
    }
}
