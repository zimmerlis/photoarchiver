#!/bin/bash

set -u

SOURCE_DIR="${SOURCE_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"
PHOTO_DIR="${PHOTO_DIR:-/volume2/photo}"
VIDEO_DIR="${VIDEO_DIR:-/volume2/video}"
selected_folder=""

while (($#)); do
    case "$1" in
        -folder)
            if (($# < 2)); then
                printf 'Error: -folder requires a folder name.\n' >&2
                exit 2
            fi
            selected_folder="$2"
            shift 2
            ;;
        -h|--help)
            printf 'Usage: %s [-folder NAME]\n' "$(basename -- "$0")"
            printf 'Without -folder, all folders below the script directory are scanned.\n'
            exit 0
            ;;
        *)
            printf 'Error: unknown argument: %s\n' "$1" >&2
            printf 'Usage: %s [-folder NAME]\n' "$(basename -- "$0")" >&2
            exit 2
            ;;
    esac
done

if [[ -n "$selected_folder" ]]; then
    case "$selected_folder" in
        .|..|*/*)
            printf 'Error: -folder must be a single folder name.\n' >&2
            exit 2
            ;;
    esac
    SOURCE_DIR="$SOURCE_DIR/$selected_folder"
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
    printf 'Error: source directory does not exist: %s\n' "$SOURCE_DIR" >&2
    exit 1
fi

if command -v exiftool >/dev/null 2>&1; then
    EXIFTOOL_AVAILABLE=1
else
    EXIFTOOL_AVAILABLE=0
    printf 'Warning: exiftool not found; using file modification dates.\n' >&2
fi

get_capture_date() {
    local file="$1"
    local date_value=""

    if ((EXIFTOOL_AVAILABLE)); then
        date_value="$(exiftool -s3 -d '%Y-%m-%d' -DateTimeOriginal -CreateDate -MediaCreateDate -TrackCreateDate "$file" 2>/dev/null | sed -n '/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ { p; q; }')"
    fi
    if [[ -n "$date_value" ]]; then
        printf '%s\n' "$date_value"
    else
        date -r "$file" '+%Y-%m-%d'
    fi
}

archive_file() {
    local source_file="$1"
    local extension="${source_file##*.}"
    local extension_lower="${extension,,}"
    local target_root
    local capture_date
    local year
    local destination_dir
    local destination
    local base_name
    local display_root
    local manifest_name
    local manifest_file
    local manifest_entry
    local display_path
    local source_folder
    local file_size
    local suffix=1

    case "$extension_lower" in
        jpg|jpeg|png|heic|heif|tif|tiff|gif|bmp|webp|dng|cr2|cr3|nef|arw|raf|rw2|orf|pef)
            target_root="$PHOTO_DIR"
            display_root="/photo"
            manifest_name="photo_archive_readme.txt"
            ;;
        mp4|mov|m4v|avi|mkv|3gp|mts|m2ts|mpg|mpeg|wmv|webm)
            target_root="$VIDEO_DIR"
            display_root="/video"
            manifest_name="video_archive_readme.txt"
            ;;
        *)
            return 0
            ;;
    esac

    if ! capture_date="$(get_capture_date "$source_file")" || [[ ! "$capture_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        printf 'Warning: could not determine a valid date; skipping: %s\n' "$source_file" >&2
        return 0
    fi

    year="${capture_date%%-*}"
    destination_dir="$target_root/$year/$capture_date"
    mkdir -p -- "$destination_dir" || return 1
    source_folder="$(dirname -- "$source_file")"
    manifest_file="$source_folder/$manifest_name"
    destination="$destination_dir/$(basename -- "$source_file")"
    base_name="$destination"
    file_size="$(wc -c < "$source_file")" || return 1

    while [[ -e "$destination" ]]; do
        if cmp -s -- "$source_file" "$destination"; then
            if ! rm -- "$source_file"; then
                printf 'Error: identical destination exists, but source could not be removed: %s\n' "$source_file" >&2
                return 1
            fi
            printf 'Removed identical duplicate: %s\n' "$source_file"
            break
        fi
        destination="${base_name%.*}__$suffix.${base_name##*.}"
        suffix=$((suffix + 1))
    done

    if [[ -e "$source_file" ]]; then
        if mv -- "$source_file" "$destination"; then
            printf 'Moved: %s -> %s\n' "$source_file" "$destination"
        else
            printf 'Error: failed to move: %s\n' "$source_file" >&2
            return 1
        fi
    fi

    display_path="$display_root/$year/$capture_date/$(basename -- "$destination")"
    manifest_entry="$display_path ($file_size bytes)"
    if ! grep -Fqx -- "$manifest_entry" "$manifest_file" 2>/dev/null; then
        if ! printf '%s\n' "$manifest_entry" >> "$manifest_file"; then
            printf 'Error: media moved but could not update manifest: %s\n' "$manifest_file" >&2
            return 1
        fi
    fi
}

while IFS= read -r -d '' source_file; do
    archive_file "$source_file" || exit 1
done < <(find "$SOURCE_DIR" -type f -print0)