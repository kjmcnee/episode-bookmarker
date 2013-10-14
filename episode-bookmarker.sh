#!/bin/bash
# episode-bookmarker.sh
# Keeps track of watched episodes

usage(){
    echo "Usage:" >&2
    echo -e "$0 start series_name path/to/series\n\tStart bookmarking a series whose files are in the given directory" >&2
    echo -e "$0 finish series_name\n\tRemove bookmark for the series" >&2
    echo -e "$0 play series_name\n\tPlay the currently bookmarked episode" >&2
    echo -e "$0 next series_name\n\tAdvance the bookmark to the next episode" >&2
    echo -e "$0 prev series_name\n\tMove the bookmark back to the previous episode" >&2
    echo -e "$0 progress series_name\n\tShow how much of the series you've watched" >&2
    echo -e "$0 list\n\tList the series being bookmarked by this script" >&2
    exit 1
}

# this file stores the bookmark information
# it has the following form:
# each series takes up 3 lines,
# one for each of the following: the series name, the directory, and the current episode
bookmarks_file="${HOME}/.episode_bookmarks"
# if it doesn't exist, create it
[ -f "${bookmarks_file}" ] || > "${bookmarks_file}"

list_of_series(){
    # sed gets every third line (the lines with the series names)
    sed -n '1~3p' "${bookmarks_file}"
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
    sed -i "N;N;s/^$1\n\(.*\)\n.*/$1\n\1\n$2/" "${bookmarks_file}"
}


# start bookmarking a new series
# $1 is the series name
# $2 is the path to the series
start_series(){
    abs_path="$(readlink -f "$2")"
    first_episode="$(ls "${abs_path}" | head -n 1)"

    if [ "${first_episode}" = "" ]; then
        echo "Error: There's nothing to bookmark in ${abs_path}" >&2
        exit 1
    fi

    echo "Now bookmarking $1"
    echo "The bookmark is set to the first episode: ${first_episode}"

    # store the bookmark
    echo "$1" >> ${bookmarks_file}
    echo "${abs_path}" >> ${bookmarks_file}
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
    next="$(ls "${series_path}" | grep -A 1 "^${current_episode}$" | tail -n 1)"

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
    prev="$(ls "${series_path}" | grep -B 1 "^${current_episode}$" | head -n 1)"

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
    ls "$(get_series_path "$1")" | sed "s/^/    /" | sed "s/    \($(get_current_episode "$1")\)/ -> \1/"
    
    num_current_episode="$(ls "$(get_series_path "$1")" | grep -n "$(get_current_episode "$1")" | sed "s/\([0-9]*\):.*/\1/")"
    num_total_episodes="$(ls "$(get_series_path "$1")" | wc -l)"
    echo Current episode: $(get_current_episode "$1") \(${num_current_episode} of ${num_total_episodes}\)
}

# print usage if no args
[ $# -gt 0 ] || usage

case "$1" in
    start)
        [ $# -eq 3 ] || usage 
        # validate series uniqueness
        if series_exists "$2" ; then
            echo "Error: The series $2 is already being bookmarked" >&2
            exit 1
        fi

        start_series "$2" "$3"
        ;;
    finish | play | next | prev | progress)
        [ $# -eq 2 ] || usage
        # exit if series not found
        if ! series_exists "$2" ; then
            echo "Error: $2 ain't no series I ever heard of!" >&2
            exit 1
        fi

        case "$1" in
            finish)
                finish_series "$2"
                ;;
            play)
                play_current_episode "$2"
                ;;
            next)
                next_episode "$2"
                ;;
            prev)
                prev_episode "$2"
                ;;
            progress)
                show_progress "$2"
                ;;
        esac
        ;;
    list)
        list_of_series
        ;;
    *)
        echo "Unknown action: $1" >&2
        usage
        ;;
esac
