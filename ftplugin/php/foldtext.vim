" Vim folding via fold-expr
" Language: PHP
"
" Maintainer: Jake Soward <swekaj@gmail.com>
"
" Options: 
"           b:phpfold_text = 1 - Enable custom foldtext() function
"
if exists('b:phpfold_text') && !b:phpfold_text
    finish
endif

setlocal foldtext=GetPhpFoldText()

function! GetPhpFoldText()
    let line = getline(v:foldstart)

    " Start off with the normal, the fold-level dashes and number of lines in the fold.
    let text = v:folddashes . ' ' . (v:foldend-v:foldstart+1) . ' lines: '

    if line =~? '\v^\s*/\*\*?\s*$' " Comments
        " If the DocBlocks are being folded with the function they document, include the function signature in the foldtext.
        if b:phpfold_doc_with_funcs
            let funcline = FindNextFunc(v:foldstart)
            if funcline > 0
                let text .= ExtractFuncName(funcline) . '{...} - '
            endif
        endif
        " Display the docblock summary, if it's one two lines attempt to display both lines for the entire summary.
        let nline = getline(v:foldstart+1)
        let text .= substitute(nline, '\v\s*\*(\s|\*)*', '', '')
        if nline !~? '\v\.$'
            let text .= substitute(getline(v:foldstart+2), '\v\s*\*(.{-}\.)\s*.*', '\1', '')
        endif
    elseif line =~? '\v\s*(abstract\s+|public\s+|private\s+|static\s+|private\s+)*function\s+\k'
        " Name functions and methods
        let text .= ExtractFuncName(v:foldstart)
        let text .= '{...}'
    elseif getline(v:foldstart-1) =~? '\v\)\s+use\s+\(|\s*(abstract\s+|public\s+|private\s+|static\s+|private\s+)*function\s+(\k+[^)]+$|\([^{]*$)'
        " If a named function's arguments are multiple lines and in their own fold, display the arguments in a list
        let cline = v:foldstart
        while cline <= v:foldend
            let text .= substitute(getline(cline), '\v^\s*([^,]+,?).*', '\1 ', '')
            let cline += 1
        endwhile
    elseif line =~? '\v\s+function\s+\(' " Closures
        " Start with the line save the indent spacing.
        let text .= substitute(line, '\v^\s*', '\1', '')
        let text .= '...'
        " The end result of all of this is an attempt to convey an overview of the closure.
        " If there is a variable-use list defined, it is displayed.
        " If either the argument list or variable-use list are listed on one line, then they are included in the fold text.
        " If either of them are listed on multiple lines, they are instead display as (...).
        " The function block is displayed as {...}.
        " Examples:
        "   --- 4 lines: $closure = function () {...}-----
        "   --- 8 lines: $closure = function () use ($var1, $var2) {...}-----
        "   -- 13 lines: $closure = function ($arg1) use (...) {...}-----
        if line =~? '\v\)\s+use\s+\([^)]*$'
            " Arg list is on one line, use list is not.
            let text .= ') {...}'
        elseif FuncHasUse(v:foldstart+1) > 0
            " Arg lsit is on multiple lines and there is a use list.
            let uline = getline(FuncHasUse(v:foldstart+1))
            " If the use list is on multiple lines, display (...) for it, otherwise display the list
            if uline =~? '\vuse\s+\([^)]+\) \{'
                let text .= substitute(uline, '\v^.*\)\s+use\s+(\([^)]+\)\s*\{)', ') use \1...}', '')
            else
                let text .= ') use (...) {...}'
            endif
        elseif line =~? '\v\(\) \{\s*$'
            " There is no use list and no arguments
            let text .= '}'
        elseif line =~? '\vuse\s+\([^)]+\)\s+\{\s*$'
            " The arg list (if present) and use list are both on one line
            let text .= '}'
        else
            " The arg list is on multiple lines and there is no use list
            let text .= ') {...}'
        endif
    elseif line =~? '\v^use\s+'
        " Display the last part of each namespace import/alias in a list
        let text .= 'use '
        let cline = v:foldstart
        while cline <= v:foldend
            let text .= substitute(getline(cline), '\v^use\s+.{-}(\k+);.*', '\1, ', '')
            let cline += 1
        endwhile
        let text = substitute(text, ', $', '', '')
    elseif line =~? '\v^\s*case\s*.*:'
        " If there are multiple case statements in a row, display them all in a list
        let cline = v:foldstart
        while line =~? '\v^\s*case\s*.*:'
            let text .= substitute(line, '\v^\s*(.{-}:)\s*$', '\1 ', '')
            let cline += 1
            let line = getline(cline)
        endwhile
    elseif line =~? '\v^\s*default:'
        " Remove any leading or trailing whitespace around default:
        let text .= 'default: '
    else
        " Handle simple folds such as arrays and stand-alone function declarations.
        let text .= substitute(line, '\v[ }]*(.{-})\s*(\S*)$', '\1 \2', '')
        let text .= '...'
        let etext = ExtractEndDelim(v:foldend)
        if empty(etext)
            let text .= ExtractEndDelim(v:foldend+1)
        else
            let text .= etext
        endif
    endif

    return text
endfunction

" Finds the next line that has a function declaration.  Limit search to the folded region.
function! FindNextFunc(lnum)
    let current = a:lnum+1
    let stopline = v:foldend

    while current <= stopline
        if getline(current) =~? '\v\s*\*/'
            if getline(current+1) =~? '\v\s*(abstract\s+|public\s+|static\s+|private\s+)*function\s+\k'
                return current+1
            endif
            return -1
        endif

        let current += 1
    endwhile

    return -2
endfunction

" Extracts the name and visibility of a function from the given line.
function! ExtractFuncName(lnum)
    return substitute(getline(a:lnum), '\v.{-}(abstract\s+|public\s+|private\s+|static\s+|private\s+)*function\s+(\k+).*', '\1\2() ', '')
endfunction

" Extracts the last delimiter(s) of the line.
function! ExtractEndDelim(lnum)
    return matchstr(getline(a:lnum), '\v^[^\]})]*\zs[\]})]+\ze.*$')
endfunction

" Determines if the function in the fold region has a use list, and returns where the use keyword is located.
function! FuncHasUse(lnum)
    let current = a:lnum
    let stopLine = v:foldend

    while current <= stopLine
        if getline(current) =~? '\v\s*\)\s+use\s+\('
            return current
        elseif getline(current) =~? '\v^\s*(\)\s+)?\{'
            return -1
        endif
        let current += 1
    endwhile
    return 0
endfunction