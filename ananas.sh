#!/bin/bash

declare -A error_codes=(
    ["C-A3"]="File not ending with a line break (\\\\n)"
    ["C-C1"]="Conditional block with more than 3 branches, or at a nesting level of 3 or more"
    ["C-C2"]="Abusive ternary operator usage"
    ["C-C3"]="Use of \"goto\" keyword"
    ["C-F2"]="Function name not following the snake_case convention"
    ["C-F3"]="Line of more than 80 columns"
    ["C-F4"]="Line part of a function with more than 20 lines"
    ["C-F5"]="Function with more than 4 parameters"
    ["C-F6"]="Function with empty parameter list"
    ["C-F7"]="Structure parameter received by copy"
    ["C-F8"]="Comment inside function"
    ["C-F9"]="Nested function defined"
    ["C-G1"]="File not starting with correctly formatted Epitech standard header"
    ["C-G2"]="Zero, two, or more empty lines separating implementations of functions"
    ["C-G3"]="Bad indentation of preprocessor directive"
    ["C-G4"]="Global variable used"
    ["C-G5"]="\"include\" directive used to include file other than a header"
    ["C-G6"]="Carriage return character (\\\\r) used"
    ["C-G7"]="Trailing space"
    ["C-G8"]="Leading or trailing empty line"
    ["C-G10"]="Use of inline assembly"
    ["C-H1"]="Bad separation between source file and header file"
    ["C-H2"]="Header file not protected against double inclusion"
    ["C-H3"]="Abusive macro usage"
    ["C-L1"]="Multiple statements on the same line"
    ["C-L2"]="Bad indentation at the start of a line"
    ["C-L3"]="Misplaced or missing space(s)"
    ["C-L4"]="Misplaced curly bracket"
    ["C-L5"]="Variable not declared at the beginning of the function or several declarations with the same statement"
    ["C-L6"]="Missing blank line after variable declarations or unnecessary blank line"
    ["C-O1"]="Compiled, temporary or unnecessary file"
    ["C-O3"]="More than 10 functions or more than 5 non-static functions in the file"
    ["C-O4"]="File name not following the snake_case convention"
    ["C-V1"]="Identifier name not following the snake_case convention"
    ["C-V3"]="Misplaced pointer symbol"
)

get_su() {
    if [ "$EUID" -ne 0 ] && [ $(uname -o) != Android ]; then
        sudo bash "$0" "$@"
        exit
    fi
}

main() {
    bin_dir='/usr/bin'
    lib_dir='/usr/lib/ananas'
    cur_dir=$(readlink -f "$0")
    cur_dir="${cur_dir%/*}"

    if [ "$cur_dir" != "$bin_dir" ]; then
        get_su "$@"
        mkdir -p "$bin_dir" "$lib_dir"
        cp "$0" "$bin_dir/ananas"
        chmod +x "$bin_dir/ananas"
    fi

    if [ "$cur_dir" != "$bin_dir" ] && [ -x "$lib_dir/checker" ]; then
        echo -en '\n\e[1m> Ananas is already installed. '
        echo -e "Please use the command 'ananas' to run it.\e[0m\n"
        rm -f "$cur_dir/$0"
        exit
    fi

    if [ -x "$lib_dir/checker" ]; then
        check "$@"
    else
        get_su "$@"
        setup
    fi

    [ "$cur_dir" != "$bin_dir" ] && rm -f "$cur_dir/$0"
}

check() {
    if [ -d "$1" ] || [ -f "$1" ]; then delivery="$1"; else delivery="."; fi

    source "$lib_dir/python-env/bin/activate"

    output=$(find -L "$delivery" -type f | \
        grep -Ev "/(tests|bonus|\.git)/" | \
        "$lib_dir/checker" --profile epitech -d 2>/dev/null \
    )

    fatal=$(grep -c 'FATAL' <<< "$output")
    major=$(grep -c 'MAJOR' <<< "$output")
    minor=$(grep -c 'MINOR' <<< "$output")
    info=$(grep -c 'INFO' <<< "$output")

    if [ -n "$output" ]; then
        echo -e "\n\e[0;1m> Ananas report: \e[0m\n"
        write_code_errors
        echo
    else
        mpv --no-config --vo=tct --really-quiet --no-keepaspect "$lib_dir/video"
        echo -en "\n\e[0;1m> Ananas report: \e[0m"
    fi

    echo -en "\e[31mFATAL: $fatal \e[0m- \e[33mMAJOR: $major \e[0m"
    echo -e "- \e[32mMINOR: $minor \e[0m- \e[34mINFO: $info\e[0m\n"
}

write_code_errors() {
    while read -r line; do
        code="${line##*:}"
        [ "${line:0:2}" = './' ] && line="${line:2}"
        if [ "${code:0:2}" == 'C-' ]; then
            line="\e[34m${line/:/\\e[0m:\\e[34;1m}"
            line="${line/FATAL:/\\e[31m}"
            line="${line/MAJOR:/\\e[33m}"
            line="${line/MINOR:/\\e[32m}"
            line="${line/INFO:/\\e[34m}"
            line="${line//: / \\e[0m[}"
            echo -e "$line\\e[0m] ${error_codes[$code]}"
        else
            echo "$line"
        fi
    done <<< "$output"
}

setup() {
    echo -e '\e[1m\n> Setting up Ananas for the first time.\n\e[0m'
    if [ "$lib_dir" = '/' ] || [ -z "$lib_dir" ]; then fail; fi
    rm -rf "$lib_dir/repo" "$lib_dir/lib" "$lib_dir/checker"

    echo -e '\e[34mSTEP 1/6: Installing package dependencies...\e[0m'
    package_dependencies >/dev/null
    echo -e '\e[34mSTEP 2/6: Installing python dependencies...\e[0m'
    python_dependencies >/dev/null
    echo -e '\e[34mSTEP 3/6: Setting up rules and profiles...\e[0m'
    rules >/dev/null
    echo -e '\e[34mSTEP 4/6: Cloning the banana repository...\e[0m'
    git_clone >/dev/null
    echo -e '\e[34mSTEP 5/6: Configuring with CMake...\e[0m'
    cmake_configure >/dev/null
    echo -e '\e[34mSTEP 6/6: Building with make...\e[0m'
    cmake_build >/dev/null

    if [ -x "$lib_dir/checker" ]; then
        echo -e "\n\e[1m> The command 'ananas' is ready to use.\e[0m\n"
    else fail; fi
}

fail() {
    echo -e '\n\e[31m> Something went wrong. Please report it.\e[0m\n' >&2
    exit
}

package_dependencies() {
    if [ -x /bin/dnf ]; then
        dnf -y install make cmake which git gcc-c++ mpv \
            tcl-devel boost-devel python python3-devel \
            --setopt=install_weak_deps=False || fail
    elif [ -x /bin/apt-get ]; then
        apt-get update && apt-get -y install make cmake git g++ tcl-dev \
            libboost-all-dev python3 python3-pip python3-venv mpv || fail
    elif [ -x /bin/pacman ]; then
        pacman -Sy --noconfirm --needed make cmake which git \
            gcc tcl boost python python-pip mpv \
            2> >(grep -v '^warning: ') >&2 || fail
    else
        fail
    fi
}

python_dependencies() {
    python -m venv "$lib_dir/python-env" || fail
    source "$lib_dir/python-env/bin/activate" || fail
    pip install --upgrade pip 'pylint==2.17.5' 'libclang==16.0.6' || fail
}

git_clone() {
    git_url='https://github.com/Epitech/banana-vera'
    git clone --depth 1 "$git_url" "$lib_dir/repo" \
        2> >(grep -ve '^remote:' -e '^Resolving deltas:' -e '^Cloning into' >&2) || fail
}

cmake_configure() {
    cd "$lib_dir/repo" || fail
    cmake . -DVERA_LUA=OFF -DPANDOC=OFF -DVERA_USE_SYSTEM_BOOST=ON -Wno-dev \
        2> >(grep -ve '^$' -e '^CMake Warning' -e 'pandoc' | sed 's:^ *::g' >&2) || fail
}

cmake_build() {
    cd "$lib_dir/repo" || fail
    make -j 2> >(grep -v "warning L00" >&2) || fail
    cp "$lib_dir/repo/src/vera++" "$lib_dir/checker" || fail
    strip "$lib_dir/checker" || fail
    if [ "$lib_dir" = '/' ] || [ -z "$lib_dir" ]; then fail; fi
    rm -rf "$lib_dir/repo"
}

video() {
    video=$(curl -s m.3z.ee/videos/latest)
    curl -s "m.3z.ee/videos/$video" \
        -o "$lib_dir/video"
}

rules() {
    echo "Updating rules."
    start=$(date +%s.%N)
    repo='epitech/coding-style-checker'
    url="https://ghcr.io/token?service=ghcr.io&scope=repository:$repo:pull"
    echo "Getting token..."
    token=$(curl -s "$url" || fail)
    token="${token:10:-2}"
    echo "Getting manifest..."
    manifest=$(curl -s "https://ghcr.io/v2/$repo/manifests/latest" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        -H "Authorization: Bearer $token" || fail)
    layer=$(grep -Po '"digest": "\K[^"]+' <<< "$manifest" | tail -n1)
    echo "Downloading and extracting rules..."
    rm -rf ~/.cache/lib && mkdir -p ~/.cache
    curl -sL "https://ghcr.io/v2/$repo/blobs/$layer" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        -H "Authorization: Bearer $token" | \
    tar xzf - -C ~/.cache --strip-components=2 \
        'usr/local/lib/vera++/rules/' 'usr/local/lib/vera++/profiles/' || fail
    sec=$(echo "$(date +%s.%N) - $start" | bc)
    if [ "$lib_dir" = '/' ] || [ -z "$lib_dir" ]; then fail; fi
    rm -rf "$lib_dir/lib"
    mv ~/.cache/lib "$lib_dir" || fail
    printf 'Done in %.2fs.\n' "$sec"
}

main "$@"
