function make_whitespace_offset(clean_line) {
    ## Generate leading spaces based on global INDENT_TYPE
    if (INDENT_TYPE == "fixed") {
        return sprintf("%*s", INDENT_FIXED, "")
    }
    lead_spaces = INDENT_MIN
    if (match(clean_line, green_dash)) {
        lead_spaces = RSTART + RLENGTH - 1
    }
    if ((INDENT_TYPE == "colon") && match(clean_line, green_colon)) {
        lead_spaces = RSTART + RLENGTH - 1
    }
    # Useable space check
    # - "Let's Encrypt cert status" would be squashed otherwise
    if ((MAXCOL - lead_spaces) < MIN_USEABLE_SPACE) {
        lead_spaces = INDENT_MIN
    }
    return sprintf("%*s", lead_spaces, "")
}

BEGIN {
    green_dash = "^[[:space:]]+-[[:space:]]"             # green "bullets"
    green_colon = "[[:space:]]:[[:space:]]"              # green colon in middle
    color_regex = "[[:cntrl:]][[0-9;?]*[A-Za-z]"         # all color codes
    ## Init from CLI, or use defaults here
    if (MIN_USEABLE_SPACE == "") {MIN_USEABLE_SPACE = 8} ## min space on the right to keep
    if (MAXCOL == "") {MAXCOL = 55}                      ## Wrap to column number
    if (INDENT_MIN == "") {INDENT_MIN = 3}               ## min offset, matching dash-alignment
    if (INDENT_FIXED == "") {INDENT_FIXED = 3}           ## fixed offset if INDENT_TYPE == "fixed"
    if (INDENT_TYPE == "") {INDENT_TYPE = "colon"}       ## Indent modes:
    ## fixed - use fixed offset
    ## dash - green_dash only
    ## colon - green_dash first then green_colon (colon overrides)
}

{
    ## ASCII ART: Skip or Hide
    if (match($0, /^[^a-zA-Z0-9─]+$/)) {
        if (MAXCOL > (RSTART + RLENGTH)) {print $0}
        next
    }
    ## Green Lines: Truncate to MAXCOL or 55
    if (match($0, /────/)) {
        if (MAXCOL < 55) {line_len = MAXCOL - 2}    ## line len: max column - leading space - count starts at 1
	else {line_len = 53}                        ## line len: 53 is the line length if word-wrap is disabled
        new_grn_line = sprintf("%*s", line_len, "") ## new line: of spaces
        gsub(/ /, "─", new_grn_line)                ## new line: change spaces to line char
        sub(/[─]+/, new_grn_line, $0)               ## old line: replace line with new line
        print; next
    }
    ## Begin word-wrapping
    ## - Wrap based on stripped colour position
    ## - Indent to either first green dash, or first green colon
    ##   based on INDENT_TYPE arg
    ## - If useable space after indenting is too small, or a long
    ##   word such as an URL cannot be split then indent to INDENT_MIN
    clean_line = $0
    gsub(color_regex, "", clean_line)      ## Line without color
    gsub(/[[:space:]]+/, " ", clean_line)  ## "dietpi-config" misaligned without this

    ## tokenize coloured line into "words", stripped line into "stripped_words"
    wn = split($0, words, /[[:space:]]+/)
    sn = split(clean_line, stripped_words, /[[:space:]]+/)

    if (sn > 0 && wn != sn) {
        print "[WARN] Banner word-wrap: Word count changed after stripping color codes"
        next
    }

    ## Determine leading spaces based on INDENT_TYPE
    lead_spaces = make_whitespace_offset(clean_line)

    charcount = 0    ## running char count for current line
    line = words[1]  ## start with first word, loop on the rest

    for (i = 2; i <= sn; i++) {
        stripped = stripped_words[i]
        word_len = length(stripped)

        new_count = charcount + word_len + 1 # Temporarily incr. by word
        if (new_count >= MAXCOL) {
            print line                       # Flush current line if longer than cols

            line = lead_spaces""words[i]     # Make new line with leading spaces
            if (length(line) >= MAXCOL) {
                lead_spaces = sprintf("%*s", INDENT_MIN, "")
                ## Word might simply be too long to pad, use the minimum
                ## e.g. URLs can't be easily split
                line = lead_spaces""words[i]
            }
            charcount = length(lead_spaces) + word_len
        } else {                             # Otherwise append word to current line
            line = line" "words[i]
            charcount = new_count
        }
    }
    print line  # Flush leftover line
}
