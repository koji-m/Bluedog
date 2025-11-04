from atproto import models

import auth


_timeline = None

class TimelineBackend:
    def __init__(self, data_dir: str):
        auth.set_data_dir(data_dir)
        self.client = auth.init_client()
        self.next_cursor = None
        self.seen_uris = set()
        self.search_next_cursor = None
        self.search_seen_uris = set()
        self.author_feed_next_cursor = None
        self.author_feed_seen_uris = set()

    def reset_state(self):
        self.next_cursor = None
        self.seen_uris = set()
        self.next_cursor = None
        self.seen_uris = set()
        self.search_next_cursor = None
        self.search_seen_uris = set()
        self.author_feed_next_cursor = None
        self.author_feed_seen_uris = set()

    @staticmethod
    def parse_post(post, reposted_by=""):
        author = post.author

        repost_count = post.repost_count if post.repost_count else 0
        quote_count = post.quote_count if post.quote_count else 0

        quote_post = None
        if hasattr(post, "embed") and isinstance(post.embed, models.AppBskyEmbedRecord.View):
            quote_record = post.embed.record
            quote_author = quote_record.author

            quote_embeds = []
            for quote_embed in quote_record.embeds:
                if isinstance(quote_embed, models.AppBskyEmbedImages.View):
                    quote_embeds.append({
                        "type": "images",
                        "thumbs": [image.thumb for image in quote_embed.images],
                    })

            quote_post = {
                "text": quote_record.value.text,
                "avatar": quote_author.avatar,
                "authorHandle": quote_author.handle,
                "authorDisplayName": quote_author.display_name,
                "authorDid": quote_author.did,
                "postedAt": quote_record.indexed_at,
                "embeds": quote_embeds,
            }

        if hasattr(post, "embed"):
            if isinstance(post.embed, models.AppBskyEmbedImages.View):
                embed = {
                    "type": "images",
                    "thumbs": [image.thumb for image in post.embed.images],
                }
            elif isinstance(post.embed, models.AppBskyEmbedExternal.View):
                embed = {
                    "type": "external",
                    "uri": post.embed.external.uri,
                    "title": post.embed.external.title,
                    "description": post.embed.external.description,
                    "thumb": post.embed.external.thumb,
                }
            elif isinstance(post.embed, models.AppBskyEmbedVideo.View):
                embed = {
                    "type": "video",
                    "uri": post.embed.playlist,
                    "thumb": post.embed.thumbnail,
                }
            else:
                embed = None

        return {
            "text": post.record.text,
            "avatar": author.avatar,
            "authorHandle": author.handle,
            "authorDisplayName": author.display_name,
            "authorDid": author.did,
            "postedAt": post.indexed_at,
            "replyCount": post.reply_count if post.reply_count else 0,
            "quoteAndRepostCount": quote_count + repost_count,
            "likeCount": post.like_count if post.like_count else 0,
            "repostedBy": reposted_by,
            "quotePost": quote_post,
            "embed": embed,
            "uri": post.uri,
            "cid": post.cid,
            "viewer_like_uri": post.viewer.like if post.viewer and post.viewer.like else "",
        }

    def fetch_post(self, rkey: str, handle: str):
        res = self.client.get_post(post_rkey=rkey, profile_identify=handle)
        post = self.client.get_posts([res.uri]).posts[0]
        feeds = [self.parse_post(post)]

        return {
            "items": feeds,
            "nextCursor": None,
            "hasMore": False,
        }


    def fetch_timeline(self, limit=30, cursor=None):
        timeline = self.client.get_timeline(
            algorithm="reverse-chronological",
            cursor=cursor,
            limit=limit,
        )
        feeds = []
        for feed_view in timeline.feed:
            post_uri = getattr(feed_view.post, "uri", None)
            if not post_uri or post_uri in self.seen_uris:
                continue
            self.seen_uris.add(post_uri)

            if feed_view.reason:
                reposted_by = feed_view.reason.by.display_name or feed_view.reason.by.handle
            else:
                reposted_by = ""

            post = feed_view.post
            feeds.append(self.parse_post(post, reposted_by=reposted_by))

        self.next_cursor = timeline.cursor or None

        return {
            "items": feeds,
            "nextCursor": self.next_cursor,
            "hasMore": self.next_cursor is not None
        }

    def init_search(self):
        self.search_next_cursor = None
        self.search_seen_uris = set()

    def search_posts(self, query: str, limit=25, cursor=None):
        params = models.app.bsky.feed.search_posts.Params(
            q=query,
            limit=limit,
            cursor=cursor,
        )
        search_res = self.client.app.bsky.feed.search_posts(params)
        feeds = []
        for post in search_res.posts:
            post_uri = getattr(post, "uri", None)
            if not post_uri or post_uri in self.search_seen_uris:
                continue
            self.search_seen_uris.add(post_uri)

            feeds.append(self.parse_post(post))

        self.search_next_cursor = search_res.cursor or None

        return {
            "items": feeds,
            "nextCursor": self.search_next_cursor,
            "hasMore": self.search_next_cursor is not None
        }

    def fetch_user_profile(self, did: str):
        profile = self.client.get_profile(did)
        return {
            "did": did,
            "banner": profile.banner,
            "avatar": profile.avatar,
            "displayName": profile.display_name,
            "handle": profile.handle,
            "followersCount": profile.followers_count,
            "followsCount": profile.follows_count,
            "postsCount": profile.posts_count,
            "description": profile.description,
            "followingUri": profile.viewer.following if profile.viewer and profile.viewer.following else "",
        }

    def reset_user_posts_cache(self):
        self.author_feed_next_cursor = None
        self.author_feed_seen_uris = set()

    def fetch_user_posts(self, did: str, limit=30, cursor=None):
        posts_res = self.client.get_author_feed(
            actor=did,
            limit=limit,
            cursor=cursor,
        )
        feeds = []
        for feed_view in posts_res.feed:
            post_uri = getattr(feed_view.post, "uri", None)
            if not post_uri or post_uri in self.author_feed_seen_uris:
                continue
            self.author_feed_seen_uris.add(post_uri)

            if feed_view.reason:
                reposted_by = feed_view.reason.by.display_name or feed_view.reason.by.handle
            else:
                reposted_by = ""

            post = feed_view.post
            feeds.append(self.parse_post(post, reposted_by=reposted_by))

        self.author_feed_next_cursor = posts_res.cursor or None

        return {
            "items": feeds,
            "nextCursor": self.author_feed_next_cursor,
            "hasMore": self.author_feed_next_cursor is not None
        }

    def fetch_replies(self, uri: str):
        res = self.client.get_post_thread(uri=uri)
        feeds = []
        for feed_view in res.thread.replies:
            post = feed_view.post
            feeds.append(self.parse_post(post))

        return {
            "items": feeds,
        }

    def follow_user(self, did: str):
        res = self.client.follow(did)
        return {
            "status": "succeeded",
            "uri": res.uri,
        }

    def unfollow_user(self, uri: str):
        res = self.client.unfollow(uri)
        return {
            "status": "succeeded" if res else "failed",
        }


def init(data_dir: str):
    global _timeline
    if _timeline is None:
        try:
            _timeline = TimelineBackend(data_dir)
            return {"status": "succeeded"}
        except Exception:
            return {"status": "failed"}


def reset_state():
    if _timeline is None:
        raise RuntimeError("backend not initialized. Call init() first.")
    _timeline.reset_state()


def init_search():
    if _timeline is None:
        raise RuntimeError("backend not initialized. Call init() first.")
    _timeline.init_search()


def fetch_timeline(limit=30, cursor=None):
    if _timeline is None:
        raise RuntimeError("backend not initialized. Call init() first.")
    return _timeline.fetch_timeline(limit=limit, cursor=cursor)


def fetch_post(rkey: str, handle: str):
    if _timeline is None:
        raise RuntimeError("backend not initialized. Call init() first.")
    return _timeline.fetch_post(rkey=rkey, handle=handle)


def fetch_replies(uri: str):
    if _timeline is None:
        raise RuntimeError("backend not initialized. Call init() first.")
    return _timeline.fetch_replies(uri=uri)


def search_posts(query: str, limit=25, cursor=None):
    if _timeline is None:
        raise RuntimeError("backend not initialized. Call init() first.")

    return _timeline.search_posts(
        query=query,
        limit=limit,
        cursor=cursor,
    )


def fetch_user_profile(did: str):
    if _timeline is None:
        raise RuntimeError("backend not initialized. Call init() first.")
    return _timeline.fetch_user_profile(did)


def reset_user_posts_cache():
    if _timeline is None:
        raise RuntimeError("backend not initialized. Call init() first.")
    return _timeline.reset_user_posts_cache()


def fetch_user_posts(did: str, limit=30, cursor=None):
    if _timeline is None:
        raise RuntimeError("backend not initialized. Call init() first.")
    return _timeline.fetch_user_posts(did=did, limit=limit, cursor=cursor)


def post(text: str):
    try:
        client = auth.init_client()

        client.send_post(text=text)

        return {"status": "succeeded"}
    except Exception as e:
        return {"status": "failed", "error": str(e)}


def follow_user(did: str):
    if _timeline is None:
        raise RuntimeError("backend not initialized. Call init() first.")
    return _timeline.follow_user(did)


def unfollow_user(uri: str):
    if _timeline is None:
        raise RuntimeError("backend not initialized. Call init() first.")
    return _timeline.unfollow_user(uri)

def sign_out():
    global _timeline
    auth.sign_out()
    _timeline = None
