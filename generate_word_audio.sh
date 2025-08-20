#!/bin/bash

API_KEY="???"
API_URL="https://api.sws.speechify.com/v1/audio/speech"

# Optional: ensure the audio folder exists
mkdir -p audio

i=1
# read last line even if no trailing newline
while IFS= read -r word || [[ -n "$word" ]]; do
  if [[ -n "$word" ]]; then
    echo "[$i] Requesting audio for: \"$word\""

    # Build JSON safely (avoids quoting/escaping issues)
    payload=$(jq -n \
      --arg input "$word" \
      --arg voice_id "erin" \
      --arg audio_format "mp3" \
      '{input:$input, voice_id:$voice_id, audio_format:$audio_format}')

    # Capture HTTP code and JSON body to a temp file
    tmp_json=$(mktemp)
    http_code=$(
      curl -s -o "$tmp_json" -w "%{http_code}" -X POST "$API_URL" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload"
    )

    if [[ "$http_code" == "200" ]]; then
      out="audio/word_$i.mp3"

      # Extract and decode audio_data -> MP3
      if jq -r '.audio_data // empty' "$tmp_json" | base64 --decode > "$out" 2>/dev/null; then
        if [[ -s "$out" ]]; then
          echo "   ✔ Saved: $out"
        else
          echo "   ✖ Decoded file is empty"
          echo "   --- Response from server ---"
          cat "$tmp_json"
          echo "   ----------------------------"
          rm -f "$out"
        fi
      else
        echo "   ✖ base64 decode failed"
        echo "   --- Response from server ---"
        cat "$tmp_json"
        echo "   ----------------------------"
        rm -f "$out"
      fi
    else
      echo "   ✖ Request failed with HTTP $http_code"
      echo "   --- Response from server ---"
      cat "$tmp_json"
      echo "   ----------------------------"
      rm -f "audio/word_$i.mp3"
    fi

    rm -f "$tmp_json"
    echo
    ((i++))
    sleep 1
  fi
done < words.txt
