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

Page {
    id: page
    property bool loading: false
    property bool loadingByPull: false
    property string nextCursor: ""

    signal openProfile()
    signal openSettings()
    signal openSearch()
    signal imageClicked(string imageUrl)
    signal videoClicked(string videoUrl)
    signal postClicked(var post)
    signal quotePostClicked(string postUri)
    signal avatarClicked(
        string authorDid,
        string authorAvatar,
        string authorDisplayName,
        string authorHandle
    )
    signal openPostClicked()

    header: PageHeader {
        id: header
        title: "Timeline"

        ActionBar {
            anchors {
                top: parent.top
                right: parent.right
                topMargin: units.gu(1)
                rightMargin: units.gu(1)
            }
            numberOfSlots: 2
            actions: [
                Action {
                    iconName: "search"
                    text: i18n.tr("Search")
                    onTriggered: page.openSearch()
                },
                Action {
                    iconName: "account"
                    text: i18n.tr("Profile")
                    onTriggered: page.openProfile()
                },
                Action {
                    iconName: "settings"
                    text: i18n.tr("Settings")
                    onTriggered: page.openSettings()
                }
            ]
        }
    }

    ListView {
        id: list
        anchors {
            top: header.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        model: postsModel
        PullToRefresh {
            refreshing: page.loadingByPull
            onRefresh: {
                page.loadingByPull = true
                page.refreshByPull()
                page.loadingByPull = false
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

                RowLayout {
                    Layout.leftMargin: units.gu(4)
                    visible: model.repostedBy.length > 0

                    Icon {
                        width: units.gu(2)
                        height: units.gu(2)
                        name: 'retweet'
                    }
                    Text {
                        id: repostedByText
                        text: model.repostedBy + " reposted"
                        font.weight: Font.Thin
                        elide: Text.ElideRight
                    }
                }
                
                TimelinePost {
                    id: postContent
                    // Layout.fillWidth: true
                    // Layout.rightMargin: units.gu(1)
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
                    quotePost: model.quotePost// ? JSON.parse(model.quotePost) : null
                    embed: model.embed// ? JSON.parse(model.embed) : null
                    uri: model.uri
                    cid: model.cid
                    viewerLikeUri: model.viewerLikeUri
                    onImageClicked: function(imageUrl) {
                        page.imageClicked(imageUrl)
                    }
                    onVideoClicked: function(videoUrl) {
                        page.videoClicked(videoUrl)
                    }
                    onBackgroundTapped: {
                        page.postClicked(model)
                    }
                    onQuotePostClicked: function(postUri) {
                        page.quotePostClicked(postUri)
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

        onContentYChanged: {
            if (!page.loading && page.nextCursor && contentY + height >= contentHeight - 800) {
                page.fetch(page.nextCursor)
            }
        }

        function findIndexByUri(postUri) {
            for (let i = 0; i < postsModel.count; i++) {
                if (postsModel.get(i).uri === postUri) {
                    return i;
                }
            }
            return -1;
        }

        Connections {
            target: backend

            onLikeSucceeded: function(likeUri, postUri) {
                let i = findIndexByUri(postUri);
                if (i === -1) return;
                postModel.setProperty(i, "viewerLikeUri", likeUri);
                postModel.setProperty(i, "likeCount", postModel.get(i).likeCount + 1);
            }

            onLikeFailed: function() {
                console.log("Like failed");
            }

            onUnlikeSucceeded: function(postUri) {
                let i = findIndexByUri(postUri);
                if (i === -1) return;
                postModel.setProperty(i, "viewerLikeUri", "");
                postModel.setProperty(i, "likeCount", postModel.get(i).likeCount - 1);
            }

            onUnlikeFailed: function() {
                console.log("Unlike failed");
            }
        }
    }

    ListModel { id: postsModel }

    Rectangle {
        id: openPostPanelButton
        width: units.gu(5)
        height: units.gu(5)
        radius: width / 2
        color: "#1386DC"
        anchors {
            bottom: parent.bottom
            right: parent.right
            rightMargin: units.gu(2)
            bottomMargin: units.gu(2)
        }
        Icon {
            name: "edit"
            anchors.centerIn: parent
            width: units.gu(3)
            height: width
            color: "white"
        }
        MouseArea {
            anchors.fill: parent
            onClicked: page.openPostClicked()
        }
    }
    
    function fetch(cursor) {
        page.loading = true
        if (!cursor) postsModel.clear()
        backend.getTimeline(30, cursor)
    }

    function fetchPost(rkey, handle) {
        page.loading = true
    }

    function refresh() {
        nextCursor = ''
        fetch('')
    }

    function refreshByPull() {
        backend.resetTimelineState()
        refresh()
    }

    Connections {
        target: backend

        onTimelineFetched: function(res) {
            for (var i=0; i < res.items.length; i++) {
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
                    cid: res.items[i].cid,
                    viewerLikeUri: res.items[i].viewer_like_uri,
                })
            }
            page.nextCursor = res.nextCursor || ""
            page.loading = false
        }

        onTimelineFetchFailed: function() {
            page.loading = false
        }
    }

    Component.onCompleted: {
        refresh()
    }
}
