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
    property bool loading: true
    property bool hasMore: false
    property string nextCursor: ""
    property string userDid: ""
    property string userAvatar: ""
    property string userDisplayName: ""
    property string userHandle: ""
    property string banner: ""
    property string followersCount: ""
    property string followsCount: ""
    property string postsCount: ""
    property string description: ""
    property string followingUri: ""
    property bool me: false

    signal unFollowUser(string uri)
    signal imageClicked(string imageUrl)
    signal videoClicked(string videoUrl)
    signal postClicked(var post)
    signal avatarClicked(
        string authorDid,
        string authorAvatar,
        string authorDisplayName,
        string authorHandle
    )

    function unfollowUser(uri) {
        py.call("backend.unfollow_user", [uri], function(res) {
            if (res.status === 'succeeded') {
                page.followingUri = ''
            } else {
                console.log("unfollow_user failed:", res)
            }
        }, function(err) {
            console.log("unfollow_user error:", err)
        })
    }

    function followUser(did) {
        py.call("backend.follow_user", [did], function(res) {
            if (res.status === 'succeeded') {
                page.followingUri = res.uri
            } else {
                console.log("follow_user failed:", res)
            }
        }, function(err) {
            console.log("follow_user error:", err)
        })
    }

    header: PageHeader {
        id: header
        StyleHints {
            backgroundColor: "transparent"
            dividerColor: "transparent"
        }
    }

    ListView {
        id: profileWithPosts
        headerPositioning: ListView.InlineHeader
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        spacing: units.gu(0.5)
        model: postsModel
        header: Component {
            Item {
                width: profileWithPosts.width
                height: banner.height + avatarRow.height / 2 + infoCol.height + units.gu(0.5)

                Image {
                    id: banner
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    height: units.gu(10)

                    source: page.banner
                    fillMode: Image.PreserveAspectCrop
                }

                RowLayout {
                    id: avatarRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: banner.bottom
                    }

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
                        Layout.preferredWidth:  units.gu(8)
                        Layout.preferredHeight: units.gu(8)
                        Layout.minimumWidth:    Layout.preferredWidth
                        Layout.minimumHeight:   Layout.preferredHeight
                        Layout.maximumWidth:    Layout.preferredWidth
                        Layout.maximumHeight:   Layout.preferredHeight
                        Layout.alignment: Qt.AlignTop

                        Image {
                            id: avatar
                            anchors.fill: parent
                            source: page.userAvatar
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
                    }

                    Button {
                        id: followButton
                        text: page.followingUri ? "Following" : "Follow"
                        color: page.followingUri ? "#5D5D5D" : "#19B6EE"
                        visible: !page.me

                        Layout.preferredHeight: units.gu(3)
                        Layout.minimumHeight:   Layout.preferredHeight
                        Layout.maximumHeight:   Layout.preferredHeight
                        Layout.alignment: Qt.AlignBottom | Qt.AlignRight

                        onClicked: {
                            if (page.followingUri) {
                                page.unfollowUser(page.followingUri);
                            } else {
                                page.followUser(page.userDid);
                            }
                        }
                    }
                }

                ColumnLayout {
                    id: infoCol
                    anchors {
                        top: avatarRow.bottom
                        left: parent.left
                        right: parent.right
                    }
                    spacing: 0
                    Text {
                        id: displayName
                        text: page.userDisplayName ? page.userDisplayName : page.userHandle
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        Layout.maximumHeight: avatar.height / 2
                    }
                    Text {
                        id: handle
                        text: '@' + page.userHandle
                        font.weight: Font.Thin
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        Layout.maximumHeight: avatar.height / 2
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop

                        Text {
                            id: followersCount
                            text: page.followersCount + " Followers"
                            font.weight: Font.Thin
                            elide: Text.ElideRight
                        }
                        Text {
                            id: followsCount
                            text: page.followsCount + " Following"
                            font.weight: Font.Thin
                            elide: Text.ElideRight
                            Layout.leftMargin: units.gu(1)
                        }
                        Text {
                            id: postsCount
                            text: page.postsCount + " Posts"
                            font.weight: Font.Thin
                            elide: Text.ElideRight
                            Layout.leftMargin: units.gu(1)
                        }
                    }
                    Text {
                        id: description
                        text: page.description
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        Layout.bottomMargin: units.gu(0.5)
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        height: 1
                        color: "gray"
                    }
                }
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
            if (!loading && hasMore && contentY + height >= contentHeight - 800) {
                page.fetch_user_posts(userDid, nextCursor)
            }
        }
    }

    ListModel { id: postsModel }

    function fetch_user_profile(did) {
        loading = true
        py.call("backend.fetch_user_profile", [did], function(res) {
            page.banner = res.banner ? res.banner : ""
            page.followersCount = res.followersCount
            page.followsCount = res.followsCount
            page.postsCount = res.postsCount
            page.description = res.description ? res.description : ""
            page.followingUri = res.followingUri

            loading = false
        }, function(err) {
            loading = false
        })
    }

    function fetch_user_posts(did, cursor) {
        loading = true
        py.call("backend.fetch_user_posts", [did, 30, cursor], function(res) {
            if (!cursor) postsModel.clear()
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
            nextCursor = res.nextCursor || ""
            hasMore = res.hasMore
            loading = false
        }, function(err) {
            console.log("fetch_user_posts error:", err)
            loading = false
        })
    }

    function refresh(userDid) {
        page.loading = true
        page.nextCursor = ""
        page.hasMore = false
        py.call("backend.reset_user_posts_cache", [], function(res) {
        }, function(err) {
            console.log("reset_user_posts_cache error:", err)
        })
        fetch_user_profile(userDid)
        fetch_user_posts(userDid, '')
    }

    Component.onCompleted: {
        page.refresh(userDid)
    }
}
