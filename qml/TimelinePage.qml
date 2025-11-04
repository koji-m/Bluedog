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
import io.thp.pyotherside 1.4

Page {
    id: page
    property bool loading: false
    property bool loadingByPull: false
    property bool hasMore: true
    property string nextCursor: ""

    signal openSettings()
    signal openSearch()
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
                    iconName: "settings"
                    text: i18n.tr("Settings")
                    onTriggered: page.openSettings()
                },
                Action {
                    iconName: "search"
                    text: i18n.tr("Search")
                    onTriggered: page.openSearch()
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
            if (!loading && hasMore && contentY + height >= contentHeight - 800) {
                page.fetch(nextCursor)
            }
        }
    }

    ListModel { id: postsModel }
    
    function resetState() {
        py.call("backend.reset_state", [], function(res) {
        }, function(err) {
            console.log("reset_state error:", err)
        })
    }

    function fetch(cursor) {
        loading = true
        py.call("backend.fetch_timeline", [30, cursor], function(res) {
            if (!cursor) postsModel.clear()
            for (var i=0; i<res.items.length; i++) {
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
            nextCursor = res.nextCursor || ""
            hasMore = res.hasMore
            loading = false
        }, function(err) {
            console.log("fetch_timeline error:", err)
            loading = false
        })
    }

    function fetchPost(rkey, handle) {
        loading = true
        py.call("backend.fetch_post", [rkey, handle], function(res) {
            let post = res.items[0]
            postsModel.insert(0, {
                displayText: post.text,
                authorAvatar: post.avatar,
                authorHandle: post.authorHandle,
                authorDisplayName: post.authorDisplayName,
                authorDid: post.authorDid,
                postedAt: post.postedAt,
                replyCount: post.replyCount,
                quoteAndRepostCount: post.quoteAndRepostCount,
                likeCount: post.likeCount,
                repostedBy: post.repostedBy,
                quotePost: post.quotePost ? JSON.stringify(post.quotePost) : '',
                embed: post.embed ? JSON.stringify(post.embed) : '',
                uri: post.uri,
                cid: post.cid,
                viewerLikeUri: post.viewer_like_uri,
            })
            nextCursor = res.nextCursor || ''
            hasMore = res.hasMore
            loading = false
        }, function(err) {
            console.log("fetch_post error:", err)
            loading = false
        })
    }

    function refresh() {
        nextCursor = ''
        hasMore = true
        fetch('')
    }

    function refreshByPull() {
        resetState()
        refresh()
    }

    Component.onCompleted: {
        refresh()
    }
}
