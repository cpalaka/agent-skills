#!/bin/bash
# Chained stem separation: Mel-Band Roformer (vocals) -> htdemucs_ft (drums/bass/other).
# Usage: stemsplit.sh <audio-file> [--six-stem] [--keep-instrumental] [--no-copy-source]
#                     [--no-analyze] [--artist NAME] [--title NAME]
set -euo pipefail

# Every path is overridable, so a machine that installed the tools elsewhere
# needs no edit to this file. Defaults match the documented setup.
DEMUCS_BIN="${STEMSPLIT_DEMUCS:-$HOME/.local/share/stem-split/demucs/.venv/bin/demucs}"
MODEL_DIR="${STEMSPLIT_MODEL_DIR:-$HOME/.local/share/stem-split/models}"
STEMS_ROOT="${STEMSPLIT_OUT:-$HOME/Music/stems}"
ROFORMER_MODEL="${STEMSPLIT_ROFORMER:-vocals_mel_band_roformer.ckpt}"
# A demucs on PATH wins over a missing venv, so a pip/uv install just works.
[ -x "$DEMUCS_BIN" ] || DEMUCS_BIN="$(command -v demucs || echo "$DEMUCS_BIN")"

ANALYZE_PY="$(dirname "$0")/analyze.py"
# librosa ships as an audio-separator dependency, so its interpreter already has
# what analyze.py needs; any python3 with librosa works just as well.
ANALYZE_PYTHON="${STEMSPLIT_PYTHON:-$HOME/.local/share/uv/tools/audio-separator/bin/python}"
[ -x "$ANALYZE_PYTHON" ] || ANALYZE_PYTHON="$(command -v python3 || true)"

IN=""; SIX_STEM=0; KEEP_INST=0; ARTIST_OVERRIDE=""; TITLE_OVERRIDE=""; ANALYZE=1; COPY_SOURCE=1
while [ $# -gt 0 ]; do
  case "$1" in
    --six-stem) SIX_STEM=1; shift ;;
    --no-analyze) ANALYZE=0; shift ;;
    --no-copy-source) COPY_SOURCE=0; shift ;;
    --keep-instrumental) KEEP_INST=1; shift ;;
    --artist) ARTIST_OVERRIDE="$2"; shift 2 ;;
    --title) TITLE_OVERRIDE="$2"; shift 2 ;;
    *) IN="$1"; shift ;;
  esac
done

[ -n "$IN" ] || { echo "ERROR: no input file given" >&2; exit 1; }
[ -f "$IN" ] || { echo "ERROR: input file not found: $IN" >&2; exit 1; }
[ -x "$DEMUCS_BIN" ] || { echo "ERROR: demucs not found at $DEMUCS_BIN" >&2; exit 1; }
command -v audio-separator >/dev/null || { echo "ERROR: audio-separator not on PATH" >&2; exit 1; }
command -v ffmpeg >/dev/null || { echo "ERROR: ffmpeg not on PATH" >&2; exit 1; }

# demucs device. Hardcoding one is a portability trap: `mps` exists only on Apple
# Silicon, and a wrong value either aborts the run or drops to CPU -- which still
# produces correct stems, just far slower, so the degradation never shows up in the
# output. Resolve it from the interpreter that will actually run demucs, and say
# which one won, so a CPU fallback is visible rather than merely slow.
# Resolve the symlink first: a uv/pipx install puts a shim in ~/.local/bin and the
# real interpreter in the tool's own venv, so dirname of the *link* finds no python
# and the probe silently falls through to a system python3 that has no torch.
DEMUCS_PYTHON="$(dirname "$(readlink -f "$DEMUCS_BIN")")/python"
[ -x "$DEMUCS_PYTHON" ] || DEMUCS_PYTHON="$(command -v python3 || true)"
DEVICE="${STEMSPLIT_DEVICE:-}"
if [ -z "$DEVICE" ] && [ -x "$DEMUCS_PYTHON" ]; then
  DEVICE=$("$DEMUCS_PYTHON" -c 'import torch; print("cuda" if torch.cuda.is_available() else "mps" if getattr(torch.backends,"mps",None) and torch.backends.mps.is_available() else "cpu")' 2>/dev/null || true)
fi
# An unanswerable probe is not the same fact as "no GPU here", and collapsing the two
# is what made the first version of this report cpu on a machine with a working 4080.
if [ -z "$DEVICE" ]; then
  echo "WARNING: could not probe torch via ${DEMUCS_PYTHON:-<none>}; assuming cpu." >&2
  DEVICE=cpu
fi

tag() { ffprobe -v error -show_entries "format_tags=$1" -of default=nw=1:nk=1 "$IN" 2>/dev/null | head -1; }
sanitize() { echo "$1" | tr '/:' '--' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

ARTIST="${ARTIST_OVERRIDE:-$(tag ARTIST)}"
TITLE="${TITLE_OVERRIDE:-$(tag TITLE)}"
BASE="$(basename "$IN")"; BASE="${BASE%.*}"
[ -n "$ARTIST" ] || ARTIST="Unknown Artist"
# Fall back to the filename with any leading track number stripped.
[ -n "$TITLE" ] || TITLE="$(echo "$BASE" | sed -E 's/^[0-9]+[[:space:]]*[-._]?[[:space:]]*//')"
ARTIST="$(sanitize "$ARTIST")"; TITLE="$(sanitize "$TITLE")"

OUT="$STEMS_ROOT/$ARTIST/$TITLE"

# Scratch lives on local temp, never beside the output and never on the source
# volume: the input may sit on a network share, and ~90 MB of intermediates has
# no business in the music library. Guard the root explicitly - an empty TMPDIR
# would make WORK a path at filesystem root, and the rm -rf at the end is real.
TMPROOT="${TMPDIR:-/tmp}"
[ -n "$TMPROOT" ] && [ -d "$TMPROOT" ] || { echo "ERROR: no usable temp dir (TMPDIR='${TMPDIR:-}')" >&2; exit 1; }
WORK="$TMPROOT/stemsplit.$$"
case "$WORK" in /*/*) : ;; *) echo "ERROR: refusing to use unsafe work dir '$WORK'" >&2; exit 1 ;; esac
rm -rf "$WORK"; mkdir -p "$WORK" "$OUT"

SRC_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$IN")
echo "==> $ARTIST / $TITLE  (${SRC_DUR%.*}s)"
echo "    output: $OUT"

# Stage locally so neither model reads repeatedly over a network mount.
#
# Network mounts hand back corrupt reads without saying so - observed on an SMB
# mount, where a bad copy hashed stable for minutes because macOS cached it, and
# the file's own mtime never moved. So decode the staged copy before spending
# GPU time on it, and re-copy if it does not survive.
LOCAL="$WORK/source.${IN##*.}"
STAGED=0
for attempt in 1 2 3; do
  # Plain cp reads through the macOS unified buffer cache, which will happily
  # serve back the same corrupt bytes it served last time - that is why a bad
  # copy hashes stable. Read with F_NOCACHE so each retry actually re-fetches.
  # An uncached read is also slower and less resilient than cp - on a flaky SMB
  # mount it can time out outright with ETIMEDOUT where cp survives. So fall
  # back rather than fail: a cached copy that passes the decode gate below is
  # still a good copy, and the next attempt tries uncached again.
  if ! python3 - "$IN" "$LOCAL" <<'PY'
import fcntl, os, sys
src, dst = sys.argv[1], sys.argv[2]
fd = os.open(src, os.O_RDONLY)
fcntl.fcntl(fd, 48, 1)  # F_NOCACHE
with open(dst, "wb") as out:
    while True:
        b = os.read(fd, 1 << 20)
        if not b: break
        out.write(b)
os.close(fd)
PY
  then
    echo "    uncached read failed (attempt $attempt) - falling back to cp"
    cp "$IN" "$LOCAL" || { echo "    copy failed (attempt $attempt)"; sleep 2; continue; }
  fi
  # ffmpeg exits 0 AND prints nothing when it decodes zero audio frames from a
  # container whose header still claims a full-length stream - observed on a
  # corrupt SMB read with whole megabytes duplicated. Absence of stderr is
  # therefore not the signal; decoded length is. ffprobe's stream=duration is
  # no use either, since it just echoes the header's claim (324s against 0s of
  # real audio on that copy). Only ffmpeg's time= counts samples that actually
  # came out of the decoder.
  ERRS=$(ffmpeg -nostdin -v error -i "$LOCAL" -f null - 2>&1 </dev/null)
  GOT=$(ffmpeg -nostdin -hide_banner -i "$LOCAL" -f null - 2>&1 </dev/null | tr '\r' '\n' \
        | grep -o 'time=[0-9][0-9]:[0-9][0-9]:[0-9][0-9]' | tail -1 \
        | awk -F'[=:]' '{print $2*3600 + $3*60 + $4}')
  WANT=${SRC_DUR%.*}
  if [ -z "$ERRS" ] && [ -n "$GOT" ] && [ "$GOT" -ge $((WANT - 1)) ]; then STAGED=1; break; fi
  echo "    staged copy failed to decode (attempt $attempt: decoded ${GOT:-0}s of ${WANT}s) - re-copying"
  sleep 2
done
[ "$STAGED" = "1" ] || { echo "ERROR: could not stage a decodable copy of $IN after 3 attempts. If it lives on a network share, the mount may be returning corrupt reads; copy it locally by hand and check it." >&2; exit 1; }

# Hand the models PCM rather than the original container. audio-separator reads
# via librosa, which reaches for libsndfile first and falls back to CoreAudio;
# libsndfile refuses some perfectly valid FLACs ("unknown error in flac
# decoder" on a 4608-sample blocksize), and the CoreAudio fallback then dies
# with a bare "error -50" that looks like a corrupt file rather than a decoder
# gap. ffmpeg decodes all of them, and this is lossless and native-rate, so the
# samples the models see are unchanged.
DECODED="$WORK/decoded.wav"
ffmpeg -nostdin -v error -y -i "$LOCAL" -map 0:a:0 -c:a pcm_s24le "$DECODED" </dev/null \
  || { echo "ERROR: could not decode $IN to PCM" >&2; exit 1; }

# Stage 1 — Roformer: best-in-class vocal isolation. normalization 1.0 only
# clip-protects, so stem levels stay true to the source (0.9 rescales them).
echo "==> [1/2] Mel-Band Roformer: vocals + instrumental"
audio-separator "$DECODED" -m "$ROFORMER_MODEL" \
  --model_file_dir "$MODEL_DIR" --output_dir "$WORK/rf" \
  --output_format WAV --normalization 1.0 >"$WORK/rf.log" 2>&1 \
  || { echo "ERROR: Roformer stage failed; see $WORK/rf.log" >&2; exit 1; }

INST=$(find "$WORK/rf" -name "*_(other)_*.wav" | head -1)
VOX=$(find "$WORK/rf" -name "*_(vocals)_*.wav" | head -1)
[ -n "$INST" ] && [ -n "$VOX" ] || { echo "ERROR: Roformer produced no stems; see $WORK/rf.log" >&2; exit 1; }

# Stage 2 — demucs splits the now vocal-free instrumental. It cannot smear a
# vocal into the guitars that is no longer there.
if [ "$SIX_STEM" = "1" ]; then MODEL="htdemucs_6s"; else MODEL="htdemucs_ft"; fi
echo "==> [2/2] $MODEL on $DEVICE: drums + bass + other"
[ "$DEVICE" = cpu ] && echo "    WARNING: no GPU backend detected; this stage will be very slow." >&2
mv "$INST" "$WORK/instrumental.wav"
"$DEMUCS_BIN" -d "$DEVICE" -n "$MODEL" --int24 -o "$WORK/dm" "$WORK/instrumental.wav" \
  >"$WORK/dm.log" 2>&1 \
  || { echo "ERROR: demucs stage failed; see $WORK/dm.log" >&2; exit 1; }
SPLIT="$WORK/dm/$MODEL/instrumental"

# Assemble. Vocals come from Roformer; everything else from demucs. 24-bit
# throughout, for headroom through an Ableton processing chain.
echo "==> assembling 24-bit WAV stems"
ffmpeg -v error -y -i "$VOX" -c:a pcm_s24le "$OUT/vocals.wav"
STEMS="vocals drums bass other"
[ "$SIX_STEM" = "1" ] && STEMS="vocals drums bass other guitar piano"
for s in $STEMS; do
  [ "$s" = "vocals" ] && continue
  [ -f "$SPLIT/$s.wav" ] && cp "$SPLIT/$s.wav" "$OUT/$s.wav"
done
[ "$KEEP_INST" = "1" ] && ffmpeg -v error -y -i "$WORK/instrumental.wav" -c:a pcm_s24le "$OUT/instrumental.wav"

# Verify: every stem full-length and carrying signal. A separation can exit 0
# and emit silence, so check the audio rather than the exit code.
#
# A wrong length is always a bug. A silent stem is not — a track with no piano
# gives an empty piano stem, and an instrumental passage gives an empty vocal
# one. So silence is reported for a human to judge, and only hard-fails when
# every stem is empty, which means the pipeline itself produced nothing.
echo "==> verification"
FAIL=0; NSTEM=0; NSILENT=0
for f in "$OUT"/*.wav; do
  n=$(basename "$f")
  d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
  peak=$(ffmpeg -hide_banner -nostats -i "$f" -af volumedetect -f null /dev/null 2>&1 \
         | grep -oE "max_volume: [-0-9.]+" | awk '{print $2}')
  drift=$(awk -v a="$d" -v b="$SRC_DUR" 'BEGIN{d=a-b; print (d<0?-d:d)}')
  status="ok"
  NSTEM=$((NSTEM + 1))
  awk -v x="$drift" 'BEGIN{exit !(x>0.5)}' && { status="LENGTH MISMATCH"; FAIL=1; }
  awk -v p="$peak" 'BEGIN{exit !(p<-60)}' && { status="EMPTY - expected for this track?"; NSILENT=$((NSILENT + 1)); }
  printf "    %-16s %6.1fs  peak %6s dB  %s\n" "$n" "$d" "$peak" "$status"
done
[ "$NSTEM" -gt 0 ] && [ "$NSILENT" = "$NSTEM" ] && { echo "    all stems empty - the pipeline produced nothing" >&2; FAIL=1; }

# Keep the original mix beside its stems, so the folder is self-contained: the
# source may live on a network share or an external drive that is not mounted
# the next time someone opens the Ableton set, and a stem folder without the
# mix cannot be A/B'd against it.
#
# Copy the staged local file rather than re-reading the original. It is the one
# that already survived the decode check above, so the copy is verified for
# free — and it costs no second read over a mount that hands back silent
# corruption. Only on a clean run: a folder of failed stems should not look
# finished.
if [ "$COPY_SOURCE" = "1" ] && [ "$FAIL" != "1" ]; then
  SRC_COPY="$OUT/$BASE.${IN##*.}"
  # A source literally named "drums.wav" would otherwise clobber that stem.
  case "$(basename "$SRC_COPY")" in
    vocals.wav|drums.wav|bass.wav|other.wav|guitar.wav|piano.wav|instrumental.wav)
      SRC_COPY="$OUT/$BASE (source).${IN##*.}" ;;
  esac
  cp "$LOCAL" "$SRC_COPY"
  echo "==> source mix kept: $(basename "$SRC_COPY")"
fi

rm -rf "$WORK"
if [ "$FAIL" = "1" ]; then echo "==> FAILED verification" >&2; exit 1; fi

# BPM and key, measured off the finished stems. Analysis failing leaves the
# stems perfectly usable, so it never fails the run.
if [ "$ANALYZE" = "1" ] && [ -x "$ANALYZE_PYTHON" ]; then
  echo "==> analysis"
  "$ANALYZE_PYTHON" "$ANALYZE_PY" "$OUT" || echo "    analysis unavailable (stems are fine)"
fi

echo "==> done: $OUT"
