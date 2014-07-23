#!/bin/bash
# episode-bookmarker.sh
# Keeps track of watched episodes

usage(){
    script_name=$(basename $0 .sh)

    echo "Usage:" >&2
    echo -e "${script_name} start path/to/series [series_name]\n\tStart bookmarking a series whose files are in the given directory\n" >&2
    echo -e "${script_name} finish [series_name]\n\tRemove bookmark for the series\n" >&2
    echo -e "${script_name} play [series_name]\n\tPlay the currently bookmarked episode\n" >&2
    echo -e "${script_name} next [series_name]\n\tAdvance the bookmark to the next episode\n" >&2
    echo -e "${script_name} prev [series_name]\n\tMove the bookmark back to the previous episode\n" >&2
    echo -e "${script_name} progress [series_name]\n\tShow how much of the series you've watched\n" >&2
    echo -e "${script_name} list\n\tList the series being bookmarked by this script\n" >&2
    echo "The series_name can be omitted." >&2
    echo "For the start function, the name will be inferred from the path (e.g. path/to/series -> series)." >&2
    echo "For the rest, the series will be the most recently used one." >&2
    echo "Escaping spaces in the series_name is not required." >&2
    exit 1
}

# this file stores the bookmark information
# it has the following form:
# each series takes up 3 lines,
# one for each of the following: the series name, the directory, and the current episode
# series are ordered from most recently used to least recently used
bookmarks_file="${HOME}/.episode_bookmarks"
# if it doesn't exist, create it
[ -f "${bookmarks_file}" ] || > "${bookmarks_file}"

list_of_series(){
    # sed gets every third line (the lines with the series names)
    sed -n '1~3p' "${bookmarks_file}"
}

get_most_recently_used_series(){
    # since the series are ordered, the most recently used series name is simply the first line
    head -n 1 "${bookmarks_file}"
}

# moves the series to the top of the file
# $1 is the series name
set_most_recently_used_series(){
    # keep the series information
    path="$(get_series_path "$1")"
    episode="$(get_current_episode "$1")"

    # remove it from the file
    sed -i "/^$1$/{N;N;d;}" "${bookmarks_file}"

    # then put it back at the top
    echo -e "$1\n${path}\n${episode}" | cat - "${bookmarks_file}" > "${bookmarks_file}.tmp"
    mv "${bookmarks_file}.tmp" "${bookmarks_file}"
}

# check if the series is being bookmarked
# $1 is the series name
series_exists(){
    list_of_series | grep "^$1$" >/dev/null
}

# return the series path
# $1 is the series name
get_series_path(){
    sed -n "/^$1$/{n;p;}" "${bookmarks_file}"
}

# return the current episode for a series
# $1 is the series name
get_current_episode(){
    sed -n "/^$1$/{n;n;p;}" "${bookmarks_file}"
}

# update the episode bookmark
# $1 is the series name
# $2 is the new episode
set_current_episode(){
    sed -i "N;N;s|^$1\n\(.*\)\n.*|$1\n\1\n$2|" "${bookmarks_file}"
}

# list the episodes of the series
# $1 is the absolute path to the series
list_episodes(){
    find "$1" -type f -not -name "*.srt" | sort | sed "s|$1/||"
}

# start bookmarking a new series
# $1 is the series name
# $2 is the absolute path to the series
start_series(){
    first_episode="$(list_episodes "$2" | head -n 1)"

    if [ "${first_episode}" = "" ]; then
        echo "Error: There's nothing to bookmark in $2" >&2
        exit 1
    fi

    echo "Now bookmarking $1"
    echo "The bookmark is set to the first episode: ${first_episode}"

    # store the bookmark
    echo "$1" >> ${bookmarks_file}
    echo "$2" >> ${bookmarks_file}
    echo "${first_episode}" >> ${bookmarks_file}
}

# remove bookmark for a series
# $1 is the series name
finish_series(){
    echo "Removing bookmark for $1"

    # inplace deletes the line with the series name and the following two lines (path and current episode)
    sed -i "/^$1$/{N;N;d;}" "${bookmarks_file}"
}

# play the currently bookmarked episode
# $1 is the series name
play_current_episode(){
    series_path="$(get_series_path "$1")"
    episode_file="$(get_current_episode "$1")"

    echo Playing ${episode_file}

    xdg-open "${series_path}/${episode_file}" &>/dev/null
}

# advance bookmark to next episode
# $1 is the series name
next_episode(){
    series_path="$(get_series_path "$1")"
    current_episode="$(get_current_episode "$1")"
    next="$(list_episodes "${series_path}" | grep -A 1 "^${current_episode}$" | tail -n 1)"

    if [ "${next}" = "${current_episode}" ]; then
        echo "${current_episode} is the last episode of $1"
    else
        echo Advancing bookmark to ${next}
        set_current_episode "$1" "${next}"
    fi
}

# move bookmark back to previous episode
# $1 is the series name
prev_episode(){
    series_path="$(get_series_path "$1")"
    current_episode="$(get_current_episode "$1")"
    prev="$(list_episodes "${series_path}" | grep -B 1 "^${current_episode}$" | head -n 1)"

    if [ "${prev}" = "${current_episode}" ]; then
        echo "${current_episode} is the first episode of $1"
    else
        echo "Moving bookmark back to ${prev}"
        set_current_episode "$1" "${prev}"
    fi
}

# show episode list followed by episode progress
# $1 is the series name
show_progress(){
    echo "$1:"

    # list episodes and prepend "->" to indicate the current episode
    list_episodes "$(get_series_path "$1")" | sed "s|^|    |" | sed "s|    \($(get_current_episode "$1")\)| -> \1|"

    num_current_episode="$(list_episodes "$(get_series_path "$1")" | grep -n "$(get_current_episode "$1")" | sed "s|\([0-9]*\):.*|\1|")"
    num_total_episodes="$(list_episodes "$(get_series_path "$1")" | wc -l)"
    echo Current episode: $(get_current_episode "$1") \(${num_current_episode} of ${num_total_episodes}\)
}

# print usage if no args
[ $# -gt 0 ] || usage

case "$1" in
    start)

        [ $# -ge 2 ] || usage

        path_to_series="$(readlink -f "$2")"

        if [ $# -ge 3 ] ; then
            # in order to avoid requiring the user to manually escape spaces
            # or quote the series_name from the command line,
            # we treat the rest of the args as part of the series name, instead of just $3
            series_name="${@:3}"
        else
            # infer the series name from the path if it is not given
            series_name=$(basename "${path_to_series}")
        fi

        # validate series uniqueness
        if series_exists "${series_name}" ; then
            echo "Error: The series ${series_name} is already being bookmarked" >&2
            exit 1
        fi

        start_series "${series_name}" "${path_to_series}"

        set_most_recently_used_series "${series_name}"
        ;;
    finish | play | next | prev | progress)
        if [ $# -ge 2 ] ; then
            series_name="${@:2}" # see above for how series_name is determined from remaining args
        else
            # use the previous series if it is not given
            series_name="$(get_most_recently_used_series)"
        fi

        # exit if series not found
        if ! series_exists "${series_name}" ; then
            echo "Error: ${series_name} ain't no series I ever heard of!" >&2
            exit 1
        fi

        case "$1" in
            finish)
                finish_series "${series_name}"
                ;;
            play)
                play_current_episode "${series_name}"
                ;;
            next)
                next_episode "${series_name}"
                ;;
            prev)
                prev_episode "${series_name}"
                ;;
            progress)
                show_progress "${series_name}"
                ;;
        esac

        if [ "$1" != "finish" ] ; then
            set_most_recently_used_series "${series_name}"
        fi
        ;;
    list)
        list_of_series
        ;;
    *)
        echo "Unknown action: $1" >&2
        usage
        ;;
esac
