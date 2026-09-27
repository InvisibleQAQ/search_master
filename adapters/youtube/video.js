/* @meta
{
  "name": "youtube/video",
  "description": "Get detailed info for a YouTube video (from current page or by video ID). Private override of bb-sites youtube/video: YouTube's service worker sometimes answers the watch-page navigation with its cached app shell (app_shell_home, no ytInitialPlayerResponse), and the community version then silently fell back to /youtubei/v1/next (9 fields, no duration/viewCount/captionLanguages/description/keywords, localized publishDate). Now page globals are used only if they belong to the requested video; otherwise /watch?v=<id> is fetched (a non-navigation request, never replaced by the shell) and ytInitialPlayerResponse / ytInitialData are parsed from the HTML. The /next branch is kept as the last resort.",
  "domain": "www.youtube.com",
  "args": {
    "id": {"required": false, "description": "Video ID (defaults to current page video)"}
  },
  "capabilities": ["network"],
  "readOnly": true,
  "example": "bb-browser site youtube/video d56mG7DezGs"
}
*/

async function(args) {
  // Parse the JSON object literal that follows `marker` in the HTML; null on any failure.
  function extractJson(html, marker) {
    const at = html.indexOf(marker);
    const start = at < 0 ? -1 : html.indexOf('{', at + marker.length);
    if (start < 0) return null;
    let depth = 0, inStr = false;
    for (let i = start; i < html.length; i++) {
      const c = html[i];
      if (inStr) { if (c === '\\') i++; else if (c === '"') inStr = false; }
      else if (c === '"') inStr = true;
      else if (c === '{') depth++;
      else if (c === '}' && --depth === 0) {
        try { return JSON.parse(html.slice(start, i + 1)); } catch (e) { return null; }
      }
    }
    return null;
  }

  // Server-rendered watch page. fetch() is not a navigation, so the service worker passes it to the network.
  async function fromWatchHtml(id) {
    try {
      const resp = await fetch('/watch?v=' + encodeURIComponent(id), {credentials: 'include'});
      if (!resp.ok) return {};
      const html = await resp.text();
      return {p: extractJson(html, 'var ytInitialPlayerResponse = '), d: extractJson(html, 'var ytInitialData = ')};
    } catch (e) {
      return {};
    }
  }

  const currentUrl = location.href;
  let videoId = args.id;

  // Auto-detect from current page
  if (!videoId) {
    const match = currentUrl.match(/[?&]v=([a-zA-Z0-9_-]{11})/);
    if (match) videoId = match[1];
  }
  if (!videoId) return {error: 'No video ID', hint: 'Provide a video ID or navigate to a YouTube video page'};

  // Page globals come from the initial document: missing when the SW served its app shell,
  // stale after SPA navigation, or for another video. Use them only if they match.
  let p = window.ytInitialPlayerResponse;
  let d = window.ytInitialData;
  if (p?.videoDetails?.videoId !== videoId || !d?.contents?.twoColumnWatchNextResults) {
    ({p, d} = await fromWatchHtml(videoId));
  }

  if (p?.videoDetails?.videoId === videoId && d) {
    const vd = p.videoDetails || {};
    const mf = p.microformat?.playerMicroformatRenderer || {};

    // Extract engagement data from ytInitialData
    const results = d.contents?.twoColumnWatchNextResults?.results?.results?.contents || [];
    const primary = results.find(i => i.videoPrimaryInfoRenderer)?.videoPrimaryInfoRenderer;

    let likeCount = '';
    const menuRenderer = primary?.videoActions?.menuRenderer;
    if (menuRenderer?.topLevelButtons) {
      for (const btn of menuRenderer.topLevelButtons) {
        const seg = btn.segmentedLikeDislikeButtonViewModel;
        if (seg) {
          likeCount = seg.likeButtonViewModel?.likeButtonViewModel?.toggleButtonViewModel?.toggleButtonViewModel?.defaultButtonViewModel?.buttonViewModel?.title || '';
        }
      }
    }

    // Channel info
    const secondary = results.find(i => i.videoSecondaryInfoRenderer)?.videoSecondaryInfoRenderer;
    const owner = secondary?.owner?.videoOwnerRenderer;

    // Comment count from section
    const commentSection = results.find(i => i.itemSectionRenderer?.targetId === 'comments-section');
    const commentToken = commentSection?.itemSectionRenderer?.contents?.[0]?.continuationItemRenderer?.continuationEndpoint?.continuationCommand?.token;

    return {
      videoId: vd.videoId,
      title: vd.title,
      channel: vd.author,
      channelId: vd.channelId,
      channelUrl: owner?.navigationEndpoint?.browseEndpoint?.canonicalBaseUrl ? 'https://www.youtube.com' + owner.navigationEndpoint.browseEndpoint.canonicalBaseUrl : '',
      subscriberCount: owner?.subscriberCountText?.simpleText || '',
      description: (vd.shortDescription || '').substring(0, 1000),
      duration: parseInt(vd.lengthSeconds) || 0,
      durationFormatted: (() => {
        const s = parseInt(vd.lengthSeconds) || 0;
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const sec = s % 60;
        return h > 0 ? h + ':' + String(m).padStart(2,'0') + ':' + String(sec).padStart(2,'0') : m + ':' + String(sec).padStart(2,'0');
      })(),
      viewCount: parseInt(vd.viewCount) || 0,
      viewCountFormatted: primary?.viewCount?.videoViewCountRenderer?.viewCount?.simpleText || '',
      likes: likeCount,
      publishDate: mf.publishDate || primary?.dateText?.simpleText || '',
      category: mf.category || '',
      isLive: vd.isLiveContent || false,
      keywords: (vd.keywords || []).slice(0, 20),
      captionLanguages: (p.captions?.playerCaptionsTracklistRenderer?.captionTracks || []).map(t => ({lang: t.languageCode, name: t.name?.simpleText})),
      url: 'https://www.youtube.com/watch?v=' + vd.videoId,
      _commentContinuationToken: commentToken || null
    };
  }

  // Last resort: innertube next API gives basic info only (no duration/viewCount/captions, localized date)
  const cfg = window.ytcfg?.data_ || {};
  const apiKey = cfg.INNERTUBE_API_KEY;
  const context = cfg.INNERTUBE_CONTEXT;
  if (!apiKey || !context) return {error: 'YouTube config not found', hint: 'Make sure you are on youtube.com'};

  const resp = await fetch('/youtubei/v1/next?key=' + apiKey + '&prettyPrint=false', {
    method: 'POST',
    credentials: 'include',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({context, videoId})
  });

  if (!resp.ok) return {error: 'API returned HTTP ' + resp.status};
  const data = await resp.json();

  const results = data.contents?.twoColumnWatchNextResults?.results?.results?.contents || [];
  const primary = results.find(i => i.videoPrimaryInfoRenderer)?.videoPrimaryInfoRenderer;
  const secondary = results.find(i => i.videoSecondaryInfoRenderer)?.videoSecondaryInfoRenderer;
  const owner = secondary?.owner?.videoOwnerRenderer;

  let likeCount = '';
  const menuRenderer = primary?.videoActions?.menuRenderer;
  if (menuRenderer?.topLevelButtons) {
    for (const btn of menuRenderer.topLevelButtons) {
      const seg = btn.segmentedLikeDislikeButtonViewModel;
      if (seg) {
        likeCount = seg.likeButtonViewModel?.likeButtonViewModel?.toggleButtonViewModel?.toggleButtonViewModel?.defaultButtonViewModel?.buttonViewModel?.title || '';
      }
    }
  }

  return {
    videoId,
    title: primary?.title?.runs?.[0]?.text || '',
    channel: owner?.title?.runs?.[0]?.text || '',
    channelId: owner?.navigationEndpoint?.browseEndpoint?.browseId || '',
    subscriberCount: owner?.subscriberCountText?.simpleText || '',
    viewCountFormatted: primary?.viewCount?.videoViewCountRenderer?.viewCount?.simpleText || '',
    likes: likeCount,
    publishDate: primary?.dateText?.simpleText || '',
    url: 'https://www.youtube.com/watch?v=' + videoId
  };
}
