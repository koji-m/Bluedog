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
    signal signOutRequested()

    header: PageHeader {
        id: header
        title: "Settings"
    }

    Column {
        anchors.margins: units.gu(2)
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
        }
        spacing: units.gu(1)

        Button {
            id: signOutButton
            text: "Sign out"
            onClicked: {
                backend.signOut()
            }
        }
    }
}
