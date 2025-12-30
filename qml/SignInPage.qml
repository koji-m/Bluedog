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

Page {
    id: page
    signal signedIn()
    signal signInFailed()
    signal ready()

    onReady: function() {
        busy.running = false
    }

    header: PageHeader {
        id: header
        title: "Sign in"
    }

    Column {
        id: signInForm
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            topMargin: units.gu(2)
            leftMargin: units.gu(2)
            rightMargin: units.gu(2)
        }
        spacing: units.gu(1)

        TextField {
            id: userField
            placeholderText: "handle"
            focus: true
        }
        TextField {
            id: passField
            placeholderText: "app password"
            echoMode: TextInput.Password
            onAccepted: loginButton.clicked()
        }
        
        Button {
            id: loginButton
            text: busy.running ? "Signing in..." : "Sign in"
            color: "#1386DC"
            enabled: !busy.running && userField.text.length > 0 && passField.text.length > 0
            onClicked: {
                busy.running = true
                backend.signIn(userField.text, passField.text)
            }

            Connections {
                target: backend

                onSignInSuccess: function() {
                    busy.running = false
                }

                onSignInFailed: function() {
                    busy.running = false
                    errorLabel.text = "Sign in failed"
                }
            }
        }
        ActivityIndicator { id: busy; running: false; visible: running }
        Label { id: errorLabel; color: "red" }
    }

    Row {
        anchors {
            top: signInForm.bottom
            left: parent.left
            right: parent.right
            margins: units.gu(2)
        }
        spacing: units.gu(0.5)
        Icon {
            id: infoIcon
            width: units.gu(2)
            height: units.gu(2)
            name: "info"
        }
        Label {
            width: parent.width - infoIcon.width
            text: "The password here is an app password, not your main password. You need to create an app password on your Bluesky account settings page."
            wrapMode: Text.Wrap
        }
    }
}
