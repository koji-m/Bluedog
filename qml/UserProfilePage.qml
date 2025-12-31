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
    property bool loading: true
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
        backend.unfollowUser(uri)
    }

    function followUser(did) {
        backend.followUser(did)
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
                            source: page.userAvatar ? page.userAvatar : Qt.resolvedUrl("../assets/avatar_none.svg")
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
                page.fetch_user_posts(page.userDid, page.nextCursor)
            }
        }
    }

    ListModel { id: postsModel }

    function fetch_user_profile(did) {
        loading = true
        backend.getUserProfile(did)
    }

    function fetch_user_posts(did, cursor) {
        loading = true
        backend.getUserPosts(did, 30, cursor)
    }

    function refresh(userDid) {
        page.loading = true
        page.nextCursor = ""
        backend.resetAuthorFeedState()
        fetch_user_profile(userDid)
        fetch_user_posts(userDid, '')
    }

    Component.onCompleted: {
        page.refresh(userDid)
    }

    Connections {
        target: backend

        onUserProfileFetched: function(data) {
            page.banner = data.banner ? data.banner : ""
            page.followersCount = data.followersCount
            page.followsCount = data.followsCount
            page.postsCount = data.postsCount
            page.description = data.description
            page.followingUri = data.followingUri

            page.loading = false
        }
        onUserProfileFetchFailed: function() {
            page.loading = false
        }

        onUserPostsFetched: function(res, init) {
            if (init) postsModel.clear()
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
            page.loading = false
        }

        onUserPostsFetchFailed: function() {
            page.loading = false
        }

        onFollowSucceeded: function(uri) {
            page.followingUri = uri
        }

        onFollowFailed: function() {
            console.log('Follow failed')
        }

        onUnfollowSucceeded: function() {
            page.followingUri = ''
        }

        onUnfollowFailed: function() {
            console.log('Unfollow failed')
        }
    }   
}
