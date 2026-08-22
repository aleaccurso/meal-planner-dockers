#!/bin/bash
#
# Shared helpers for deploy/deploy.sh - GitHub REST API access (no jq
# dependency - must run identically on macOS and Synology DSM's shell),
# v<YYYY.MM.DD>.<N> tag lookup/sorting, and the cross-machine tag-minting
# lock.
#
# Must be sourced after GIT_AUTH_TOKEN is set in the caller's environment.

BACKEND_REPO="${BACKEND_REPO:?BACKEND_REPO not set - set it in .env.backend, e.g. owner/meal-planner-backend}"
FRONTEND_REPO="${FRONTEND_REPO:?FRONTEND_REPO not set - set it in .env.frontend, e.g. owner/meal-planner}"
GITHUB_API="${GITHUB_API:-https://api.github.com}"
LOCK_STALE_SECONDS="${LOCK_STALE_SECONDS:-600}"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

# ---- tiny JSON helpers (no jq dependency - must run identically on macOS
# and Synology DSM's shell) ----

json_field() {
    # First occurrence of "field":"value" in $1 -> prints value.
    local json="$1" field="$2"
    printf '%s' "$json" | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -n1 |
        sed -E "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"([^\"]*)\"/\\1/"
}

# ---- GitHub REST API wrapper ----

GH_STATUS=""
GH_BODY=""

gh_request() {
    # gh_request <METHOD> <path> [json-body]  ->  sets GH_STATUS, GH_BODY
    local method="$1" path="$2" data="${3:-}" raw
    if [ -n "$data" ]; then
        raw=$(curl -sS -X "$method" \
            -H "Authorization: Bearer ${GIT_AUTH_TOKEN}" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            -w $'\n%{http_code}' \
            -d "$data" \
            "${GITHUB_API}${path}")
    else
        raw=$(curl -sS -X "$method" \
            -H "Authorization: Bearer ${GIT_AUTH_TOKEN}" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            -w $'\n%{http_code}' \
            "${GITHUB_API}${path}")
    fi
    GH_STATUS=$(printf '%s' "$raw" | tail -n1)
    GH_BODY=$(printf '%s' "$raw" | sed '$d')
}

# ---- tag lookup ----

LATEST_TAG_NAME=""
LATEST_TAG_SHA=""

get_latest_tag() {
    local repo="$1" refs shas paired filtered latest_line latest_version

    gh_request GET "/repos/${repo}/git/matching-refs/tags/v"
    [ "$GH_STATUS" = "200" ] || fail "could not list tags for ${repo} (HTTP ${GH_STATUS}): ${GH_BODY}"

    # GitHub's API returns indented, multi-line JSON (one key per line), not
    # compact single-line JSON - patterns must tolerate whitespace around ':'
    # and must not assume "object" and "sha" share a line. grep -o exits 1 on
    # no match, which would kill the script under `set -o pipefail`, so `|| true`.
    refs=$(printf '%s' "$GH_BODY" | grep -o '"ref"[[:space:]]*:[[:space:]]*"refs/tags/[^"]*"' | sed -E 's#.*"ref"[[:space:]]*:[[:space:]]*"refs/tags/([^"]*)"#\1#' || true)
    shas=$(printf '%s' "$GH_BODY" | grep -o '"sha"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -E 's#.*"sha"[[:space:]]*:[[:space:]]*"([^"]*)"#\1#' || true)
    paired=$(paste -d'\t' <(printf '%s\n' "$refs") <(printf '%s\n' "$shas"))
    filtered=$(printf '%s\n' "$paired" | grep -E $'^v[0-9]{4}\\.[0-9]{2}\\.[0-9]{2}\\.[0-9]+\t' || true)

    if [ -z "$filtered" ]; then
        LATEST_TAG_NAME=""
        LATEST_TAG_SHA=""
        return
    fi

    # Strip leading 'v' and do a proper numeric multi-field sort (not -V,
    # which isn't available on macOS's BSD sort).
    latest_line=$(printf '%s\n' "$filtered" | sed 's/^v//' | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -n1)
    latest_version=$(printf '%s' "$latest_line" | cut -f1)
    LATEST_TAG_NAME="v${latest_version}"
    LATEST_TAG_SHA=$(printf '%s' "$latest_line" | cut -f2)
}

# ---- tag minting, with cross-machine locking ----
#
# Locking exists so tag_commit_if_needed can safely run from both a local
# machine and the NAS without racing (see plans/enforce-fresh-main-builds.md
# in the umbrella repo for the full design history).

iso_to_epoch() {
    # Cross-platform ISO8601 UTC ("...Z") -> epoch seconds: GNU date on Linux
    # (Synology DSM), BSD date on macOS.
    local iso="$1"
    if date -u -d "$iso" +%s >/dev/null 2>&1; then
        date -u -d "$iso" +%s
    else
        date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s
    fi
}

LOCK_HELD_REPO=""

release_lock() {
    if [ -n "$LOCK_HELD_REPO" ]; then
        gh_request DELETE "/repos/${LOCK_HELD_REPO}/git/refs/tags/tag-release-lock"
        LOCK_HELD_REPO=""
    fi
}
trap release_lock EXIT

acquire_lock() {
    local repo="$1" head_sha="$2" attempt tag_object_sha
    local lock_tag_sha lock_date lock_message lock_epoch now_epoch age

    for attempt in 1 2; do
        gh_request POST "/repos/${repo}/git/tags" \
            "{\"tag\":\"tag-release-lock\",\"message\":\"locked by $(hostname) pid=$$\",\"object\":\"${head_sha}\",\"type\":\"commit\"}"
        [ "$GH_STATUS" = "201" ] || fail "could not create lock tag object for ${repo} (HTTP ${GH_STATUS}): ${GH_BODY}"
        tag_object_sha=$(json_field "$GH_BODY" "sha")

        gh_request POST "/repos/${repo}/git/refs" \
            "{\"ref\":\"refs/tags/tag-release-lock\",\"sha\":\"${tag_object_sha}\"}"

        if [ "$GH_STATUS" = "201" ]; then
            LOCK_HELD_REPO="$repo"
            return 0
        fi
        [ "$GH_STATUS" = "422" ] || fail "unexpected error acquiring lock for ${repo} (HTTP ${GH_STATUS}): ${GH_BODY}"

        # Contention: someone (possibly the other machine) already holds it.
        gh_request GET "/repos/${repo}/git/refs/tags/tag-release-lock"
        [ "$GH_STATUS" = "200" ] || fail "lock ref reported as existing for ${repo} but could not be read (HTTP ${GH_STATUS}): ${GH_BODY}"
        lock_tag_sha=$(json_field "$GH_BODY" "sha")

        gh_request GET "/repos/${repo}/git/tags/${lock_tag_sha}"
        [ "$GH_STATUS" = "200" ] || fail "could not resolve lock tag object for ${repo} (HTTP ${GH_STATUS}): ${GH_BODY}"
        lock_date=$(json_field "$GH_BODY" "date")
        lock_message=$(json_field "$GH_BODY" "message")
        lock_epoch=$(iso_to_epoch "$lock_date")
        now_epoch=$(date -u +%s)
        age=$((now_epoch - lock_epoch))

        if [ "$age" -le "$LOCK_STALE_SECONDS" ]; then
            fail "${repo}: tag-release-lock is held (age ${age}s, held by: ${lock_message})"
        fi
        if [ "$attempt" -eq 2 ]; then
            fail "${repo}: tag-release-lock still contended after breaking a stale lock and retrying once"
        fi

        echo "WARN: ${repo}: breaking stale tag-release-lock (age ${age}s, held by: ${lock_message})" >&2
        gh_request DELETE "/repos/${repo}/git/refs/tags/tag-release-lock"
        [ "$GH_STATUS" = "204" ] || fail "could not delete stale lock ref for ${repo} (HTTP ${GH_STATUS}): ${GH_BODY}"
    done
}

compute_next_tag() {
    local last_name="$1" today last_date last_n
    today="$(date +%Y.%m.%d)"
    if [ -z "$last_name" ]; then
        printf 'v%s.1' "$today"
        return
    fi
    last_date=$(printf '%s' "$last_name" | sed -E 's/^v([0-9]{4}\.[0-9]{2}\.[0-9]{2})\.[0-9]+$/\1/')
    last_n=$(printf '%s' "$last_name" | sed -E 's/^v[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.([0-9]+)$/\1/')
    if [ "$last_date" = "$today" ]; then
        printf 'v%s.%d' "$today" "$((last_n + 1))"
    else
        printf 'v%s.1' "$today"
    fi
}

TAG_WAS_NEW=""

tag_commit_if_needed() {
    # tag_commit_if_needed <owner/repo> <sha> <out-var-name>
    #
    # Reuses the existing vYYYY.MM.DD.N tag if one already points at <sha>
    # (e.g. this exact commit was already deployed and tagged before).
    # Otherwise mints the next tag for today pointing at <sha>, under the
    # cross-machine lock. Tags the SHA that was actually just deployed, not
    # whatever main happens to be by the time this runs.
    #
    # Also sets the global TAG_WAS_NEW to "1" if a tag was minted here, "0"
    # if an existing tag was reused - callers check it right after the call,
    # before the next tag_commit_if_needed invocation overwrites it.
    local repo="$1" sha="$2" out_var="$3" next_tag ref_to_use

    get_latest_tag "$repo"

    if [ -n "$LATEST_TAG_SHA" ] && [ "$LATEST_TAG_SHA" = "$sha" ]; then
        ref_to_use="$LATEST_TAG_NAME"
        TAG_WAS_NEW="0"
    else
        acquire_lock "$repo" "$sha"
        # Re-check under the lock in case another machine minted a tag for
        # this same SHA while we were building.
        get_latest_tag "$repo"
        if [ -n "$LATEST_TAG_SHA" ] && [ "$LATEST_TAG_SHA" = "$sha" ]; then
            ref_to_use="$LATEST_TAG_NAME"
            TAG_WAS_NEW="0"
        else
            next_tag=$(compute_next_tag "$LATEST_TAG_NAME")
            gh_request POST "/repos/${repo}/git/refs" \
                "{\"ref\":\"refs/tags/${next_tag}\",\"sha\":\"${sha}\"}"
            [ "$GH_STATUS" = "201" ] || fail "could not create tag ${next_tag} for ${repo} (HTTP ${GH_STATUS}): ${GH_BODY}"
            ref_to_use="$next_tag"
            TAG_WAS_NEW="1"
        fi
        release_lock
    fi

    printf -v "$out_var" '%s' "$ref_to_use"
}
