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
import io.thp.pyotherside 1.4

Page {
    id: page
    signal signedIn()

    header: PageHeader {
        id: header
        title: "Sign in"
    }

    Column {
        anchors.margins: units.gu(2)
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
        }
        spacing: units.gu(1)

        TextField {
            id: userField
            placeholderText: "username"
            focus: true
        }
        TextField {
            id: passField
            placeholderText: "password"
            echoMode: TextInput.Password
            onAccepted: loginButton.clicked()
        }
        
        Button {
            id: loginButton
            text: busy.running ? "Signing in..." : "Sign in"
            enabled: !busy.running
            onClicked: {
                py.importModule('auth', function () {
                    busy.running = true
                    py.call('auth.sign_in', [userField.text, passField.text], function (res) {
                        busy.running = false
                        if (res.status === 'ok') {
                            page.signedIn()
                        } else {
                            errorLabel.text = res.message || "Sign in failed"
                        }
                    }, function (err) {
                        busy.running = false
                        errorLabel.text = "" + err
                    })
                })
            }
        }
        ActivityIndicator { id: busy; running: false; visible: running }
        Label { id: errorLabel; color: theme.palette.normal.negativeText }
    }
}
