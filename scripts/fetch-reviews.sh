#!/usr/bin/env bash
# Fetch reviews for a window of PRs and dump one CSV-ish line per review
set -u
REPO="jsboige/roo-extensions"
PRS=(3359 3358 3357 3356 3355 3354 3353 3352 3349 3348 3343 3340 3339 3338 3337 3336 3335 3334 3333 3332 3331 3330 3328 3327 3326 3325 3318 3317 3315 3313 3312 3311 3310 3309 3308 3307 3306 3305 3304 3303)
for pr in "${PRS[@]}"; do
  gh api "repos/${REPO}/pulls/${pr}/reviews" --jq '.[] | "PR='"$pr"' user=\(.user.login) state=\(.state) at=\(.submitted_at) sha=\(.commit_id[0:7]) first=\(.body | split("\n")[0] | gsub("\""; "\\\""))"' 2>/dev/null | sed 's/\\"/"/g'
done
