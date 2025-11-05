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

Page {
    id: root
    signal finished()

    ColumnLayout {
        anchors {
            left: parent.left
            top: parent.top
            right: parent.right
        }
        spacing: units.gu(1)

        TextArea {
            id: editor
            Layout.fillWidth: true
            Layout.margins: units.gu(1)
            wrapMode: TextEdit.Wrap
            placeholderText: "What's on your mind?"
            width: parent.width
            focus: true

            signal reset()

            onReset: {
                text = ""
            }
        }

        Label {
            id: errorLabel
            Layout.alignment: Qt.AlignTop
            text: ""
            color: "red"
            visible: text.length > 0
            Layout.fillWidth: true
        }

        Row {
            Layout.alignment: Qt.AlignTop
            spacing: 8
            Button {
                text: "Cancel"
                onClicked: {
                    editor.reset()
                    root.finished()
                }
            }
            Button {
                id: postButton
                text: "Post"
                color: "#1386DC"
                enabled: editor.text.length > 0

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

    function post(text) {
        py.call("backend.post", [text], function(res) {
            if (res.status === 'succeeded') {
                editor.reset()
                root.finished()
            } else {
                errorLabel.text = "Error: " + res.error
                postButton.enable()
            }
        }, function(err) {
            console.log("post error:", err)
        })
    }
}
