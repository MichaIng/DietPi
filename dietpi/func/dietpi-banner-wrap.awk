function make_whitespace_offset(clean_line){
    ## Generate leading spaces based on global INDENT_TYPE
    if (INDENT_TYPE == "min"){
        return sprintf("%*s", INDENT_MIN, "")
    }
    lead_spaces = ""
    if ((INDENT_TYPE == "dash" || INDENT_TYPE == "dashcolon") && match(clean_line, green_dash)){
        lead_spaces = sprintf("%*s", RSTART + RLENGTH - 1, "")
    }
    if ((INDENT_TYPE == "colon" || INDENT_TYPE == "dashcolon") && match(clean_line, green_colon)){
        lead_spaces = sprintf("%*s", RSTART + RLENGTH - 1, "")
    }
    # Useable space check
    # - "Let's Encrypt cert status" would be squashed otherwise
    if ( (MAXCOL - length(lead_spaces)) < MIN_USEABLE_SPACE){
        lead_spaces = sprintf("%*s", INDENT_MIN, "")
    }
    return lead_spaces
}

BEGIN {
    green_dash = "^[[:space:]]+-[[:space:]]"  # green "bullets"
    green_colon = "[[:space:]]:[[:space:]]"  # green colon in middle
    color_regex = "[[:cntrl:]][[0-9;?]*[A-Za-z]"  # all color codes
    ## Init from CLI, or use defaults here
    if (MIN_USEABLE_SPACE == ""){MIN_USEABLE_SPACE = 8} ## min space on the right to keep
    if (MAXCOL == ""){MAXCOL = 30}                      ## Wrap to column number
    if (INDENT_MIN == ""){INDENT_MIN = 1}               ## min offset seen in dietpi banner
    if (INDENT_TYPE == ""){INDENT_TYPE = "dashcolon"}   ## Indent modes:
    ## min - use minimum
    ## dash - green_dash only
    ## colon - green_colon only
    ## dashcolon - match dash first then colon (colon overrides)
}

{
    ## ASCII ART: Skip or Hide
    if (match($0, /^[^a-zA-Z0-9─]+$/)){
        if (MAXCOL > (RSTART+RLENGTH)){print $0;}
        next;
    }
    ## Green Lines: Truncate to MAXCOL
    if (match($0, /────/)){
        new_grn_line = sprintf("%*s", MAXCOL - 2, "")    ## new line: of spaces
        gsub(/ /, "─", new_grn_line)                     ## new line: change spaces to line char
        gsub(/─/, "W", $0)  # hack:mawk cant handle /─*/ ## old line: change all line chars to W
        sub(/W+/, new_grn_line, $0)                      ## old line: change longest W to new line
        print; next;
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

    if (sn > 0 && wn != sn){
        print "[WARN] Color word order does not match stripped word order"
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
