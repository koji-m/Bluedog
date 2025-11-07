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
import Lomiri.Content 1.3
import io.thp.pyotherside 1.4

Page {
    id: picker
	property var activeTransfer

	property var url
	property var handler
	property var contentType
	
    signal cancel()
    signal imported(var fileUrls)
    signal finished()

    header: PageHeader {
        title: "Choose"
    }

    ContentPeerPicker {
        anchors { fill: parent; topMargin: picker.header.height }
        visible: parent.visible
        showTitle: false
        contentType: picker.contentType //ContentType.Pictures
        handler: picker.handler //ContentHandler.Source

        onPeerSelected: {
            peer.selectionType = ContentTransfer.Multiple
            picker.activeTransfer = peer.request()
            picker.activeTransfer.stateChanged.connect(function() {
                if (picker.activeTransfer == null) {
                    return;
                }
                if (picker.activeTransfer.state === ContentTransfer.Charged) {
                    console.log("Charged");
                    var images = [];
                    for (var i = 0; i < picker.activeTransfer.items.length; i++) {
                        images.push(picker.activeTransfer.items[i].url.toString());
                    }
                    picker.imported(images)
                    picker.activeTransfer = null
                }
            })
        }
       
        onCancelPressed: {
            picker.finished()
        }
    }

    ContentTransferHint {
        id: transferHint
        anchors.fill: parent
        activeTransfer: picker.activeTransfer
    }
    Component {
        id: resultComponent
        ContentItem {}
	}
}

