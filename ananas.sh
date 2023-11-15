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
    if [ "$EUID" -ne 0 ]; then
        sudo bash "$0" "$@"
        exit
    fi
}

main() {
    bin_dir='/bin'
    lib_dir='/lib/ananas'

    cur_dir=$(readlink -f "$0")
    cur_dir="${cur_dir%/*}"

    if [ "$cur_dir" != "$bin_dir" ]; then
        get_su "$@"
        mkdir -p "$bin_dir" "$lib_dir"
        cp "$0" "$bin_dir/ananas"
        chmod +x "$bin_dir/ananas"
        rm -f "$0"
    fi

    if [ -x "$lib_dir/checker" ]; then
        check "$@"
    else
        get_su "$@"
        setup
    fi
}

check() {
    if [ -d "$1" ] || [ -f "$1" ]; then delivery="$1"; else delivery="."; fi

    source "$lib_dir/python-env/bin/activate"

    output=$(find -L "$delivery" -type f | \
        grep -Ev "^(./tests|./bonus|./.git).*" | \
        #grep -v 'illegal token in column' | \
        "$lib_dir/checker" --profile epitech -d 2>/dev/null \
    )

	fatal=$(grep -c 'FATAL' <<< "$output")
	major=$(grep -c 'MAJOR' <<< "$output")
	minor=$(grep -c 'MINOR' <<< "$output")
	info=$(grep -c 'INFO' <<< "$output")

	if [ -n "$output" ]; then
		echo -e "\n\e[0;1m> Ananas report: \e[0m\n"
	    write_errors
		echo
	else
		echo -en "\n\e[0;1m> Ananas report: \e[0m"
	fi

	echo -en "\e[31mFATAL: $fatal \e[0m- \e[33mMAJOR: $major \e[0m"
	echo -e "- \e[32mMINOR: $minor \e[0m- \e[34mINFO: $info\e[0m\n"
}

write_errors() {
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
    rm -rf "$lib_dir/repo" "$lib_dir/lib" "$lib_dir/checker"

    echo -e '\e[34mSTEP 1/6: Installing dnf dependencies...\e[0m'
    dnf_dependencies >/dev/null
    echo -e '\e[34mSTEP 2/6: Installing python dependencies...\e[0m'
    python_dependencies >/dev/null
    echo -e '\e[34mSTEP 3/6: Cloning the banana repository...\e[0m'
    git_clone >/dev/null
    echo -e '\e[34mSTEP 4/6: Configuring with CMake...\e[0m'
    cmake_configure >/dev/null
    echo -e '\e[34mSTEP 5/6: Building with make...\e[0m'
    cmake_build >/dev/null
    echo -e '\e[34mSTEP 6/6: Setting up rules and profiles...\e[0m'
    profile >/dev/null
    rules >/dev/null

    if [ -x "$lib_dir/checker" ]; then
        echo -e "\n\e[1m> The command 'ananas' is ready to use.\e[0m\n"
    else
        echo -e '\n\e[31m> Something went wrong. Please report it.\e[0m\n'
    fi
    exit
}

dnf_dependencies() {
    dnf -y install make cmake which git gcc-c++ \
        tcl-devel boost-devel python python3-devel;
}

python_dependencies() {
    python -m venv "$lib_dir/python-env"
    source "$lib_dir/python-env/bin/activate"
    pip install --upgrade pip 'pylint==2.17.5' 'libclang==16.0.6'
}

git_clone() {
    git_url='https://github.com/Epitech/banana-vera'
    git clone --depth 1 "$git_url" "$lib_dir/repo" \
        2> >(grep -ve '^remote:' -e '^Resolving deltas:' -e '^Cloning into' >&2)
}

cmake_configure() {
    cd "$lib_dir/repo"
    cmake . -DVERA_LUA=OFF -DPANDOC=OFF -DVERA_USE_SYSTEM_BOOST=ON -Wno-dev \
        2> >(grep -ve '^$' -e '^CMake Warning' -e 'pandoc' | sed 's:^ *::g' >&2)
}

cmake_build() {
    cd "$lib_dir/repo"
    make -j 2> >(grep -v "warning L00" >&2)
    cp "$lib_dir/repo/src/vera++" "$lib_dir/checker"
    strip "$lib_dir/checker"
    rm -rf "$lib_dir/repo"
}

profile() {
    profile+=$'#!/usr/bin/tclsh\n\nset rules {\n'
    for rule in C-A3 C-C1 C-C2 C-C3 C-F2 C-F3 C-F4 C-F5 C-F6 C-F7 C-F8 \
        C-F9 C-G1 C-G2 C-G3 C-G4 C-G5 C-G6 C-G7 C-G8 C-G10 C-H1 C-H2 \
        C-H3 C-L1 C-L2 C-L3 C-L4 C-L5 C-L6 C-O1 C-O3 C-O4 C-V1 C-V3; do
        profile+="    $rule"$'\n'
    done
    profile+='}'
    mkdir -p "$lib_dir/lib/vera++/profiles"
    echo "$profile" > "$lib_dir/lib/vera++/profiles/epitech"
}

rules() {
mkdir -p "$lib_dir/lib/vera++/rules"
cd "$lib_dir/lib/vera++/rules"
mkdir -p 'utils/functions'
touch '__init__.py'

cat << EOF > './C-A3.py'
import vera

from utils import is_source_file, is_header_file, is_makefile, get_lines


def check_file_end():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file) and not is_makefile(file):
            continue

        lines = get_lines(file)
        if lines[-1] != '':
            vera.report(file, len(lines), 'INFO:C-A3')


check_file_end()
EOF

cat << EOF > './C-C1.py'
from dataclasses import dataclass
from enum import Enum
from typing import List

import vera
from utils import is_source_file, is_header_file
from utils.functions import get_functions

# The maximum depth of nested control structures allowed
# before reporting a violation

MAX_DEPTH_ALLOWED = 2

class _State(Enum):
    NOTHING = 0
    CONDITIONAL = 1
    ELSEIF = 2
    ELSE = 3


@dataclass
class ControlStructure:
    type: str
    has_braces: bool = False


class CC1HelperStateMachine:
    def __init__(self, file, func):
        self.index = 0
        self.state = _State.NOTHING
        self.depth = 0

        self.parenthesis_nesting_level = 0
        self.controls: List[ControlStructure] = []

        self.file = file
        self.tokens = vera.getTokens(
            file,
            func.body.line_start, func.body.column_start,
            func.body.line_end, func.body.column_end, [
                'do', 'if', 'else', 'while', 'for',
                'semicolon',
                'leftbrace', 'rightbrace',
                'newline',
                'leftparen', 'rightparen'
            ]
        )

    @property
    def token_count(self) -> int:
        return len(self.tokens)

    @property
    def token(self):
        return self.tokens[self.index]

    def visit_leftbrace(self):
        # If a "{" is encountered as part of a control structure,
        # it increases the structure nesting level by 1
        # and sets the fact that further parentheses arnt that of the keyword

        if self.state != _State.NOTHING and len(self.controls) > 0:
            self.controls[-1].has_braces = True

    def visit_rightbrace(self):
        # If a "}" is encountered as part of a control structure,
        # it decreases the structure nesting level and the depth by 1

        if self.state == _State.NOTHING:
            return

        self.depth -= 1
        if len(self.controls) > 0:
            self.controls.pop(-1)

        while (
            len(self.controls) > 0
            and not self.controls[-1].has_braces
        ):
            self.controls.pop(-1)
            self.depth -= 1

    def visit_semicolon(self):
        # If an ";" is encountered after the parentheses
        # of a keyword that does not have braces,
        # it considers the control structure "closed"
        # and decreases the depth of all nested braceless structures

        if (
            self.parenthesis_nesting_level != 0
            or self.state == _State.NOTHING
        ):
            return

        while (
            len(self.controls) > 0
            and not self.controls[-1].has_braces
        ):
            next_index = self.index + 1
            next_token = None

            while next_index < len(self.tokens) and next_token is None:
                if self.tokens[next_index].type != 'newline':
                    next_token = self.tokens[next_index]

                next_index += 1

            next_token_type = next_token.type if next_token else None
            self.depth -= 1

            last_control_structure = self.controls.pop(-1)
            if (
                last_control_structure.type == 'if'
                and next_token_type == 'else'
            ):
                break

    def visit_else(self):
        next_token = self.tokens[self.index + 1]
        next_token_type = next_token.type
        self.depth += 1

        if next_token_type != 'if':
            self.controls.append(ControlStructure('else'))
            self.state = _State.ELSE
            return

        self.depth += 1
        self.controls.append(ControlStructure('else'))
        self.controls.append(ControlStructure('if'))

        if self.state != _State.ELSEIF:
            self.state = _State.ELSEIF
            if self.depth > MAX_DEPTH_ALLOWED:
                vera.report(self.file, self.token.line, 'MAJOR:C-C1')
        else:
            # Two consecutive "else if" statements
            vera.report(self.file, next_token.line, 'MAJOR:C-C1')
        self.index += 1

    def visit_block_start(self):
        self.depth += 1
        self.controls.append(ControlStructure(self.token.type))

        if self.depth > MAX_DEPTH_ALLOWED:
            vera.report(self.file, self.token.line, 'MAJOR:C-C1')

        self.state = _State.CONDITIONAL

    def visit_newline(self):
        if self.depth != 0 or self.state == _State.NOTHING:
            self.visit_default()
            return

        if self.index + 1 >= len(self.tokens):
            self.index += 1
            return

        next_token = self.tokens[self.index + 1]

        if (
            next_token.type != 'else'
            or next_token.line != self.token.line + 1
        ):
            self.state = _State.NOTHING

    def visit_default(self):
        if self.state == _State.NOTHING:
            return

        if self.token.type == 'leftparen':
            self.parenthesis_nesting_level += 1

        elif self.token.type == 'rightparen':
            self.parenthesis_nesting_level -= 1


    state_handlers = {
        "leftbrace": visit_leftbrace,
        "rightbrace": visit_rightbrace,
        "semicolon": visit_semicolon,
        "else": visit_else,
        "if": visit_block_start,
        "do": visit_block_start,
        "while": visit_block_start,
        "for": visit_block_start,
        "newline": visit_newline
    }

    def run(self):
        # method from class name to make it act as a regular function
        default_handler = CC1HelperStateMachine.visit_default

        while self.index < self.token_count:
            self.state_handlers.get(self.token.type, default_handler)(self)
            self.index += 1


def check_conditional_branching():
    for file in vera.getSourceFileNames():
        if not (is_source_file(file) or is_header_file(file)):
            continue

        for func in get_functions(file):
            if func.body is not None:
                CC1HelperStateMachine(file, func).run()


check_conditional_branching()
EOF

cat << EOF > './C-C2.py'
import vera

from utils import is_source_file, is_header_file, ASSIGN_TOKENS, VALUE_MODIFIER_TOKENS, INCREMENT_DECREMENT_TOKENS, \\
    Token
from utils.functions import for_each_function_with_statements

def _report(token: Token) -> None:
    vera.report(
        token.file,
        token.line,
        'MAJOR:C-C2'
    )


def get_statements_using_ternary_operator(statements: list[list[Token]]) -> list[list[Token]]:
    return list(filter(lambda s: any(t.type == 'question_mark' for t in s), statements))

def are_branches_identical(first_branch: list[Token], second_branch: list[Token]) -> bool:
    tokens_to_ignore = {'leftparen', 'rightparen', 'leftbrace', 'rightbrace'}
    first_branch_content = ''.join(t.value for t in first_branch if t.type not in tokens_to_ignore)
    second_branch_content = ''.join(t.value for t in second_branch if t.type not in tokens_to_ignore)
    return first_branch_content == second_branch_content

def check_for_identical_branches(
        statement: list[Token],
        first_ternary_operator_index: int | None,
        first_colon_index: int | None
) -> None:
    if first_ternary_operator_index is not None and first_colon_index is not None:
        first_branch = statement[first_ternary_operator_index + 1:first_colon_index]
        second_branch = statement[first_colon_index + 1:]
        if second_branch[-1].type == 'semicolon':
            second_branch = second_branch[:-1]
        if are_branches_identical(first_branch, second_branch):
            _report(statement[first_ternary_operator_index])


def _is_possible_function_call(statement: list[Token], i: int) -> bool:
    return statement[i].type == 'identifier' and i + 1 < len(statement) and statement[i + 1].type == 'leftparen'


def _check_ternary_operator_for_function(statements: list[list[Token]]) -> None:
    for statement in get_statements_using_ternary_operator(statements):
        first_ternary_operator_encountered = False
        is_value_used = False
        first_ternary_operator_index = None
        first_colon_index = None
        parentheses_depth = 0
        possible_function_call = False
        for i, token in enumerate(statement):
            if (token.type == 'semicolon' and i != len(statement) - 1) or token.type in INCREMENT_DECREMENT_TOKENS:
                # Several sub-statements embedded in a single statement
                # or increment/decrement in ternary operator
                _report(token)
            elif first_ternary_operator_encountered:
                # Nested ternary operator or assignation in operator
                if token.type == 'question_mark' or token.type in VALUE_MODIFIER_TOKENS:
                    _report(token)
                elif token.type == 'colon':
                    first_colon_index = i
            else:
                # First ternary not yet encountered
                if token.type == 'question_mark':
                    first_ternary_operator_encountered = True
                    first_ternary_operator_index = i
                    if possible_function_call and parentheses_depth > 0:
                        is_value_used = True
                    # Ternary operator without assignation or return
                    if not is_value_used:
                        _report(token)
                elif token.type in {*ASSIGN_TOKENS, 'return'}:
                    is_value_used = True
                    if token.type in ASSIGN_TOKENS and parentheses_depth > 0:
                        # Assignation in ternary operator condition
                        _report(token)
                possible_function_call = possible_function_call or _is_possible_function_call(statement, i)
                parentheses_depth += token.type == 'leftparen'
                parentheses_depth -= token.type == 'rightparen'
        # Checks for identical branches
        check_for_identical_branches(statement, first_ternary_operator_index, first_colon_index)



def check_ternary_operator():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue
        for_each_function_with_statements(file, _check_ternary_operator_for_function)


check_ternary_operator()
EOF

cat << EOF > './C-C3.py'
import vera

from utils import is_source_file, is_header_file


def check_goto_keyword():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue
        for goto_token in vera.getTokens(file, 1, 0, -1, -1, ['goto']):
            vera.report(file, goto_token.line, 'MAJOR:C-C3')


check_goto_keyword()
EOF

cat << EOF > './C-F2.py'
import vera
from utils import is_source_file, is_header_file, is_lower_snakecase
from utils.functions import get_functions


def check_name_case():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue
        functions = get_functions(file)
        for function in functions:
            if function.body is None:
                continue
            if not is_lower_snakecase(function.name) or len(function.name.replace('_', '')) <= 2:
                vera.report(file, function.prototype.line_start, "MINOR:C-F2")


check_name_case()
EOF

cat << EOF > './C-F3.py'
import vera
from utils import get_lines
from utils import is_header_file, is_source_file, is_makefile

TAB_MAX_LENGTH = 4
LINE_MAX_LENGTH = 80


def check_line_length():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file) and not is_makefile(file):
            continue

        for line_number, line in enumerate(get_lines(file), start=1):
            line = line.strip('\n')
            count = 0
            for character in line:
                if character == '\t':
                    count = (count + TAB_MAX_LENGTH) - (count % TAB_MAX_LENGTH)
                else:
                    count += 1
            # Always count the newline character
            count += 1
            if count > LINE_MAX_LENGTH:
                vera.report(file, line_number, "MAJOR:C-F3")


check_line_length()
EOF

cat << EOF > './C-F4.py'
import vera
from utils import is_source_file, is_header_file
from utils.functions import get_functions

MAX_BODY_LINE_COUNT = 20

def check_function_body_length():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue
        functions = get_functions(file)
        for function in functions:
            if function.body is None:
                continue
            lines = function.body.raw[1:-1].split('\n')
            if len(lines) > 0 and lines[0] is not None and len(lines[0]) == 0:
                lines = lines[1:]
            if len(lines) > 0 and lines[-1] is not None and len(lines[-1]) == 0:
                lines = lines[:-1]
            for i in range(0, len(lines) - MAX_BODY_LINE_COUNT):
                vera.report(file, function.body.line_end - i - 1, "MAJOR:C-F4")

check_function_body_length()
EOF

cat << EOF > './C-F5.py'
import vera
from utils import is_source_file, is_header_file
from utils.functions import get_functions

MAX_ARGS_COUNT = 4


def check_function_arguments():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue

        functions = get_functions(file)
        for function in functions:
            arguments_count = function.get_arguments_count()
            if arguments_count > MAX_ARGS_COUNT:
                for _ in range(arguments_count - MAX_ARGS_COUNT):
                    vera.report(file, function.prototype.line_start, "MAJOR:C-F5")


check_function_arguments()
EOF

cat << EOF > './C-F6.py'
import vera
from utils import is_source_file, is_header_file
from utils.functions import get_functions

MAX_ARGS_COUNT = 4


def check_no_empty_parameters_list():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue

        functions = get_functions(file)
        for function in functions:
            if function.arguments is None:
                vera.report(file, function.prototype.line_start, "MAJOR:C-F6")


check_no_empty_parameters_list()
EOF

cat << EOF > './C-F7.py'
import vera
from utils import is_header_file, is_source_file
from utils.functions import get_functions


def _check_arguments(file: str, line: int, arg: str) -> None:
    normalized_arg = arg.replace('\t', ' ').strip()

    if not normalized_arg.startswith('struct '):
        return

    if normalized_arg.count(' ') < 2:
        # struct should have 2 at least 2 words after them
        # eg: struct foo_s *my_struct
        return

    _, struct_typ, name, *_ = normalized_arg.split(' ')
    if not name.startswith('*') and not struct_typ.endswith('*'):
        vera.report(file, line, "MAJOR:C-F7")


def check_no_structure_copy_as_parameter():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue

        for function in get_functions(file):
            if function.arguments is None:
                continue
            for arg in function.arguments:
                _check_arguments(file, function.prototype.line_start, arg)


check_no_structure_copy_as_parameter()
EOF

cat << EOF > './C-F8.py'
import vera

from utils import is_source_file, is_header_file
from utils.functions import get_functions


def check_comment_inside_function():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue
        functions = get_functions(file)

        for function in functions:
            last_function_token = function.prototype if function.body is None else function.body
            comments = vera.getTokens(file, function.prototype.line_start, function.prototype.column_start,
                                      last_function_token.line_end, last_function_token.column_end,
                                      ['ccomment', 'cppcomment'])
            for comment in comments:
                vera.report(file, comment.line, "MINOR:C-F8")


check_comment_inside_function()
EOF

cat << EOF > './C-F9.py'
import itertools
import vera

from utils import is_source_file, is_header_file
from utils.functions import get_functions_legacy, Function


def is_nested_function(parent: Function, child: Function):
    if parent.body is None or child.prototype is None:
        return False

    return (
        parent.body.line_start <= child.prototype.line_start
        and parent.body.line_end >= child.prototype.line_end
    )


def check_nested_functions():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue

        functions = get_functions_legacy(file)

        for fa, fb in itertools.combinations(functions, r=2):
            if is_nested_function(fa, fb):
                vera.report(file, fb.prototype.line_start, "MAJOR:C-F9")
            elif is_nested_function(fb, fa):
                vera.report(file, fa.prototype.line_start, "MAJOR:C-F9")


check_nested_functions()
EOF

cat << EOF > './C-G1.py'
import re

import vera
from utils import is_source_file, is_header_file, is_makefile, get_lines

MAKEFILE_HEADER_REGEX = re.compile(
    r'^##\n'
    r'## EPITECH PROJECT, [1-9][0-9]{3}\n'
    r'## \S.+\n'
    r'## File description:\n'
    r'(## .*\n)+'
    r'##(\n|$)')

C_HEADER_REGEX = re.compile(
    r'^/\*\n'
    r'\*\* EPITECH PROJECT, [1-9][0-9]{3}\n'
    r'\*\* \S.+\n'
    r'\*\* File description:\n'
    r'(\*\* .*\n)+'
    r'\*/(\n|$)')


def check_epitech_header():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file) and not is_makefile(file):
            continue
        raw = '\n'.join(get_lines(file))
        if (is_source_file(file) or is_header_file(file)) and not re.match(C_HEADER_REGEX, raw):
            vera.report(file, 1, 'MINOR:C-G1')
        if is_makefile(file) and not re.match(MAKEFILE_HEADER_REGEX, raw):
            vera.report(file, 1, 'MINOR:C-G1')


check_epitech_header()
EOF

cat << EOF > './C-G10.py'
import vera

from utils import is_source_file, is_header_file


def check_inline_assembly_usage():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue
        for asm_token in vera.getTokens(file, 1, 0, -1, -1, ['asm', 'identifier']):
            if asm_token.name == 'asm' or asm_token.value == '__asm__':
                vera.report(file, asm_token.line, 'FATAL:C-G10')


check_inline_assembly_usage()
EOF

cat << EOF > './C-G2.py'
import vera

from utils import is_source_file, is_header_file, get_lines
from utils.functions import get_functions
from utils.functions.function import Function


def is_only_one_line_without_comment(file: str, last_function: Function, current_function: Function):
    try:
        tokens = vera.getTokens(
            file,
            last_function.body.line_end + 1,
            last_function.body.column_end,
            current_function.prototype.line_start - 1,
            current_function.prototype.column_start + 1,
            ['ccomment', 'cppcomment']
        )
    # pylint:disable=W0703
    except Exception:
        return True

    if len(tokens) == 0:
        return False
    if tokens[0].line - last_function.body.line_end != 2:
        return False
    if (current_function.prototype.line_start - tokens[-1].line - tokens[-1].value.count('\n')) > 1:
        return False
    return True


def check_empty_line_between_functions():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue

        lines = get_lines(file, replace_comments=True, replace_stringlits=True)

        functions = [f for f in get_functions(file) if f.body is not None]
        for i, f in enumerate(functions):
            if i == 0:
                continue
            end_last_function = functions[i - 1].body.line_end
            start_current_function = f.prototype.line_start
            if start_current_function - end_last_function < 2:
                vera.report(file, start_current_function, 'MINOR:C-G2')
            elif start_current_function - end_last_function == 2:
                if lines[f.prototype.line_start - 2] != '':
                    vera.report(file, start_current_function, 'MINOR:C-G2')
            elif i > 0 and not is_only_one_line_without_comment(file, functions[i - 1], functions[i]):
                vera.report(file, start_current_function, 'MINOR:C-G2')


check_empty_line_between_functions()
EOF

cat << EOF > './C-G3.py'
from typing import List

import vera
from utils import is_header_file, get_lines, is_source_file


def _get_indentation_level(line: str):
    return len(line) - len(line.lstrip())


OPENING_DIRECTIVES = [
    'pp_if',
    'pp_ifdef',
    'pp_ifndef'
]

BRANCHING_DIRECTIVES = [
    'pp_elif',
    'pp_else'
]

CLOSING_DIRECTIVES = [
    'pp_endif'
]

ALL_DIRECTIVES = OPENING_DIRECTIVES + BRANCHING_DIRECTIVES + CLOSING_DIRECTIVES + [
    'pp_define',
    'pp_error',
    'pp_hheader',
    'pp_include',
    'pp_line',
    'pp_number',
    'pp_pragma',
    'pp_qheader',
    'pp_undef',
    'pp_warning'
]


def _is_pp_directive(file: str, line_number: int, directives: List[str]):
    token_list = vera.getTokens(file, 1, 0, -1, -1, directives)
    return any(token.line == line_number for token in token_list)


def check_preprocessor_directives_indentation():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue

        lines = get_lines(file)
        previous_indentation_level_stack = [-1]
        for line_number, line in enumerate(lines, start=1):
            # Empty lines are ignored
            if len(line.strip()) == 0:
                continue

            line_indentation_level = _get_indentation_level(line)
            # If the indentation level is inferior to the current scope's, it is always an error
            if _is_pp_directive(file, line_number, ALL_DIRECTIVES) \\
                    and line_indentation_level < previous_indentation_level_stack[-1]:
                vera.report(file, line_number, 'MINOR:C-G3')

            if _is_pp_directive(file, line_number, OPENING_DIRECTIVES):
                # When a opening directive is found,
                # its indentation level is pushed onto the stack and serves as the new reference
                previous_indentation_level_stack.append(line_indentation_level)
            elif _is_pp_directive(file, line_number, BRANCHING_DIRECTIVES):
                # When an adjacent branching directive is found,
                # it must be exactly on the same indentation level as its opening directive
                if line_indentation_level > previous_indentation_level_stack[-1]:
                    vera.report(file, line_number, 'MINOR:C-G3')
            elif _is_pp_directive(file, line_number, CLOSING_DIRECTIVES):
                # A closing directive must always be exactly on the same indentation level as what its opening directive
                if line_indentation_level > previous_indentation_level_stack[-1]:
                    vera.report(file, line_number, 'MINOR:C-G3')
                # Check done in order to prevent malformed #else directives to make this rule thrown an exception
                if len(previous_indentation_level_stack) >= 2:
                    previous_indentation_level_stack.pop()
            elif _is_pp_directive(file, line_number, ALL_DIRECTIVES) \\
                    and line_indentation_level == previous_indentation_level_stack[-1]:
                # Directives inside directives that are not themselves branching directives
                # must always be indented more than the branching directive which contains it
                vera.report(file, line_number, 'MINOR:C-G3')


check_preprocessor_directives_indentation()
EOF

cat << EOF > './C-G4.py'
import vera

from utils import is_source_file, is_header_file


def acceptPairs(file, tokens, index=0, level=0, state="other"):
    end = len(tokens)
    while index != end:
        token = tokens[index]

        if token.type == "leftbrace":
            index += 1
            level += 1
            acceptPairs(file, tokens, index, level, state)
            if index == end:
                return

            index += 1
        elif token.type == "assign":
            index += 1
            if level == 0 and state != "const":
                state = "assign"
            elif level == 0:
                state = "constassign"

        elif token.type == "rightbrace":
            level -= 1
            if level == 0:
                state = "other"
            return
        elif token.type == "semicolon":
            index += 1
            if level == 0 and state == "assign":
                vera.report(file, token.line, "MAJOR:C-G4")
            state = "other"
        elif token.type == "const":
            index += 1
            if level == 0 and state == "other":
                state = "const"

def check_global_variable_constness():
    for file in vera.getSourceFileNames():
        if not (is_source_file(file) or is_header_file(file)):
            continue
        tokens = vera.getTokens(
            file, 1, 0, -1, -1, ["const", "semicolon", "assign", "leftbrace", "rightbrace"])
        acceptPairs(file, tokens)

check_global_variable_constness()
EOF

cat << EOF > './C-G5.py'
import re

import vera
from utils import is_source_file, is_header_file


def check_includes():
    regex = r"^\s*#include\s*(?:<|\")(.*)(?:>|\")"
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue
        for token in vera.getTokens(file, 1, 0, -1, -1, ["pp_qheader"]):
            matches = re.finditer(regex, token.value, re.MULTILINE)
            for match in matches:
                for group_num in range(0, len(match.groups())):
                    group_num = group_num + 1
                    if not match.group(group_num).endswith(".h"):
                        vera.report(file, token.line, "MAJOR:C-G5")


check_includes()
EOF

cat << EOF > './C-G6.py'
import vera

from utils import is_header_file, is_source_file, is_makefile, get_lines


def check_carriage_return_character():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file) and not is_makefile(file):
            continue
        for line_number, line in enumerate(get_lines(file), start=1):
            if '\r' in line:
                vera.report(file, line_number, "MINOR:C-G6")


check_carriage_return_character()
EOF

cat << EOF > './C-G7.py'
import vera

from utils import is_header_file, is_source_file, is_makefile, get_lines


def check_trailing_spaces():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file) and not is_makefile(file):
            continue
        for line_number, line in enumerate(get_lines(file), start=1):
            # Reports for every trailing space, not just once per offending line
            line_without_break = line.rstrip("\r\n")
            for _ in range(len(line_without_break) - len(line_without_break.rstrip())):
                vera.report(file, line_number, "MINOR:C-G7")


check_trailing_spaces()
EOF

cat << EOF > './C-G8.py'
import vera

from utils import is_header_file, is_source_file, is_makefile, get_lines, is_line_empty


def check_leading_and_trailing_lines():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file) and not is_makefile(file):
            continue

        file_lines = get_lines(file)

        # Empty files or files with only one line cannot have leading or trailing lines, regardless of their content
        if len(file_lines) < 2:
            continue

        # Leading lines
        lowest_line_checked = 0
        for line_number, line in enumerate(file_lines, start=1):
            lowest_line_checked = line_number
            if is_line_empty(line):
                vera.report(file, line_number, "MINOR:C-G8")
            else:
                break

        # Trailing lines
        # Prevents the lines reported as leading from being reported as trailing as well,
        # in the case of a file with only empty lines
        trailing_lines = []
        for i in range(len(file_lines) - 1, lowest_line_checked - 1, -1):
            line_number = i + 1
            line = file_lines[i]
            if is_line_empty(line):
                trailing_lines.insert(0, line_number)
            else:
                break
        for line_number in trailing_lines[1:]:
            vera.report(file, line_number, "MINOR:C-G8")


check_leading_and_trailing_lines()
EOF

cat << EOF > './C-H1.py'
import vera
from utils import is_source_file, is_header_file
from utils.functions import get_functions, Function

FORBIDDEN_SOURCE_FILE_DIRECTIVES = ['typedef', 'pp_define']


def check_forbidden_directives():
    for file in vera.getSourceFileNames():
        if not is_source_file(file):
            continue
        for token in vera.getTokens(file, 1, 0, -1, -1, FORBIDDEN_SOURCE_FILE_DIRECTIVES):
            vera.report(file, token.line, 'MAJOR:C-H1')


def _is_function_allowed_in_source_file(function: Function) -> bool:
    if function.body is None:
        return False
    if function.static and function.inline:
        return False
    return True


def _is_function_allowed_in_header_file(function: Function) -> bool:
    if function.body is None:
        return True
    return function.static and function.inline


def _is_function_allowed_in_file(function: Function, file: str) -> bool:
    if is_source_file(file):
        return _is_function_allowed_in_source_file(function)
    if is_header_file(file):
        return _is_function_allowed_in_header_file(function)
    return False


def check_functions():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue
        functions = get_functions(file)
        for function in functions:
            if not _is_function_allowed_in_file(function, file):
                vera.report(file, function.prototype.line_start, "MAJOR:C-H1")


check_forbidden_directives()
check_functions()
EOF

cat << EOF > './C-H2.py'
import re

import vera
from utils import is_header_file, get_lines

PRAGMA_ONCE_REGEX = re.compile(r'\s*#\s*pragma\s+once\s*(//|/\*|$)')
IFNDEF_REGEX = re.compile(r'\s*#\s*ifndef\s+(?P<guard_name>\w+)\s*(//|/\*|$)')
DEFINE_REGEX = re.compile(r'\s*#\s*define\s+(?P<guard_name>\w+)\s*(//|/\*|$)')


def _is_protected_by_pragma_once(file):
    for pragma_token in vera.getTokens(file, 1, 0, -1, -1, ['pp_pragma']):
        # pragma_token.value only returns 'pragma',
        # thus as a workaround we fetch all the line at which the directive is encountered.
        pragma_directive = get_lines(file)[pragma_token.line - 1]
        if PRAGMA_ONCE_REGEX.match(pragma_directive):
            return True
    return False


def _is_protected_by_ifndef(file):
    ifndef_token_list = vera.getTokens(file, 1, 0, -1, -1, ['pp_ifndef'])
    define_token_list = vera.getTokens(file, 1, 0, -1, -1, ['pp_define'])
    endif_token_list = vera.getTokens(file, 1, 0, -1, -1, ['pp_endif'])

    if len(ifndef_token_list) > 0 and len(define_token_list) > 0 and len(endif_token_list) > 0:
        ifndef_token = get_lines(file)[ifndef_token_list[0].line - 1]
        match = IFNDEF_REGEX.match(ifndef_token)
        if match is None:
            return False
        guard_name = match.group('guard_name')
        define_token = get_lines(file)[define_token_list[0].line - 1]
        if guard_name:
            define_guard_match = DEFINE_REGEX.match(define_token)
            return define_guard_match and guard_name == define_guard_match.group('guard_name')
    return False


def check_double_inclusion_guards():
    for file in vera.getSourceFileNames():
        if not is_header_file(file):
            continue
        protected = _is_protected_by_ifndef(file) or _is_protected_by_pragma_once(file)

        if not protected:
            vera.report(file, 1, "MAJOR:C-H2")


check_double_inclusion_guards()
EOF

cat << EOF > './C-H3.py'
import vera

from utils import is_header_file, is_source_file


def is_abusive_macro(line: str) -> bool:
    # Macro should fit in a single line
    # and contain a single statement
    return line.endswith('\\\\') or ';' in line


def check_macro_size():
    for file in vera.getSourceFileNames():
        if not is_header_file(file) and not is_source_file(file):
            continue

        defines = vera.getTokens(file, 1, 0, -1, -1, ['pp_define'])

        for df in defines:
            line = vera.getLine(file, df.line).rstrip()

            if is_abusive_macro(line):
                vera.report(file, df.line, "MAJOR:C-H3")


if __name__ == "__main__":
    check_macro_size()
EOF

cat << EOF > './C-L1.py'
import vera

from utils import is_source_file, is_header_file, CONTROL_STRUCTURE_TOKENS, ASSIGN_TOKENS, Token
from utils.functions import for_each_function_with_statements, skip_interval


def __report(token: Token):
    vera.report(token.file, token.line, 'MAJOR:C-L1')


CLOSING_LINE_AUTHORIZED_TOKENS = {
    'if': 'else',
    'do': 'while',
    'else': 'else'
}


def _has_comma_at_root_level(statement: list[Token]) -> bool:
    root_level = 0
    i = 0
    while i < len(statement) and statement[i].name == 'leftparen':
        root_level += 1
        i += 1
    parentheses_depth = 0
    for token in statement[i:]:
        if token.name == 'leftparen':
            parentheses_depth += 1
        elif token.name == 'rightparen':
            parentheses_depth -= 1
        elif token.name == 'comma' and parentheses_depth <= root_level:
            return True
    return False


def _get_for_prototype_parts(statement: list[Token]) -> list[list[Token]]:
    parentheses_depth = 0
    part_start = None
    parts = []
    for i, token in enumerate(statement):
        if token.name == 'leftparen':
            parentheses_depth += 1
            if parentheses_depth == 1:
                part_start = i + 1
        elif token.name == 'rightparen':
            parentheses_depth -= 1
            if parentheses_depth == 0:
                if part_start is not None and part_start < i:
                    parts.append(statement[part_start:i])
                break
        elif token.name == 'semicolon' and parentheses_depth == 1:
            if part_start is not None and part_start < i:
                parts.append(statement[part_start:i])
            part_start = i + 1
    return parts


def _is_structure_initialization(part_after_assign: list[Token]) -> bool:
    if len(part_after_assign) < 3:
        return False
    if part_after_assign[0].name == 'leftbrace':
        return True
    if part_after_assign[0].name == 'leftparen':
        after_paren, _ = skip_interval(part_after_assign, 0, 'leftparen', 'rightparen')
        return after_paren + 1 < len(part_after_assign) and part_after_assign[after_paren + 1].name == 'leftbrace'
    return False

def _is_chained_assignment(statement: list[Token]) -> bool:
    if statement[0].name == 'for':
        for_prototype_parts = _get_for_prototype_parts(statement)
        return any(_is_chained_assignment(part) or _has_comma_at_root_level(part) for part in for_prototype_parts)
    assign_found = False
    for i, token in enumerate(statement):
        if token.name in ASSIGN_TOKENS:
            if assign_found:
                return True
            if i + 1 < len(statement) and _is_structure_initialization(statement[i + 1:]):
                # We encountered a structure initialization, as such we stop looking for assign tokens
                # since the next one will be the one of the structure initialization.
                return False
            assign_found = True
    return False


def _check_function_statements(statements: list[list[Token]]):
    brace_depth = 0
    right_brace_line_authorized_tokens = []
    for i, statement in enumerate(statements):
        if (i > 0 and statement[0].line == statements[i - 1][-1].line
                and not (statements[i - 1][0].name == 'rightbrace'
                         and len(right_brace_line_authorized_tokens) > 0
                         and statement[0].name == right_brace_line_authorized_tokens[-1])):
            # There are two statements on the same line
            __report(statement[0])
        if (statement[0].name in CONTROL_STRUCTURE_TOKENS
                and statement[0].name != 'for'
                and any(True for token in statement if token.name in ASSIGN_TOKENS)):
            # There is an assignment in the control structure prototype
            __report(statement[0])
        if _is_chained_assignment(statement):
            # There is a chained assignment
            __report(statement[0])

        if statements[i - 1][0].name == 'rightbrace':
            if len(right_brace_line_authorized_tokens) > 0:
                right_brace_line_authorized_tokens.pop()
        if statement[-1].name == 'leftbrace':
            right_brace_line_authorized_tokens.append(CLOSING_LINE_AUTHORIZED_TOKENS.get(statement[0].name, None))
            brace_depth += 1
        elif statement[0].name == 'rightbrace' and brace_depth > 0:
            brace_depth -= 1


def check_multiple_statements_on_one_line():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue

        for_each_function_with_statements(file, _check_function_statements)

check_multiple_statements_on_one_line()
EOF

cat << EOF > './C-L2.py'
import re

import vera

from utils import is_header_file, is_source_file, get_lines, is_line_empty
from utils.functions import get_functions

from typing import List, Tuple, Sequence


def is_line_correctly_indented(line: str, in_function: bool) -> bool:
    # A well-indented line is considered to either be:
    # - an empty line;
    # - a line only comprised of spaces (which should not be considered a violation of the C-L2 rule,
    #   but a violation of the C-G7 rule);
    # - a line with any amount of 4 spaces groups (can be 0, notably for top-level statements),
    #   followed by a non-space and non-tabulation character.
    # - a line part of a comment block
    if is_line_empty(line):
        return True
    if line.endswith('*/'):
        return True
    indentation_regex = re.compile(r'^( *|( {4})*\S+.*)$')
    function_indentation_regex = re.compile(r'^( *|( {4})+\S+.*)$')
    if in_function:
        return function_indentation_regex.match(line) is not None
    return indentation_regex.match(line) is not None


def check_line_indentation():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue

        functions = get_functions(file)
        function_lines = []
        global_scope = []

        for function in functions:
            if function.body is not None:
                function_lines += range(function.body.line_start + 1, function.body.line_end)

        for line_number, line in enumerate(get_lines(file, replace_comments=True, replace_stringlits=True), start=1):
            if not is_line_correctly_indented(line, line_number in function_lines):
                vera.report(file, line_number, 'MINOR:C-L2')

            if line_number not in function_lines:
                global_scope.append((line_number, line))

        check_global_scope(file, global_scope)


def get_indent_level(line: str) -> int:
    spaces = 0
    for c in line:
        if c == ' ':
            spaces += 1
        elif c == '\t':
            spaces += 4
        else:
            break
    # round up
    return (spaces + 3) // 4


def iter_skip_comments(lines: Sequence[Tuple[int, str]]):
    # deeper clean after replace_comment
    in_comment = False
    in_string = False
    skip_next = False

    for lineno, line in lines:
        cleaned = ''

        for c, cnext in zip(line, line[1::] + ' '):
            if skip_next:
                skip_next = False
                continue

            if c == '"':
                in_string = not in_string

            if in_string:
                cleaned += c
                continue

            if not in_comment:
                if c == '/' and cnext in '/':
                    break

                if c == '/' and cnext == '*':
                    in_comment = True
                    continue

                cleaned += c
            elif c == '*' and cnext == '/':
                in_comment = False
                skip_next = True
        yield lineno, cleaned


def check_global_scope(file: str, global_scope: List[Tuple[int, str]]) -> None:
    depth = 0
    depth_stack = []
    depth_match = {
        '[': ']',
        '(': ')',
        '{': '}'
    }

    for lineno, line in iter_skip_comments(global_scope):
        depth_change = 0

        if not line or line.isspace():
            continue

        if line.lstrip(' \t').startswith('#'):
            continue

        postponed_depth_decrease = False

        for i, c in enumerate(line.lstrip(' \t')):
            if c in depth_match:
                depth_stack.append(depth_match[c])
                depth_change += 1
                depth += 1

            if depth_stack and c == depth_stack[-1]:
                depth_stack.pop()
                if i != 0 and depth_change == 0:
                    postponed_depth_decrease = True
                else:
                    depth -= 1
                    depth_change -= 1

        if get_indent_level(line) != depth and depth_change != 1:
            vera.report(file, lineno, "MINOR:C-L2")
        if postponed_depth_decrease:
            depth -= 1


check_line_indentation()
EOF

cat << EOF > './C-L3.py'
from typing import List

import vera

from utils import (
    PARENTHESIS_TOKENS,
    KEYWORDS_TOKENS,
    BINARY_OPERATORS_TOKENS,
    IDENTIFIERS_TOKENS,
    UNARY_OPERATORS_TOKENS,
    TYPES_TOKENS,
    SQUARE_BRACKETS_TOKENS,

    Token,
    is_source_file,
    is_header_file,
    get_prev_token_index,
)

SEPARATOR_TOKENS = [
    'comma',
    'semicolon'
]

SPACES_TOKENS = [
    'space',
    'newline'
]

SPACE_RELATED_TOKENS = (
  BINARY_OPERATORS_TOKENS
  + UNARY_OPERATORS_TOKENS
  + SPACES_TOKENS
  + IDENTIFIERS_TOKENS
  + TYPES_TOKENS
  + PARENTHESIS_TOKENS
  + SEPARATOR_TOKENS
  + SQUARE_BRACKETS_TOKENS
  + ['case', 'default']
  + ["pp_define"]
)

KEYWORDS_NEEDS_SPACE = (
    'if',
    'switch',
    'case',
    'for',
    'do',
    'while',
    'return',
    'comma',
    'struct',
)


def send_report(name: str, lineno: int) -> None:
    # vera.report cannot be transformed into a partial
    # due to the C++ API not supporting keyword arguments.
    vera.report(name, lineno, "MINOR:C-L3")


def _is_invalid_space(tokens: List[Token], i: int):
    # If there is a new line or a single space the space is always valid
    if tokens[i].name == 'newline' or tokens[i].value == ' ':
        return False
    # If there is multiple spaces but theses spaces was preceded by a new line this is valid
    if i > 0 and tokens[i].name == 'space' and tokens[i - 1].name == 'newline':
        return False
    # Elsewhere the space is invalid
    return True


def _check_binary_operator(file, token, i, tokens, prev_token_indeces):
    prev_case_token_index, prev_separator_token_index = prev_token_indeces

    # Check for space before
    if i == 0:
        return
    # Special case for the Elvis operator
    if token.name == 'colon' and tokens[i - 1].name == 'question_mark':
        return
    if (
        prev_case_token_index < prev_separator_token_index
        or prev_case_token_index < 0
    ) and _is_invalid_space(tokens, i - 1):
        send_report(file, token.line)
        return
    # Check for space after
    if i + 1 < len(tokens):
        # Special case for the Elvis operator
        if token.name == 'question_mark' and tokens[i + 1].name == 'colon':
            return
        if (
            prev_case_token_index < prev_separator_token_index
            or prev_case_token_index <0
        ) and _is_invalid_space(tokens, i + 1):
            send_report(file, token.line)

def _check_unwanted_spaces(file, token, i, tokens):
    if token.name != 'space':
        return

    if i in (0, len(tokens) - 1):
        return

    if vera.getTokens(file, token.line, 0, token.line, i, ["pp_define"]):
        return

    neighbor_names = (tokens[i - 1].name, tokens[i + 1].name)

    if neighbor_names in (
        ('identifier', 'leftparen'),
        ('rightparen', 'semicolon')
    ):
        send_report(file, token.line)


def check_space_around_operators(file):
    tokens = vera.getTokens(file, 1, 0, -1, -1, SPACE_RELATED_TOKENS)
    target_operators = UNARY_OPERATORS_TOKENS + BINARY_OPERATORS_TOKENS

    for i, token in enumerate(tokens):
        _check_unwanted_spaces(file, token, i, tokens)

        if token.name not in target_operators:
            continue

        prev_case_token_index = get_prev_token_index(tokens, i, ['case', 'default'])
        prev_separator_token_index = get_prev_token_index(tokens, i, ['comma', 'semicolon', 'leftbrace'])

        if token.name not in UNARY_OPERATORS_TOKENS:
            _check_binary_operator(
                file, token, i, tokens,
                (prev_case_token_index, prev_separator_token_index)
            )
            continue
        if i in (0, len(tokens) - 1):
            continue

        allowed_previous_tokens = ['not', 'and']
        operator_separators_tokens = (
            SPACES_TOKENS
            + PARENTHESIS_TOKENS
            + SQUARE_BRACKETS_TOKENS
            + [token.name]
        )

        if (
            tokens[i - 1].name not in allowed_previous_tokens
            and tokens[i - 1].name not in operator_separators_tokens
            and tokens[i + 1].name not in operator_separators_tokens
        ):
            send_report(file, token.line)


def _check_for_return_case(file, token, i, tokens):
    # "return" keyword is an exception,
    # where it needs to be immediately followed by either a space
    #  and something else than a semicolon,
    #  or immediately by a semicolon without a space in between
    if tokens[i + 1].name == 'semicolon':
        return
    if tokens[i + 1].name not in SPACES_TOKENS:
        send_report(file, token.line)
    elif (
        i + 2 >= len(tokens)
        or tokens[i + 2].name == 'semicolon'
        or _is_invalid_space(tokens, i + 1)
    ):
        send_report(file, token.line)


def check_space_after_keywords_and_commas(file):
    tokens = vera.getTokens(file, 1, 0, -1, -1, [])
    target_tokens = KEYWORDS_TOKENS + ['comma']

    for i, token in enumerate(tokens):
        if token.name not in target_tokens:
            continue

        if (i + 1) >= len(tokens):
            continue

        if token.name == 'return':
            _check_for_return_case(file, token, i, tokens)
        # If the token needs to have a space,
        # and that there is not space after it, it is an error
        elif (
            token.name in KEYWORDS_NEEDS_SPACE
            and _is_invalid_space(tokens, i + 1)
        ):
            send_report(file, token.line)
        # If the token does not need to have a space,
        # and that there is a space after it, it is an error
        elif (
            token.name not in KEYWORDS_NEEDS_SPACE
            and tokens[i + 1].name in SPACES_TOKENS
         ):
            send_report(file, token.line)


def check_spaces():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue

        check_space_after_keywords_and_commas(file)
        check_space_around_operators(file)


check_spaces()
EOF

cat << EOF > './C-L4.py'
import re
from typing import List

import vera
from utils import is_source_file, is_header_file, Token, get_lines, CONTROL_STRUCTURE_TOKENS
from utils.functions import get_functions, for_each_function_with_statements
from utils.functions.function import Function


def __report(token: Token) -> None:
    vera.report(token.file, token.line, "MINOR:C-L4")

def get_function_start_at_token(functions: List[Function], token: Token) -> Function | None:
    for function in functions:
        if function.body and function.body.line_start == token.line and function.body.column_start == token.column:
            return function
    return None


def _is_left_brace_misplaced(statement: list[Token], i: int, statements: list[list[Token]]) -> bool:
    if statement[-1].name != 'leftbrace':
        return False
    if i + 1 < len(statements) and statement[-1].line == statements[i + 1][0].line:
        # The left brace is followed by a token on the same line
        return True
    if len(statement) > 1 and statement[-1].line != statement[-2].line:
        # The left brace is not preceded by a token on the same line
        return True
    return False



def _is_right_brace_misplaced(
        statement: list[Token],
        i: int,
        statements: list[list[Token]],
        is_in_do: bool
) -> bool:
    if statement[0].name != 'rightbrace':
        return False
    if i - 1 >= 0 and statement[0].line == statements[i - 1][-1].line:
        # The right brace is preceded by a token on the same line
        return True
    if i + 1 < len(statements):
        if statements[i + 1][0].name == 'else' or (is_in_do and statements[i + 1][0].name == 'while'):
            return statement[0].line != statements[i + 1][0].line
        # The right brace is followed by a token on the same line (except else)
        return statement[0].line == statements[i + 1][0].line
    return False


def _check_braces_placement_in_function(statements: list[list[Token]]) -> None:
    control_structure_nesting = []
    for i, statement in enumerate(statements):
        if statement[0].name in CONTROL_STRUCTURE_TOKENS and statement[-1].name == 'leftbrace':
            control_structure_nesting.append(statement[0].name)
        if (_is_left_brace_misplaced(statement, i, statements)
                or _is_right_brace_misplaced(
                    statement,
                    i,
                    statements,
                    len(control_structure_nesting) > 0 and control_structure_nesting[-1] == 'do'
                )
        ):
            __report(statement[-1])
        if statement[-1].name == 'rightbrace':
            if len(control_structure_nesting) > 0:
                control_structure_nesting.pop()


def _is_token_part_of_function_body(token: Token, functions: list[Function]) -> bool:
    for function in functions:
        if function.body is None:
            continue
        if function.body.line_start < token.line < function.body.line_end:
            return True
        if function.body.line_start == token.line and function.body.line_end == token.line:
            return function.body.column_start < token.column < function.body.column_end
        if function.body.line_start == token.line and function.body.column_start < token.column:
            return True
        if function.body.line_end == token.line and function.body.column_end > token.column:
            return True
    return False

# pylint:disable=too-many-branches
# pylint:disable=too-many-locals
# pylint:disable=too-many-statements
def check_curly_brackets_placement():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue

        for_each_function_with_statements(file, _check_braces_placement_in_function)

        tokens_filter = [
            'leftbrace',
            'rightbrace',
            "case",
            "do",
            "else",
            "for",
            "if",
            "typedef",
            "switch",
            "while",
            "struct",
            "leftparen",
            "rightparen",
            "enum",
            "assign",
            "union",
            "identifier",
            "semicolon"
        ]
        lines = get_lines(file, True, True)
        tokens = vera.getTokens(file, 1, 0, -1, -1, tokens_filter)
        tokens_count = len(tokens)
        enum_braces_count = []
        union_braces_count = []
        assign_braces_count = []
        struct_braces_count = []
        typedef_struct_braces_count = []
        functions = get_functions(file)
        skipping_level_increase_token = None
        skipping_level_decrease_token = None
        skipping_checks = False
        skipping_level = 0

        for i, token in enumerate(tokens):
            if _is_token_part_of_function_body(token, functions):
                continue
            token_line_content = vera.getLine(file, token.line)

            if not skipping_checks:
                if token.name == 'leftparen':
                    skipping_level = 1
                    skipping_checks = True
                    skipping_level_increase_token = 'leftparen'
                    skipping_level_decrease_token = 'rightparen'
                    continue
                if i > 0 and token.name == 'leftbrace' and tokens[i - 1].name == 'assign':
                    skipping_level = 1
                    skipping_checks = True
                    skipping_level_increase_token = 'leftbrace'
                    skipping_level_decrease_token = 'rightbrace'
                    continue

            if skipping_checks:
                if token.name == skipping_level_increase_token:
                    skipping_level += 1
                elif token.name == skipping_level_decrease_token:
                    skipping_level -= 1
                if skipping_level == 0:
                    skipping_checks = False
                continue

            if token.name == 'enum':
                enum_braces_count.append(0)
            elif token.name == 'assign':
                assign_braces_count.append(0)
            elif token.name == 'union':
                union_braces_count.append(0)
            elif token.name == 'typedef' and i + 1 < tokens_count and tokens[i + 1].name == 'struct':
                typedef_struct_braces_count.append(0)
            elif token.name == 'struct':
                struct_braces_count.append(0)

            elif token.name == 'leftbrace':
                # Count the braces of a typedef struct or enum in order to detect the end of the bloc
                if len(enum_braces_count) > 0:
                    enum_braces_count[-1] += 1
                if len(assign_braces_count) > 0:
                    assign_braces_count[-1] += 1
                if len(union_braces_count) > 0:
                    union_braces_count[-1] += 1
                if len(typedef_struct_braces_count) > 0:
                    typedef_struct_braces_count[-1] += 1
                if len(struct_braces_count) > 0:
                    struct_braces_count[-1] += 1

                func = get_function_start_at_token(functions, token)
                if func is not None and len(lines[token.line - 1]) > 1:  # handling function specific case
                    __report(token)
                elif func is None and i > 0 and tokens[i - 1].line != token.line:
                    __report(token)
                elif i < len(tokens) - 1 and tokens[i + 1].line == token.line: # handling content after left brace
                    __report(token)

            elif token.name == 'rightbrace':
                # Count the braces of a typedef struct or enum in order to detect the end of the bloc
                if len(enum_braces_count) > 0:
                    enum_braces_count[-1] -= 1
                if len(assign_braces_count) > 0:
                    assign_braces_count[-1] -= 1
                if len(union_braces_count) > 0:
                    union_braces_count[-1] -= 1
                if len(typedef_struct_braces_count) > 0:
                    typedef_struct_braces_count[-1] -= 1
                if len(struct_braces_count) > 0:
                    struct_braces_count[-1] -= 1

                # True when it's the end of the enum bloc
                if len(enum_braces_count) > 0 and enum_braces_count[-1] == 0:
                    enum_braces_count.pop()
                    continue

                # True when it's the end of the assign bloc
                if len(assign_braces_count) > 0 and assign_braces_count[-1] == 0:
                    assign_braces_count.pop()
                    continue

                # True when it's the end of the union bloc
                if len(union_braces_count) > 0 and union_braces_count[-1] == 0:
                    union_braces_count.pop()
                    continue

                # True when it's the end of the typedef struct bloc
                if len(typedef_struct_braces_count) > 0 and typedef_struct_braces_count[-1] == 0:
                    typedef_struct_braces_count.pop()
                    continue

                # True when it's the end of the struct bloc
                if len(struct_braces_count) > 0 and struct_braces_count[-1] == 0:
                    struct_braces_count.pop()
                    continue

                if i + 1 < tokens_count and tokens[i + 1].name == 'else':
                    continue
                line = token_line_content.replace(' ', '').replace('\t', '')
                is_valid = re.match("}[ \t]*;?(//.*|/\\\\*.*)?[ \t]*$", line)
                if not is_valid:
                    __report(token)
            elif token.name == 'else':
                # A righbrace preceding an else must be on the same line
                if i >= 1 and tokens[i - 1].name == 'rightbrace' and tokens[i - 1].line != token.line:
                    __report(token)
                # Check if there is a valid token after the else on the same line
                if (
                        i + 1 >= tokens_count or
                        (tokens[i + 1].name not in ['if', 'leftbrace'] and tokens[i + 1].line == token.line)
                ):
                    __report(token)

            elif token.name == 'if' and i >= 1 and tokens[i - 1].name == 'else':
                if token.line != tokens[i - 1].line:
                    __report(token)



check_curly_brackets_placement()
EOF

cat << EOF > './C-L5.py'
import vera
from utils import is_header_file, is_source_file
from utils.functions import is_variable_declaration, for_each_function_with_statements, UnsureBool, skip_interval


def is_declaring_multiple_variables(statement) -> bool:
    declaration = []
    i = 0
    while i < len(statement):
        token = statement[i]
        if token.name == 'assign':
            break
        if token.name == 'leftparen':
            i, _ = skip_interval(statement, i, 'leftparen', 'rightparen')
        else:
            declaration.append(token)
        i += 1
    return len(list(filter(lambda t: t.name == 'comma', declaration))) > 0

def _check_variable_declarations_for_function(statements):
    declaration_zone = True
    for statement in statements:
        variable_declaration = is_variable_declaration(statement)
        if variable_declaration == UnsureBool.TRUE:
            if not declaration_zone or is_declaring_multiple_variables(statement):
                vera.report(
                    statement[0].file,
                    statement[0].line,
                    "MAJOR:C-L5",
                )
        elif variable_declaration == UnsureBool.FALSE:
            declaration_zone = False

def check_variable_declarations():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue
        for_each_function_with_statements(file, _check_variable_declarations_for_function)


check_variable_declarations()
EOF

cat << EOF > './C-L6.py'
import vera
from utils import is_header_file, is_source_file, is_line_empty
from utils.functions import get_functions, get_function_statements, is_variable_declaration, get_function_body_tokens, \\
    UnsureBool

def _get_variable_declaration_status_for_each_line(function_statements) -> list[UnsureBool]:
    return list(map(is_variable_declaration, function_statements))

def _get_line_number_after_declarations(
        statements: list[list[vera.Token]],
        declaration_statuses: list[UnsureBool]
) -> int | None:
    declarations_present = False
    for i, statement in enumerate(statements):
        declaration_status = declaration_statuses[i]
        if declaration_status == UnsureBool.TRUE:
            declarations_present = True
        else:
            return statement[0].line if declarations_present else None
    return None

def _has_declaration_zone(variable_declarations: list[UnsureBool]) -> UnsureBool:
    has_one_sure_declaration = False
    for declaration in variable_declarations:
        if declaration == UnsureBool.TRUE:
            has_one_sure_declaration = True
        elif declaration == UnsureBool.FALSE:
            break
        else:
            return UnsureBool.UNSURE
    return UnsureBool.from_bool(has_one_sure_declaration)

def _check_line_breaks_for_function(tokens, empty_lines: list[int]):
    function_statements = get_function_statements(tokens)
    variable_declarations = _get_variable_declaration_status_for_each_line(function_statements)
    has_declaration_zone = _has_declaration_zone(variable_declarations)

    unnecessary_empty_lines = empty_lines.copy()
    if has_declaration_zone == UnsureBool.TRUE:
        line_number_after_declarations = _get_line_number_after_declarations(function_statements, variable_declarations)
        mandatory_line_break = line_number_after_declarations - 1 if line_number_after_declarations is not None else None
        if mandatory_line_break:
            if mandatory_line_break not in empty_lines:
                vera.report(
                    tokens[0].file,
                    mandatory_line_break + 1,
                    "MINOR:C-L6",
                )
            else:
                # Remove the lowest empty line number adjacent to the mandatory line break,
                # so that in the case of a double line break, the first one is not reported,
                # as it is the one expected.
                line_break_to_remove = mandatory_line_break
                for line_number in range(mandatory_line_break - 1, 0, -1):
                    if line_number not in empty_lines:
                        break
                    line_break_to_remove = line_number
                unnecessary_empty_lines.remove(line_break_to_remove)
    elif has_declaration_zone == UnsureBool.UNSURE and len(empty_lines) > 0:
        unnecessary_empty_lines.pop(0)

    for line_number in unnecessary_empty_lines:
        vera.report(
            tokens[0].file,
            line_number,
            "MINOR:C-L6",
        )

def _get_function_empty_lines(file, line_start, line_end) -> list[int]:
    file_lines = vera.getAllLines(file)
    empty_lines = []
    for line_number in range(line_start, line_end + 1):
        if is_line_empty(file_lines[line_number - 1]):
            empty_lines.append(line_number)
    return empty_lines

def check_variable_declarations():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue

        functions = get_functions(file)
        for function in functions:
            if function.body is None:
                continue
            function_tokens = get_function_body_tokens(file, function)
            empty_lines = _get_function_empty_lines(file, function.body.line_start, function.body.line_end)
            _check_line_breaks_for_function(function_tokens, empty_lines)



check_variable_declarations()
EOF

cat << EOF > './C-O1.py'
import re

import vera
from utils import get_filename

# Inspired by
# https://github.com/github/gitignore/blob/master/C.gitignore
# https://github.com/github/gitignore/blob/master/Gcov.gitignore
_UNWANTED_FILES_REGEXES = [
    # Prerequisites
    re.compile(r'.*\.d$'),

    # Object files
    re.compile(r'.*\.o$'),
    re.compile(r'.*\.ko$'),
    re.compile(r'.*\.obj$'),
    re.compile(r'.*\.elf$'),

    # Linker output
    re.compile(r'.*\.ilk$'),
    re.compile(r'.*\.map$'),
    re.compile(r'.*\.exp$'),

    # Precompiled Headers
    re.compile(r'.*\.gch$'),
    re.compile(r'.*\.pch$'),

    # Libraries
    re.compile(r'.*\.lib$'),
    re.compile(r'.*\.a$'),
    re.compile(r'.*\.la$'),
    re.compile(r'.*\.lo$'),

    # Shared objects (inc. Windows DLLs)
    re.compile(r'.*\.dll$'),
    re.compile(r'.*\.so$'),
    re.compile(r'.*\.so\..*$'),
    re.compile(r'.*\.dylib$'),

    # Executables
    re.compile(r'.*\.exe$'),
    re.compile(r'.*\.out$'),
    re.compile(r'.*\.app$'),
    re.compile(r'.*\.i.*86$'),
    re.compile(r'.*\.x86_64$'),
    re.compile(r'.*\.hex$'),

    # Debug files
    re.compile(r'.*\.su$'),
    re.compile(r'.*\.idb$'),
    re.compile(r'.*\.pdb$'),

    # Kernel Module Compile Results
    re.compile(r'.*\.mod.*$'),
    re.compile(r'.*\.cmd$'),
    re.compile(r'^modules\.order$'),
    re.compile(r'^Module\.symvers$'),
    re.compile(r'^Mkfile\.old$'),
    re.compile(r'^dkms\.conf$'),

    # gcc coverage testing tool files
    re.compile(r'.*\.gcno$'),
    re.compile(r'.*\.gcda$'),
    re.compile(r'.*\.gcov$'),

    # Temporary files
    re.compile(r'.*~.*'),
    re.compile(r'.*#.*'),

    # Valgrind core dump files
    re.compile(r'^vgcore\.\d+$')
]

_UNWANTED_BINARY_MAGIC = [
    # ELF
    b'\x7fELF',

    # EXE
    b'MZ',

    # Mach-O
    b'\xfe\xed\xfa\xce',

    # PE
    b'\x4d\x5a',
]


def is_unwanted_binary(file: str) -> bool:
    with open(file, 'rb') as f:
        first_line = f.readline()
        return any(first_line.startswith(magic) for magic in _UNWANTED_BINARY_MAGIC)


def check_delivery_files():
    for file in vera.getSourceFileNames():
        if is_unwanted_binary(file):
            vera.report(file, 1, "MAJOR:C-O1")
            continue
        file_name = get_filename(file)
        for regex in _UNWANTED_FILES_REGEXES:
            if regex.match(file_name):
                vera.report(file, 1, "MAJOR:C-O1")
                break


check_delivery_files()
EOF

cat << EOF > './C-O3.py'
import vera
from utils import is_header_file, is_source_file
from utils.functions import get_functions

MAX_FUNCTION_COUNT = 10
MAX_NON_STATIC_FUNCTION_COUNT = 5


def check_functions_count():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue

        functions = get_functions(file)
        function_count = 0
        non_static_function_count = 0
        for function in functions:
            if function.body is None:
                continue
            function_count += 1
            if not function.static:
                non_static_function_count += 1
                if non_static_function_count > MAX_NON_STATIC_FUNCTION_COUNT:
                    vera.report(file, function.prototype.line_start, "MAJOR:C-O3")
                    continue
            if function_count > MAX_FUNCTION_COUNT:
                vera.report(file, function.prototype.line_start, "MAJOR:C-O3")

check_functions_count()
EOF

cat << EOF > './C-O4.py'
import re

import vera
from utils import is_header_file, is_source_file, get_filename_without_extension


def check_file_name():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue

        file_name = get_filename_without_extension(file)
        if not re.match(r'^[a-z]([a-z\d_]*[a-z\d])?$', file_name) or '__' in file_name:
            vera.report(file, 1, "MINOR:C-O4")


check_file_name()
EOF

cat << EOF > './C-V1.py'
import io
import re

import vera
from utils import is_source_file, is_header_file, get_lines

ALLOWED_TYPES = [
    "sfBlack",
    "sfBlendAdd",
    "sfBlendAlpha",
    "sfBlendMultiply",
    "sfBlendNone",
    "sfBlue",
    "sfCircleShape",
    "sfClock",
    "sfColor",
    "sfContext",
    "sfConvexShape",
    "sfCursor",
    "sfCyan",
    "sfFloatRect",
    "sfFont",
    "sfGreen",
    "sfImage",
    "sfIntRect",
    "sfJoystick",
    "sfKeyboard",
    "sfListener",
    "sfMagenta",
    "sfMicroseconds",
    "sfMilliseconds",
    "sfMouse",
    "sfMouseButtonEvent",
    "sfMusic",
    "sfMutex",
    "sfRectangleShape",
    "sfRed",
    "sfRenderStates",
    "sfRenderTexture",
    "sfRenderWindow",
    "sfSeconds",
    "sfSensor",
    "sfShader",
    "sfShape",
    "sfSleep",
    "sfSound",
    "sfSoundBuffer",
    "sfSoundBufferRecorder",
    "sfSoundRecorder",
    "sfSoundStream",
    "sfSprite",
    "sfText",
    "sfTexture",
    "sfThread",
    "sfTime",
    "sfTouch",
    "sfTransform",
    "sfTransformable",
    "sfTransparent",
    "sfVertexArray",
    "sfVideoMode",
    "sfView",
    "sfWhite",
    "sfWindow",
    "sfYellow",
    "sfBool",
    "sfFtp",
    "sfFtpDirectoryResponse",
    "sfFtpListingResponse",
    "sfFtpResponse",
    "sfGlslIvec2",
    "sfGlslVec2",
    "sfGlslVec3",
    "sfHttp",
    "sfHttpRequest",
    "sfHttpResponse",
    "sfInputStream",
    "sfInputStreamGetSizeFunc",
    "sfInputStreamReadFunc",
    "sfInputStreamSeekFunc",
    "sfInputStreamTellFunc",
    "sfInt16",
    "sfInt32",
    "sfInt64",
    "sfInt8",
    "sfPacket",
    "sfShapeGetPointCallback",
    "sfSocketSelector",
    "sfSoundBuffer",
    "sfSoundBufferRecorder",
    "sfSoundRecorder",
    "sfSoundRecorderProcessCallback",
    "sfSoundRecorderStartCallback",
    "sfSoundRecorderStopCallback",
    "sfSoundStream",
    "sfSoundStreamChunk",
    "sfSoundStreamGetDataCallback",
    "sfSoundStreamSeekCallback",
    "sfTcpListener",
    "sfTcpSocket",
    "sfUdpSocket",
    "sfUint16",
    "sfUint32",
    "sfUint64",
    "sfUint8",
    "sfVector2f",
    "sfVector2u",
    "sfVector2i",
    "sfVector3f",
    "sfVector3u",
    "sfVector3i",
    "sfWindowHandle",
    "userData",
    "FILE",
    "DIR",
    "Elf_Byte",
    "Elf32_Sym",
    "Elf32_Off",
    "Elf32_Addr",
    "Elf32_Section",
    "Elf32_Versym",
    "Elf32_Half",
    "Elf32_Sword",
    "Elf32_Word",
    "Elf32_Sxword",
    "Elf32_Xword",
    "Elf32_Ehdr",
    "Elf32_Phdr",
    "Elf32_Shdr",
    "Elf32_Rel",
    "Elf32_Rela",
    "Elf32_Dyn",
    "Elf32_Nhdr",
    "Elf64_Sym",
    "Elf64_Off",
    "Elf64_Addr",
    "Elf64_Section",
    "Elf64_Versym",
    "Elf64_Half",
    "Elf64_Sword",
    "Elf64_Word",
    "Elf64_Sxword",
    "Elf64_Xword",
    "Elf64_Ehdr",
    "Elf64_Phdr",
    "Elf64_Shdr",
    "Elf64_Rel",
    "Elf64_Rela",
    "Elf64_Dyn",
    "Elf64_Nhdr",
    "_Bool",
    "WINDOW"
]

_MODIFIERS = (
    "inline",
    "static",
    "unsigned",
    "signed",
    "short",
    "long",
    "volatile",
    "struct",
)

_MODIFIERS_REGEX = '|'.join(_MODIFIERS)
FUNCTION_PROTOTYPE_REGEX = (
    fr"^[\t ]*(?P<modifiers>(?:(?:{_MODIFIERS_REGEX})[\t ]+)*)"
    r"(?!else|typedef|return)(?P<type>\w+)\**[\t ]+\**[\t ]*\**[\t ]*"
    r"(?P<name>\w+)(?P<spaces>[\t ]*)"
    r"\((?P<parameters>[\t ]*"
    r"(?:(void|(\w+\**[\t ]+\**[\t ]*\**\w+[\t ]*(,[\t \n]*)?))+|)[\t ]*)\)"
    r"[\t ]*"
    r"(?P<endline>;\n|\n?{*\n){1}"
)

def _get_lines_without_comments(filepath: str) -> str:
    buf = io.StringIO()

    for line in get_lines(filepath, replace_comments=True):
        buf.write(line)
        buf.write('\n')

    return buf.getvalue()


def check_function_return_type():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue

        s = _get_lines_without_comments(file)
        p = re.compile(FUNCTION_PROTOTYPE_REGEX, re.MULTILINE)
        for search in p.finditer(s):
            line_start = s.count('\n', 0, search.start()) + 1
            if (
                search.group('type')
                and not re.match("^[a-z][a-z0-9_]*$", search.group('type'))
                and search.group('type') not in ALLOWED_TYPES
            ):
                vera.report(file, line_start, "MINOR:C-V1")


def check_macro_names():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue

        defines = vera.getTokens(file, 1, 0, -1, -1, ["pp_define"])

        for df in defines:
            line = vera.getLine(file, df.line)
            index = line.find("define")

            if index == -1:
                continue

            cut = line[index + len("define"):].lstrip()
            end_cut = min(map(cut.find, " \t\n("))

            if end_cut == -1:
                macro_name = cut.strip()
            else:
                macro_name = cut[:end_cut].strip()
            if not re.match(r"[A-Z$]([\$A-Z_0-9]+)", macro_name):
                vera.report(file, df.line, "MINOR:C-V1")

check_function_return_type()
check_macro_names()
EOF

cat << EOF > './C-V3.py'
import vera

from utils import is_source_file, is_header_file, get_star_token_type, StarType, find_token_index


def check_pointer_attachments():
    for file in vera.getSourceFileNames():
        if not is_source_file(file) and not is_header_file(file):
            continue

        stars = vera.getTokens(file, 1, 0, -1, -1, ["star"])

        for star in stars:
            tokens = tuple(vera.getTokens(file, star.line, 0, star.line + 1, -1, []))
            i = find_token_index(tokens, star)
            star_type = get_star_token_type(tokens, i)

            if star_type not in {StarType.POINTER, StarType.DEREFENCE}:
                continue

            # Chained ptr (eg: char **)
            if tokens[i - 1].name == 'star':
                if tokens[i + 1].name == 'star':
                    continue
                if tokens[i + 1].name == 'space':
                    vera.report(file, star.line, "MINOR:C-V3")
                continue

            if (
                tokens[i - 1].name not in {'space', 'leftparen', 'leftbracket'}
                and star_type == StarType.POINTER
            ):
                vera.report(file, star.line, "MINOR:C-V3")

            # pointer edge case: ( *[])
            elif tokens[i - 2].name == "leftparen":
                vera.report(file, star.line, "MINOR:C-V3")

            if tokens[i + 1].name == "space":
                vera.report(file, star.line, "MINOR:C-V3")


if __name__ == "__main__":
    check_pointer_attachments()
EOF

cat << EOF > './utils/__init__.py'
import re
from dataclasses import dataclass
from os import path
from sys import stderr

from enum import Enum, auto
from typing import List, Optional, Sequence

import vera
from .cache import cached, cached_filename

LOWER_SNAKECASE_REGEX = re.compile(r'^[a-z](?:_?[a-z0-9]+)*$')
UPPER_SNAKECASE_REGEX = re.compile(r'^[A-Z](?:_?[A-Z0-9]+)*$')

ASSIGN_TOKENS = [
    'assign',
    'plusassign',
    'minusassign',
    'starassign',
    'divideassign',
    'percentassign',
    'xorassign',
    'andassign',
    'shiftleftassign',
    'shiftrightassign',
    'orassign'
]

BINARY_OPERATORS_TOKENS = [
    'plus',
    'minus',
    'star',
    'divide',
    'greater',
    'greaterequal',
    'less',
    'lessequal',
    'equal',
    'notequal',
    'or',
    'andand',
    'and',
    'percent',
    'xor',
    'shiftleft',
    'shiftright',
    'oror',
    'colon',
    'question_mark'
] + ASSIGN_TOKENS

PREPROCESSOR_TOKENS = [
    'pp_define',
    'pp_elif',
    'pp_else',
    'pp_endif',
    'pp_error',
    'pp_hheader',
    'pp_if',
    'pp_ifdef',
    'pp_ifndef',
    'pp_include',
    'pp_line',
    'pp_number',
    'pp_pragma',
    'pp_qheader',
    'pp_undef',
    'pp_warning'
]

UNARY_OPERATORS_TOKENS = [
    'and',
    'plus',
    'minus',
    'not',
    'sizeof',
    'star'
]

INCREMENT_DECREMENT_TOKENS = [
    'plusplus',
    'minusminus'
]

VALUE_MODIFIER_TOKENS = ASSIGN_TOKENS + INCREMENT_DECREMENT_TOKENS

LITERALS_TOKENS = [
    'intlit',
    'stringlit',
    'charlit',
    'floatlit',
    'longintlit'
]

TYPES_TOKENS = [
    'auto',
    'bool',
    'char',
    'comma',
    'const',
    'decimalint',
    'double',
    'enum',
    'extern',
    'float',
    'hexaint',
    'inline',
    'int',
    'long',
    'mutable',
    'octalint',
    'register',
    'short',
    'signed',
    'static',
    'typedef',
    'union',
    'unsigned',
    'virtual',
    'void',
    'volatile',
    'struct'
]

IDENTIFIERS_TOKENS = [
    'identifier',
] + LITERALS_TOKENS

KEYWORDS_TOKENS = [
    'break',
    'default',
    'return',
    'case',
    'continue',
    'default',
    'goto',
    'typeid',
    'typename',
    'struct',
    'if',
    'for',
    'while',
    'do',
    'switch'
]

PARENTHESIS_TOKENS = [
    'leftparen',
    'rightparen'
]

SQUARE_BRACKETS_TOKENS = [
    'leftbracket',
    'rightbracket'
]

CONTROL_STRUCTURE_TOKENS = [
    'if',
    'else',
    'while',
    'do',
    'for',
    'switch'
]

# Tokens that do not influence the semantic of the code
NON_SEMANTIC_TOKENS = [
    'space',
    'space2',
    'newline',
    'ccomment',
    'cppcomment'
]

STRUCTURE_ACCESS_OPERATORS_TOKENS = [
    'dot',
    'arrow',
    'arrowstar'
]

@dataclass
class Token:
    file: str
    value: str
    line: int
    column: int
    name: str
    type: str
    raw: str


@cached_filename
def is_header_file(file: str) -> bool:
    return file.endswith('.h') and not is_binary(file)


@cached_filename
def is_source_file(file: str) -> bool:
    return file.endswith('.c') and not is_binary(file)


def is_makefile(file: str) -> bool:
    if is_binary(file):
        return False

    return (
        get_extension(file) in ('.mk', '.mak', '.make')
        or any(
            get_filename(file).startswith(makefile_name)
            for makefile_name in ("Makefile", "makefile", "GNUmakefile")
        )
    )


def is_binary(file: str) -> bool:
    return vera.isBinary(file)


def get_extension(file: str) -> str:
    _, extension = path.splitext(file)
    return extension


def get_filename_without_extension(file: str) -> str:
    extension = get_extension(file)
    if extension:
        return path.basename(path.splitext(file)[0])
    return path.basename(file)


@cached_filename
def get_filename(file: str) -> str:
    return path.basename(file)


def is_upper_snakecase(raw: str) -> bool:
    return re.fullmatch(UPPER_SNAKECASE_REGEX, raw) is not None


def is_lower_snakecase(raw: str):
    return re.fullmatch(LOWER_SNAKECASE_REGEX, raw) is not None


def debug_print(s, **kwargs):
    print(s, file=stderr, flush=True, **kwargs)


def __remove_between(lines: List[str], token: Token, begin_token="//", end_token=None) -> None:
    for offset, value in enumerate(token.value.split("\n")):
        line = lines[token.line - 1 + offset]
        has_line_break = line.endswith('\\\\')

        head = line[:token.column] if offset == 0 else ""
        if (len(line) - (len(head) + len(value))) > 0:
            tail = line[-(len(line) - (len(head) + len(value))):]
        else:
            tail = ""

        if begin_token and end_token and value.startswith(begin_token) and value.endswith(end_token):
            line = head + begin_token + ' ' * (len(value) - (len(begin_token) + len(end_token))) + end_token + tail
        elif begin_token and value.startswith(begin_token):
            line = head + begin_token + ' ' * (len(value) - len(begin_token)) + tail
        elif end_token and value.endswith(end_token):
            line = head + ' ' * (len(value) - len(end_token)) + end_token + tail
        else:
            line = ' ' * len(line)

        if has_line_break:
            line = line[:-1] + '\\\\'

        lines[token.line - 1 + offset] = line


def __reset_token_value(lines: List[str], token:Token) -> Token:
    value = token.value
    line = lines[token.line - 1][token.column:]
    offset = 0
    while not line.replace('\\\\', '').replace('\n', '').startswith(value.replace('\\\\', '').replace('\n', '')) and (token.line - 1 + offset + 1) < len(lines):
        offset += 1
        line = line + '\n' + lines[token.line - 1 + offset]
    diff = len(line.replace('\\\\', '').replace('\n', '')) - len(value.replace('\\\\', '').replace('\n', ''))
    if diff > 0:
        line = line[:-diff]
    return Token(
        token.file,
        line,
        token.line,
        token.column,
        token.name,
        token.type,
        token.raw
    )


def _compute_get_lines_cache_key(file: str, replace_comments=False, replace_stringlits=False):
    # Hash key for get_lines: (Hash, bool, bool) which is a valid Dict key
    return hash(file), replace_comments, replace_stringlits


@cached(_compute_get_lines_cache_key)
def get_lines(file: str, replace_comments=False, replace_stringlits=False) -> List[str]:
    lines = vera.getAllLines(file)
    if replace_comments or replace_stringlits:
        lines = [l[:] for l in lines]
    if replace_comments:
        comments = vera.getTokens(file, 1, 0, -1, -1, ['ccomment', 'cppcomment'])
        for comment in comments:
            comment = __reset_token_value(lines, comment)
            if comment.type == 'ccomment':  # /*  */
                __remove_between(lines, comment, '/*', '*/')
            elif comment.type == 'cppcomment':  # //
                __remove_between(lines, comment, '//')

    if replace_stringlits:
        stringlits = vera.getTokens(file, 1, 0, -1, -1, ['stringlit'])
        for stringlit in stringlits:
            stringlit = __reset_token_value(lines, stringlit)
            __remove_between(lines, stringlit, '"', '"')
    return lines


def is_line_empty(line: str):
    # A line only made of spaces is considered empty
    return len(line) == 0 or line.isspace()


def get_index_from_raw(raw: str, line: int, column: int):
    lines = raw.split('\n')
    len_before_current_line = len('\n'.join(lines[:line - 1]))
    len_before_column = lines[line - 1][:column]
    return len_before_current_line + len_before_column


def get_prev_token_index(tokens: List[Token], index: int, types_filters: List[str]):
    for i in range(0, index):
        token = tokens[index - i - 1]
        if token.name in types_filters:
            return index - i - 1
    return -1


def get_next_token_index(tokens: List[Token], index: int, types_filters: List[str]):
    for i in range(index + 1, len(tokens)):
        token = tokens[i]
        if token.name in types_filters:
            return i
    return -1


class StarType(Enum):
    MULTIPLICATION = auto()
    DEREFENCE = auto()
    POINTER = auto()
    LONELY = auto()
    UNCLEAR = auto()


def _parse_star_left_paren(names: List[str], tok_count: int, index: int) -> StarType:
    # lonely ptr, eg : \`*(int *(*)[])\`
    if names[index + 1] == "rightparen":
        return StarType.LONELY

    if names[index + 1] == "identifier":
        # type ptr or dereference
        while index < tok_count and names[index] != "rightparen":
            index += 1

        if index == tok_count:
            return StarType.UNCLEAR

        # - Dereference: not followed by a leftparen or leftbracket
        if names[index + 1] not in {"leftparen", "leftbracket"}:
            return StarType.DEREFENCE

        # - Function: ptr (*f)(...)
        # - Type:  int (*arr)[3]
        return StarType.POINTER

    return StarType.UNCLEAR


def _parse_star_left_token(names: List[str], tok_count: int, index: int) -> Optional[StarType]:

    if names[index - 1] == "leftparen":
        return _parse_star_left_paren(names, tok_count, index)

    if names[index - 1] == "rightparen":
        return StarType.MULTIPLICATION

    if names[index - 1] == "star":
        has_ident = all(name not in TYPES_TOKENS for name in names[:index])
        return StarType.DEREFENCE if has_ident else StarType.POINTER

    if names[index - 1] == "assign":
        return StarType.DEREFENCE

    return None


def get_star_token_type(tokens: Sequence["vera.Token"], index: int) -> StarType:
    token = tokens[index]

    code_tokens = [t for t in tokens if t.name != "space"]
    index = find_token_index(code_tokens, token)

    names = [t.name for t in code_tokens]
    tok_count = len(names)

    if index in {0, tok_count}:
        return StarType.UNCLEAR

    conclusion = _parse_star_left_token(names, tok_count, index)
    if conclusion is not None:
        return conclusion

    # If the line contains very few tokens, it can be unclear
    # whether the statement is a multiplication or a pointer declaration.

    # However, it is way more likely to be a pointer declaration as
    # a unassigned multiplication would be useless to the program.

    # Eg: \`sfEvent *event\` vs \`a * b\`
    # We will prioterize pointer declaration for known types
    if (
        names[index + 1] in {"semicolon", "assign"}
        or names[index - 1] in TYPES_TOKENS
        or code_tokens[index - 1].value.endswith('_t')
    ):
        return StarType.POINTER

    return StarType.UNCLEAR


def find_token_index(tokens, target) -> int:
    for i, token in enumerate(tokens):
        if token.column == target.column and token.line == target.line:
            return i

    return -1


def filter_out_non_semantic_tokens(tokens: List[Token]) -> List[Token]:
    return list(filter(lambda t: t.name not in NON_SEMANTIC_TOKENS, tokens))
EOF

cat << EOF > './utils/cache.py'
from functools import wraps


def cached(hash_method):
    # it would be event better to have the __cache at file scope but
    # the check_code_quality force us to put it there...
    __cache = {}

    def wrapper(func):

        @wraps(func)
        def wrapped(*args, **kwargs):
            key = (func.__name__, hash_method(*args, **kwargs))
            cached_value = __cache.get(key)

            if cached_value is not None:
                return cached_value

            result = func(*args, **kwargs)
            __cache[key] = result
            return result

        return wrapped
    return wrapper


def cached_filename(func):
    # Set within a function
    # to avoid check_code_quality "global variables case" report
    # cached_filename = cached(lambda filename, *_, **__: filename)
    return cached(lambda filename, *_, **__: filename)(func)
EOF

cat << EOF > './utils/functions/__init__.py'
import re
from dataclasses import dataclass
from enum import Enum
from typing import List, Callable, Tuple

import clang.cindex

import vera

from .. import cached_filename, ASSIGN_TOKENS, STRUCTURE_ACCESS_OPERATORS_TOKENS, Token

from .function import Function
from .section import Section
from .utils import remove_attributes, get_column
from .. import CONTROL_STRUCTURE_TOKENS, TYPES_TOKENS, get_lines, filter_out_non_semantic_tokens

RESERVED_KEYWORDS = [
    "break",
    "case",
    "continue",
    "default",
    "do",
    "else",
    "for",
    "goto",
    "if",
    "return",
    "sizeof",
    "switch",
    "typedef",
    "while"
]

FUNCTION_REGEX = re.compile(
    r"(?P<beforeFunction>(^|#.+|(?<=[;}{]))([\n\s*/]*(^|(?<=[\n\s{};]))))"
    r"(?P<func>"
    r"(?P<type>((?!" + r"\W|".join(RESERVED_KEYWORDS) + r"\W)\w+[\w\s\n*,]*|(\w+[\s\t\n*]+)\(\*.*\)\(.*\))[\s\n*]+)"
                                                        r"(?P<name>(?<=[\n\s*])[\w$]+)[\s\n]*\([\n\s]*"
                                                        r"(?P<args>[^;{]*)[\n\s]*\)[\s\n]*"
                                                        r"(?P<functionStartChar>[;{]{1}))"
)


def __get_function_body(file: str, function_start_index: int):
    all_lines = get_lines(file, replace_comments=True)
    raw = '\n'.join(all_lines)
    braces_count = 0
    line_number = raw[:function_start_index].count('\n') + 1
    column_number = get_column(raw, line_number, function_start_index)
    tokens = vera.getTokens(file, line_number, column_number, -1, -1, ['leftbrace', 'rightbrace'])
    end_line_number = -1
    end_column_number = -1

    for token in tokens:
        if token.name == 'leftbrace':
            if braces_count == 0:
                line_number = token.line
                column_number = token.column
            braces_count += 1
        elif token.name == 'rightbrace':
            braces_count -= 1
        if braces_count == 0:
            end_line_number = token.line
            end_column_number = token.column
            break
    function_lines = all_lines[line_number - 1:end_line_number]
    function_lines[0] = function_lines[0][column_number:]
    function_lines[-1] = function_lines[-1][:end_column_number + 1]
    raw = '\n'.join(function_lines)
    return Section(
        line_start=line_number,
        line_end=end_line_number,
        column_start=column_number,
        column_end=end_column_number,
        raw=raw
    )


def __get_arguments_from_string(arguments_string: str):
    arguments_parts_array = arguments_string.split(',')
    argument = ""
    arguments = []

    for argument_part in arguments_parts_array:
        argument += argument_part
        if len(argument.strip()) > 0 and argument.count('(') == argument.count(')'):
            arguments.append(argument)
            argument = ""
    return arguments


def _get_function_from_clang_cursor(cursor: clang.cindex.Cursor, file_contents: str) -> Function:
    has_arguments_list = cursor.type.kind.name == 'FUNCTIONPROTO'
    has_body = False
    body_start = None
    parameters = []
    for c in cursor.get_children():
        if c.kind.name == 'COMPOUND_STMT':
            has_body = True
            body_start = c.extent.start
        elif c.kind.name == 'PARM_DECL':
            parameters.append(file_contents[c.extent.start.offset:c.extent.end.offset])
    body_end: clang.cindex.SourceLocation | None = None
    if has_body:
        body_end = cursor.extent.end
    is_inline = False
    for token in cursor.get_tokens():
        if token.spelling == cursor.spelling:
            break
        if token.spelling == 'inline':
            is_inline = True
            break
    return Function(
        prototype=Section(
            line_start=cursor.extent.start.line,
            line_end=body_start.line if has_body else cursor.extent.end.line,
            column_start=cursor.extent.start.column - 1,
            column_end=(body_start.column if has_body else cursor.extent.end.column) - 1,
            raw=file_contents[cursor.extent.start.offset:body_start.offset] if has_body else
            file_contents[cursor.extent.start.offset:cursor.extent.end.offset]
        ),
        body=Section(
            line_start=body_start.line,
            line_end=body_end.line,
            column_start=body_start.column - 1,
            column_end=body_end.column - 2,
            raw=file_contents[body_start.offset:body_end.offset]
        ) if has_body else None,
        arguments=parameters if has_arguments_list else None,
        raw=file_contents[cursor.extent.start.offset:body_end.offset] if has_body else None,
        return_type=cursor.type.get_result().spelling,
        name=cursor.spelling,
        static=cursor.storage_class.name == 'STATIC',
        inline=is_inline,
        variadic=has_arguments_list and cursor.type.is_function_variadic()
    )


@cached_filename
def get_functions(file: str) -> List[Function]:
    file_contents = '\n'.join(get_lines(file))

    parsed = clang.cindex.Index.create().parse(file).cursor
    new_functions = []

    if parsed.kind.name == 'TRANSLATION_UNIT':
        for tu_child in [
            c for c in parsed.get_children()
            if c.kind.name == 'FUNCTION_DECL' and str(c.location.file) == file
        ]:
            new_functions.append(_get_function_from_clang_cursor(tu_child, file_contents))
    return new_functions



@cached_filename
def get_functions_legacy(file: str) -> List[Function]:
    """
    Get all functions in a file using the legacy regex method.
    It is only used in order to detect functions not detected by Clang (e.g. GCC nested functions).
    get_functions() should be used instead.

    :param file: The file name
    :return: A list of functions
    """
    raw = '\n'.join(get_lines(file, replace_comments=True, replace_stringlits=True))
    uncommented = remove_attributes(raw)
    matches = re.finditer(FUNCTION_REGEX, uncommented)
    functions = []
    for match in matches:
        before_function_len = len(match.group("beforeFunction"))
        match_start = match.start() + before_function_len + 1
        raw_match = match.group()[before_function_len + 1:]
        if match.group("functionStartChar") == ';':
            function_body = None
        else:
            function_body = __get_function_body(file, match.end() - 1)
        proto_start_line = raw.count('\n', 0, match.start()) + match.group("beforeFunction").count('\n') + 1
        proto_start_column = get_column(raw, proto_start_line, match_start - 1)
        proto_end_line = proto_start_line + raw_match.count('\n')
        proto_end_column = get_column(raw, proto_end_line, match.end() - 1)
        prototype_raw = raw_match[:match.end() - 1]
        functions.append(Function(
            prototype=Section(
                line_start=proto_start_line,
                line_end=proto_end_line,
                column_start=proto_start_column,
                column_end=proto_end_column,
                raw=prototype_raw
            ),
            body=function_body,
            raw=prototype_raw + (function_body.raw if function_body else ""),
            return_type=match.group("type"),
            name=match.group("name"),
            arguments=__get_arguments_from_string(match.group("args")),
        ))
    return functions


def get_function_body_tokens(file: str, func: Function) -> list[Token]:
    """
    Get the tokens of the function body, between and excluding the body braces.

    :param file: The file name
    :param func: The function
    :return:
    """
    return vera.getTokens(
        file,
        func.body.line_start,
        func.body.column_start,
        func.body.line_end,
        func.body.column_end,
        []
    )[1:]


def _contains_ambiguous_statement(tokens: list[Token]) -> bool:
    i = 0
    while i < len(tokens) and tokens[i].name == 'identifier':
        i += 1
    if i >= len(tokens) or i == 0:
        return False
    parentheses_pairs = 0
    while i < len(tokens) and tokens[i].name == 'leftparen':
        parentheses_pairs += 1
        i, _ = skip_interval(tokens, i, 'leftparen', 'rightparen')
        i += 1
    return parentheses_pairs == 2


def _starts_with_identifier_and_leftparen(tokens: list[Token]) -> bool:
    return (len(tokens) >= 2
            and tokens[0].name == 'identifier'
            and tokens[1].name == 'leftparen')


def _get_amount_of_variable_defining_identifiers(tokens: list[Token]) -> int:
    """
    Gets the amount of identifiers that are not inside brackets, and are not related to structure field access.

    :param tokens:
    :return:
    """
    amount = 0
    i = 0
    while i < len(tokens):
        token = tokens[i]
        # "new" is included as it is a valid C identifier, but a reserved keyword in C++
        if token.name in ['identifier', 'new']:
            if i + 1 < len(tokens) and tokens[i + 1].name == 'leftparen':
                return 0
            if ((i + 1 >= len(tokens) or tokens[i + 1].name not in STRUCTURE_ACCESS_OPERATORS_TOKENS)
                and (i - 1 < 0 or tokens[i - 1].name not in STRUCTURE_ACCESS_OPERATORS_TOKENS)):
                amount += 1
        elif token.name == 'leftbracket':
            i, _ = skip_interval(tokens, i, 'leftbracket', 'rightbracket')
        if tokens[i].name == 'rightbracket' and i + 1 < len(tokens) and tokens[i + 1].name == 'leftparen':
            # This is a function call following an indexing
            return 0
        i += 1
    return amount


class UnsureBool(Enum):
    TRUE = 'True'
    FALSE = 'False'
    UNSURE = 'Unsure'

    @staticmethod
    def from_bool(value: bool | None) -> 'UnsureBool':
        if value is None:
            return UnsureBool.UNSURE
        return UnsureBool.TRUE if value else UnsureBool.FALSE


def is_variable_declaration(statement: list[Token]) -> UnsureBool:
    if not statement:
        return UnsureBool.FALSE
    if statement[0].name in TYPES_TOKENS:
        return UnsureBool.TRUE

    tokens_before_assign = []
    for token in statement:
        if token.name == 'assign':
            break
        tokens_before_assign.append(token)
    if tokens_before_assign[0].name == 'identifier':
        if _contains_ambiguous_statement(tokens_before_assign):
            return UnsureBool.UNSURE
        if (_get_amount_of_variable_defining_identifiers(tokens_before_assign) >= 2
                and not _starts_with_identifier_and_leftparen(tokens_before_assign)
                and not any(map(lambda t: t.name in ASSIGN_TOKENS, tokens_before_assign))):
            return UnsureBool.TRUE
    return UnsureBool.FALSE


def skip_interval(
        tokens: list[Token],
        i: int,
        start_token_name: str,
        end_token_name: str
) -> Tuple[int, list[Token]]:
    """
    Skips an interval of tokens, starting from the token at index i,
    and ending at the first token with name end_token_name

    :param tokens: The tokens
    :param i: The index of the first token
    :param start_token_name: The name of the starting token
    :param end_token_name: The name of the ending token
    :return: The index of the ending token, and the skipped tokens
    """
    depth = 0
    skipped_tokens = []
    while i < len(tokens):
        token = tokens[i]
        if token.name == start_token_name:
            depth += 1
        elif token.name == end_token_name:
            depth -= 1
            if depth == 0:
                break
        # Starting token is not included in skipped tokens
        if depth != 0 and (token.name != start_token_name or depth != 1):
            skipped_tokens.append(token)
        i += 1
    return i, skipped_tokens


@dataclass
class _StatementType:
    ending_tokens: list[str]
    interval_tokens: tuple[str, str] | None = None
    end_after_first_skip: bool = False


_CONTROL_STRUCTURE_STATEMENT = _StatementType(
    ending_tokens=['leftbrace', 'semicolon'],
    interval_tokens=('leftparen', 'rightparen'),
    end_after_first_skip=True
)
_CASE_AND_DEFAULT_STATEMENT = _StatementType(
    ending_tokens=['colon']
)
_OTHER_STATEMENT = _StatementType(
    ending_tokens=['semicolon'],
    interval_tokens=('leftbrace', 'rightbrace')
)


def _get_statement_type(first_statement_token: Token) -> _StatementType | None:
    if first_statement_token.name in CONTROL_STRUCTURE_TOKENS:
        return _CONTROL_STRUCTURE_STATEMENT
    if first_statement_token.name in ['case', 'default']:
        return _CASE_AND_DEFAULT_STATEMENT
    if first_statement_token.name != 'rightbrace':
        return _OTHER_STATEMENT
    return None


def is_else(tokens: list[Token], i: int) -> bool:
    return i < len(tokens) and tokens[i].name == 'else' and (i + 1 >= len(tokens) or tokens[i + 1].name != 'if')


def _get_statement_tokens(tokens: list[Token], i: int, statement_type: _StatementType):
    statement_tokens = []
    skip_happened = False
    # Special handling for else (not for an else-if)
    is_else_special_case = is_else(tokens, i)
    if is_else_special_case:
        statement_tokens.append(tokens[i])
        skip_happened = True
    while not is_else_special_case and i < len(tokens) and tokens[i].name not in statement_type.ending_tokens:
        statement_tokens.append(tokens[i])
        if statement_type.interval_tokens and tokens[i].name == statement_type.interval_tokens[0]:
            i, skipped_tokens = skip_interval(tokens, i, statement_type.interval_tokens[0],
                                              statement_type.interval_tokens[1])
            statement_tokens += skipped_tokens
            if i < len(tokens):
                statement_tokens.append(tokens[i])
            if statement_type.end_after_first_skip:
                skip_happened = True
                break
        i += 1
    if skip_happened and i + 1 < len(tokens) and tokens[i + 1].name in statement_type.ending_tokens:
        statement_tokens.append(tokens[i + 1])
        i += 1
    elif not skip_happened and i < len(tokens) and tokens[i].name in statement_type.ending_tokens:
        statement_tokens.append(tokens[i])
    return statement_tokens, i


def get_function_statements(tokens: list[Token]) -> list[list[Token]]:
    filtered_tokens = filter_out_non_semantic_tokens(tokens)
    statements = []
    i = 0
    while i < len(filtered_tokens):
        current_statement = []

        statement_type = _get_statement_type(filtered_tokens[i])
        if statement_type:
            statement_tokens, i = _get_statement_tokens(filtered_tokens, i, statement_type)
            current_statement += statement_tokens
        else:
            current_statement.append(filtered_tokens[i])

        statements.append(current_statement)

        i += 1
    return statements


def for_each_function_with_statements(file: str, handler_func: Callable[[list[list[Token]]], None]) -> None:
    functions = get_functions(file)
    for func in functions:
        if func.body is None:
            continue
        function_tokens = get_function_body_tokens(file, func)
        statements = get_function_statements(function_tokens)
        handler_func(statements)
EOF

cat << EOF > './utils/functions/function.py'
from .section import Section

class Function:

    # pylint: disable=R0913, R0902
    def __init__(
        self,
        prototype: Section,
        body: Section | None,
        raw: str,
        return_type: str,
        name: str,
        arguments: list[str] | None,
        static: bool = False,
        inline: bool = False,
        variadic: bool = False
    ):
        self.prototype = prototype
        self.body = body
        self.raw = raw
        self.return_type = return_type
        self.name = name
        self.arguments = arguments
        self.static = static
        self.inline = inline
        self.variadic = variadic

    def __str__(self):
        base_str =(f'{"Static function" if self.static else "Function"}: {self.name} with prototype {self.prototype}'
                   f' returning {self.return_type}')
        if self.arguments is not None:
            if len(self.arguments) == 0:
                base_str += ', no arguments'
            else:
                base_str += f', arguments {self.arguments}'
        else:
            base_str += ', no defined argument list'
        if self.body:
            return f'{base_str} and body {self.body} (raw: "{self.body.raw}")'
        return f'{base_str} and no body'

    def __repr__(self):
        return str(self)

    def get_arguments_count(self) -> int:
        if self.arguments is None:
            return 0
        return len(self.arguments) + (1 if self.variadic else 0)
EOF

cat << EOF > './utils/functions/section.py'
class Section:

    # pylint: disable=R0913, R0902
    def __init__(
        self,
        line_start: int,
        line_end: int,
        column_start: int,
        column_end: int,
        raw: str
    ):
        self.line_start = line_start
        self.line_end = line_end
        self.column_start = column_start
        self.column_end = column_end
        self.raw = raw

    def __str__(self):
        return f'Section {self.line_start}:{self.column_start} to {self.line_end}:{self.column_end}'
EOF

cat << EOF > './utils/functions/utils.py'
import re

ATTRIBUTE_REGEX = re.compile(r"__attribute__\(\(\w*\)\)")

def get_column(raw: str, line_number: int, index: int):
    if line_number == 1:
        last_newline_index = 0
    else:
        last_newline_index = raw[:index].rindex('\n') + 1
    return index - last_newline_index

def remove_attributes(raw: str, keep_char_count: bool = True):
    matches = re.finditer(ATTRIBUTE_REGEX, raw)
    offset = 0

    for match in matches:
        match_size = match.end() - match.start()
        char_count = match_size * keep_char_count
        offset += match_size * (not keep_char_count)
        start = match.start() - offset
        end = match.end() - offset
        raw = raw[:start] + (' ' * char_count) + raw[end:]
    return raw
EOF
}

main "$@"
