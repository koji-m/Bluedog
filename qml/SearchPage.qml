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
    property bool hasMore: true
    property string nextCursor: ""
    property string query: ""

    signal imageClicked(string imageUrl)
    signal videoClicked(string videoUrl)
    signal postClicked(var post)
    signal avatarClicked(
        string authorDid,
        string authorAvatar,
        string authorDisplayName,
        string authorHandle
    )

    header: PageHeader {
        id: header

        contents: TextArea {
            id: searchInput
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                leftMargin: units.gu(3)
                rightMargin: units.gu(3)
                topMargin: units.gu(1)
                bottomMargin: units.gu(1)
            }
            placeholderText: "Search"
            autoSize: true
            maximumLineCount: 1

            Keys.onReturnPressed: {
                if (!event.isAutoRepeat) {
                    event.accepted = true
                    if (searchInput.text.length === 0) {
                        return
                    }
                    page.query = searchInput.text
                    page.refresh()
                    page.search(page.query, page.nextCursor)
                }
            }
            Keys.onEnterPressed: Keys.onReturnPressed(event)
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
                page.search(page.query, page.nextCursor)
            }
        }
    }

    ListModel { id: postsModel }
    
    function search(query, cursor) {
        page.loading = true
        if (!cursor) postsModel.clear()
        backend.searchPosts(query, 25, cursor)
    }

    function refresh() {
        backend.resetSearchState()
        page.nextCursor = ''
        hasMore = true
    }

    function refreshByPull() {
        refresh()
    }

    Component.onCompleted: {
        refresh()
    }

    Connections {
        target: backend

        onSearchResultFetched: function(res) {
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

        onSearchFailed: function() {
            page.loading = false
        }
    }
}
