# Snapshot file
# Unset all aliases to avoid conflicts with functions
unalias -a 2>/dev/null || true
# Functions
.autocomplete:async:_describe () {
	local -i _autocomplete__described_lines=1 
	autocomplete:async:_describe:old "$@"
}
.autocomplete:async:clear () {
	unset curcontext _autocomplete__isearch
	.autocomplete:async:reset-context
	builtin zle -Rc
	return 0
}
.autocomplete:async:compadd () {
	local -A _opts_=() 
	local -a _xopts_=() _displ_=() _matches_=() 
	local -P _displ_name_= _matches_name_= 
	zparseopts -A _opts_ -E -- D: E: O: X:=_xopts_ x:=_xopts_
	local -Pi _unused_lines_=$(( _autocomplete__max_lines - compstate[list_lines] )) 
	if [[ -v _autocomplete__described_lines && -n $_grp ]]
	then
		if [[ -z $_opts_[-D] ]]
		then
			builtin compadd "$@"
			return
		fi
		_displ_name_=$_opts_[-D] 
		_matches_name_=$_opts_[-O] 
		if [[ -v _autocomplete__partial_list ]]
		then
			set -A $_displ_name_
			[[ -n $_matches_name_ ]] && set -A $_matches_name_
		fi
		builtin compadd "$@"
		local -Pi _ret_=$? 
		local -i _ndisplay_=${(PA)#_displ_name_} 
		local -i _lines_left_for_describe_=$(( _unused_lines_ - _autocomplete__described_lines )) 
		if (( ${#${(u)${(PA)_displ_name_}[@]#*:}} > _lines_left_for_describe_ ))
		then
			local -Pi _matches_to_remove=$(( _ndisplay_ - max( 0, _lines_left_for_describe_ ) )) 
			if (( _matches_to_remove < _ndisplay_ ))
			then
				shift -p $_matches_to_remove $_displ_name_ $_matches_name_
			else
				set -A $_displ_name_
				[[ -n $_matches_name_ ]] && set -A $_matches_name_
			fi
			_ndisplay_=${(PA)#_displ_name_} 
			.autocomplete:async:compadd:disable
		fi
		(( _autocomplete__described_lines += _ndisplay_ ))
		return _ret_
	fi
	if [[ -v _autocomplete__partial_list ]]
	then
		[[ -n $_opts_[-D] ]] && set -A $_opts_[-D]
		[[ -n $_opts_[-O] ]] && set -A $_opts_[-O]
		return 1
	fi
	if [[ -n $_opts_[-D]$_opts_[-O] ]]
	then
		builtin compadd "$@"
		return
	fi
	local -i _old_total_lines=$compstate[list_lines] 
	local -Pi _total_new_lines_="$(
      zparseopts -a _xopts_ -D -E -- X: x:
      builtin compadd "$@"
      print -nr -- $(( $compstate[list_lines] - _old_total_lines ))
  )" 
	local -Pi _new_completion_lines_="$(
      zparseopts -a _xopts_ -D -E -- X: x:
      builtin compadd "$@"
      print -nr -- $(( $compstate[list_lines] - _old_total_lines ))
  )" 
	local -Pi _new_heading_lines_=$(( _total_new_lines_ - _new_completion_lines_ )) 
	if (( _total_new_lines_ + $compstate[list_lines] <= _autocomplete__max_lines ))
	then
		builtin compadd "$@"
		return
	fi
	if (( _new_heading_lines_ > 1 && _new_completion_lines_ < 1 ))
	then
		.autocomplete:async:compadd:disable
		return 1
	fi
	local -a _dopt_=() 
	zparseopts -a _dopt_ -D -E -- d: ld:
	_displ_name_=$_dopt_[2] 
	local -a _Dopt_=() 
	[[ -n $_displ_name_ ]] && _Dopt_=(-D $_displ_name_) 
	builtin compadd -O _matches_ $_Dopt_ "$@"
	if [[ -z $_displ_name_ ]]
	then
		_displ_name_=_displ_ 
		_displ_=("$_matches_[@]") 
		_dopt_=(-d $_displ_name_) 
	fi
	local -Pi _nmatches_per_line_=$(( 1.0 * $#_matches_ / _new_completion_lines_ )) 
	if (( _nmatches_per_line_ < 1 ))
	then
		set -A $_displ_name_ ${(@r:COLUMNS-1:)${(PA)_displ_name_}[@]//$'\n'/\n}
		_dopt_=(-ld $_displ_name_) 
		(( _nmatches_per_line_ = 1 ))
	fi
	local -Pi _nmatches_that_fit_=$((
      ( _unused_lines_ - _new_heading_lines_ ) * _nmatches_per_line_
  )) 
	local -Pi _nmatches_to_remove_=$(( $#_matches_ - max( 0, _nmatches_that_fit_ ) )) 
	if (( _nmatches_to_remove_ > 0 ))
	then
		(( _nmatches_to_remove_++ ))
		if (( _nmatches_to_remove_ < $#_matches_ ))
		then
			shift -p $_nmatches_to_remove_ _matches_ $_displ_name_
		else
			set -A _matches_
			set -A $_displ_name_
		fi
		.autocomplete:async:compadd:disable
	fi
	_autocomplete__compadd_opts_len "$@"
	builtin compadd "$_dopt_[@]" -a "$@[1,?]" _matches_
}
.autocomplete:async:compadd:disable () {
	typeset -g _autocomplete__partial_list=$curtag 
	comptags () {
		false
	}
}
.autocomplete:async:complete () {
	if [[ -v _autocomplete__inserted ]]
	then
		unset _autocomplete__inserted
		typeset -g curcontext= 
		builtin zstyle -s :autocomplete: default-context curcontext
	fi
	.autocomplete:async:save-state
	.autocomplete__zle-flags || return 0
	(( KEYS_QUEUED_COUNT || PENDING )) && return
	[[ -v ZSH_AUTOSUGGEST_IGNORE_WIDGETS ]] && (( ZSH_AUTOSUGGEST_IGNORE_WIDGETS[(I)$LASTWIDGET] )) && unset POSTDISPLAY
	[[ $LASTWIDGET == (autosuggest-suggest|.autocomplete:async:*:fd-widget) ]] && return 0
	{
		if (( REGION_ACTIVE )) || [[ -v _autocomplete__isearch && $LASTWIDGET == *(incremental|isearch)* ]]
		then
			builtin zle -Rc
			return 0
		fi
		builtin zstyle -t ":autocomplete:${LASTWIDGET}:" ignore && return 0
		local -Pa ignored=('_complete_help' '(copy|insert)-*-word' 'describe-key-briefly' '(|reverse-)menu-complete' 'what-cursor-position' 'where-is') 
		[[ ${LASTWIDGET##.} == (${(~j:|:)~ignored}) ]] && return 0
		[[ $KEYS == ([\ -+*]|$'\e\t') ]] && builtin zle -Rc
		[[ -v _FAST_MAIN_CACHE ]] && _zsh_highlight
		typeset -ga _autocomplete__region_highlight=("$region_highlight[@]") 
		if [[ -v ZSH_AUTOSUGGEST_IGNORE_WIDGETS ]] && (( ZSH_AUTOSUGGEST_IGNORE_WIDGETS[(I)$LASTWIDGET] ))
		then
			unset POSTDISPLAY
		fi
		.autocomplete:async:wait
	}
	return 0
}
.autocomplete:async:complete:fd-widget () {
	setopt localoptions NO_banghist
	{
		local +h -F SECONDS=0.0 
		local -i fd=$1 
		{
			builtin zle -F $fd
			if [[ -n $_autocomplete__zle_flags ]]
			then
				builtin zle -f $_autocomplete__zle_flags
				[[ $_autocomplete__zle_flags == yank* ]] && return 0
			fi
			(( KEYS_QUEUED_COUNT || PENDING )) && return
			.autocomplete:async:same-state || return 0
			local -a reply=() 
			IFS=$'\0' read -rAu $fd
			shift -p reply
			(( SECONDS += reply[2] ))
		} always {
			exec {fd}<&-
		}
		[[ -n $curcontext ]] && setopt $_autocomplete__ctxt_opts[@]
		local +h PS4=$_autocomplete__ps4 
		if ! builtin zle ._list_choices -w "$reply[1]" 2>>| $_autocomplete__log
		then
			typeset -g _autocomplete__overhead=$SECONDS 
			typeset -g region_highlight=("$_autocomplete__region_highlight[@]") 
			[[ -v functions[_zsh_autosuggest_highlight_apply] ]] && _zsh_autosuggest_highlight_apply
			builtin zle -R
		fi
		.autocomplete:async:reset-state
		return 0
	}
}
.autocomplete:async:isearch-exit () {
	unset _autocomplete__isearch
}
.autocomplete:async:isearch-update () {
	typeset -gi _autocomplete__isearch=1 
}
.autocomplete:async:list-choices:completion-widget () {
	local +h PS4=$_autocomplete__ps4 
	setopt localoptions banghist
	if [[ $1 != <1-> ]]
	then
		compstate[list]= 
		return
	fi
	.autocomplete:async:sufficient-input || return 2
	compstate[insert]= 
	compstate[old_list]= 
	compstate[pattern_insert]= 
	.autocomplete:async:list-choices:main-complete
	unset MENUSELECT MENUMODE
	compstate[insert]= 
	_lastcomp[insert]= 
	compstate[pattern_insert]= 
	_lastcomp[pattern_insert]= 
	if [[ -v _autocomplete__partial_list ]]
	then
		builtin compadd -J -last- -x '%F{0}%K{12}(MORE)%f%k'
		_lastcomp[list_lines]=$compstate[list_lines] 
	fi
	return 2
}
.autocomplete:async:list-choices:main-complete () {
	local -i _autocomplete__max_lines
	case $curcontext in
		(*history-*) setopt $_autocomplete__func_opts[@]
			autocomplete:_main_complete:new - history-lines _autocomplete__history_lines ;;
		(recent-paths:*) setopt $_autocomplete__func_opts[@]
			autocomplete:_main_complete:new - recent-paths _autocomplete__recent_paths ;;
		(*) {
				() {
					emulate -L zsh
					setopt $_autocomplete__func_opts[@]
					local curcontext=list-choices::: 
					.autocomplete:async:shadow compadd
					autoload -Uz +X _describe
					.autocomplete:async:shadow _describe
				} "$@"
				.autocomplete:async:list-choices:max-lines
				autocomplete:_main_complete:new "$@"
			} always {
				unfunction compadd comptags 2> /dev/null
				.autocomplete:async:unshadow compadd
				.autocomplete:async:unshadow _describe
			} ;;
	esac
}
.autocomplete:async:list-choices:max-lines () {
	local -Pi max_lines
	builtin zstyle -s ":autocomplete:${curcontext}:" list-lines max_lines || max_lines=16 
	_autocomplete__max_lines=$(( min( max_lines, LINES - BUFFERLINES - 1 ) )) 
}
.autocomplete:async:pty () {
	local +h PS4=$_autocomplete__ps4 
	local -F seconds= 
	builtin zstyle -s ":autocomplete:${curcontext}" timeout seconds || seconds=0.5 
	TMOUT=$(( [#10] 1 + seconds )) 
	eval ${${${"$( zstyle -L '*' format )"}//zstyle /zstyle -d }// -e / }
	builtin bindkey $'\C-@' .autocomplete:async:pty:zle-widget
	local __tmp__= 
	builtin vared __tmp__
} 2>>| $_autocomplete__log
.autocomplete:async:pty:completion-widget () {
	local +h PS4=$_autocomplete__ps4 
	setopt localoptions banghist
	{
		if ! .autocomplete:async:sufficient-input
		then
			return
		fi
		{
			unfunction compadd 2> /dev/null
			unset 'compstate[vared]'
			.autocomplete:async:list-choices:main-complete
		} always {
			_autocomplete__list_lines=$compstate[list_lines] 
		}
	} 2>>| $_autocomplete__log
}
.autocomplete:async:pty:no-op () {
	:
}
.autocomplete:async:pty:zle-widget () {
	local +h PS4=$_autocomplete__ps4 
	setopt localoptions NO_banghist
	local -a _autocomplete__comp_mesg=() 
	local -i _autocomplete__list_lines=0 
	local _autocomplete__mesg= 
	{
		print -n -- '\C-A'
		LBUFFER=$_autocomplete__lbuffer 
		RBUFFER=$_autocomplete__rbuffer 
		[[ -n $curcontext ]] && setopt $_autocomplete__ctxt_opts[@]
		local +h PS4=$_autocomplete__ps4 
		builtin zle .autocomplete:async:pty:completion-widget -w 2>>| $_autocomplete__log
	} always {
		print -rNC1 -- ${_autocomplete__list_lines:-0}$'\C-B'
		builtin exit
	}
} 2>>| $_autocomplete__log
.autocomplete:async:reset-context () {
	.autocomplete:async:reset-state
	typeset -g curcontext= 
	builtin zstyle -s :autocomplete: default-context curcontext
	.autocomplete:async:complete
	return 0
}
.autocomplete:async:reset-state () {
	unset _autocomplete__curcontext _autocomplete__lbuffer _autocomplete__rbuffer
}
.autocomplete:async:same-state () {
	[[ -v _autocomplete__curcontext && $_autocomplete__curcontext == $curcontext && -v _autocomplete__lbuffer && $_autocomplete__lbuffer == $LBUFFER && -v _autocomplete__rbuffer && $_autocomplete__rbuffer == $RBUFFER ]]
}
.autocomplete:async:save-state () {
	typeset -g _autocomplete__curcontext=$curcontext _autocomplete__lbuffer="$LBUFFER" _autocomplete__rbuffer="$RBUFFER" 
}
.autocomplete:async:shadow () {
	[[ -v functions[$1] ]] && functions[autocomplete:async:${1}:old]="$functions[$1]" 
	functions[$1]="$functions[.autocomplete:async:$1]" 
}
.autocomplete:async:start () {
	local fd= 
	sysopen -r -o cloexec -u fd <(
    local +h PS4=$_autocomplete__ps4
    .autocomplete:async:start:inner 2>>| $_autocomplete__log
  )
	builtin zle -Fw "$fd" .autocomplete:async:complete:fd-widget
	command true
}
.autocomplete:async:start:inner () {
	{
		typeset -F SECONDS=0 
		local -P hooks=(chpwd periodic precmd preexec zshaddhistory zshexit) 
		builtin unset ${^hooks}_functions &> /dev/null
		$hooks[@] () {
			:
		}
		local -P hook= 
		for hook in zle-{isearch-{exit,update},line-{pre-redraw,init,finish},history-line-set,keymap-select}
		do
			builtin zle -N $hook .autocomplete:async:pty:no-op
		done
		{
			local REPLY= 
			zpty AUTOCOMPLETE .autocomplete:async:pty
			local -Pi fd=$REPLY 
			zpty -w AUTOCOMPLETE $'\C-@'
			local header= 
			zpty -r AUTOCOMPLETE header $'*\C-A'
			local -a reply=() 
			local text= 
			local -F seconds=0.0 
			builtin zstyle -s ":autocomplete:${curcontext}" timeout seconds || (( seconds = 1.0 ))
			(( seconds = max( 0, seconds - SECONDS ) ))
			local -i timeout=$(( 100 * seconds )) 
			if zselect -rt $timeout "$fd"
			then
				zpty -r AUTOCOMPLETE text $'*\C-B'
			else
				zpty -wn AUTOCOMPLETE $'\C-C\C-C\C-D'
			fi
		} always {
			zpty -d AUTOCOMPLETE
		}
	} always {
		print -rNC1 -- "${text%$'\C-B'}"
	}
}
.autocomplete:async:sufficient-input () {
	local min_input= 
	if ! builtin zstyle -s ":autocomplete:${curcontext}:" min-input min_input
	then
		if [[ -n $curcontext ]]
		then
			min_input=0 
		else
			min_input=1 
		fi
	fi
	local ignored= 
	builtin zstyle -s ":autocomplete:${curcontext}:" ignored-input ignored
	if (( ${#words[@]} == 1 && ${#words[CURRENT]} < min_input )) || [[ -n $ignored && $words[CURRENT] == $~ignored ]]
	then
		compstate[list]= 
		false
	else
		true
	fi
}
.autocomplete:async:toggle-context () {
	if [[ $curcontext == $WIDGET* ]]
	then
		unset curcontext
	else
		typeset -g curcontext=${WIDGET}::: 
	fi
	zle .autocomplete:async:complete -w
}
.autocomplete:async:unshadow () {
	if [[ -v functions[autocomplete:async:${1}:old] ]]
	then
		functions[$1]="$functions[autocomplete:async:${1}:old]" 
		unfunction autocomplete:async:${1}:old
	fi
}
.autocomplete:async:wait () {
	local fd= 
	sysopen -r -o cloexec -u fd <(
    local -F seconds=
    builtin zstyle -s :autocomplete: delay seconds ||
        builtin zstyle -s :autocomplete: min-delay seconds ||
        (( seconds = 0.05 ))

    (( seconds_delay = max( 0, seconds_delay - _autocomplete__overhead ) ))

    # Convert to 100ths of a second for `zselect -t`.
    # WORKAROUND: #441 Directly using $(( [#10] … max( … ) )) leads to 0 in Zsh 5.9, as the result
    # of max() gets converted to an integer _before_ being multiplied.
    local -i timeout=$(( 100 * seconds ))

    zselect -t $timeout

    print
  )
	builtin zle -Fw "$fd" .autocomplete:async:wait:fd-widget
	return 0
}
.autocomplete:async:wait:fd-widget () {
	{
		local -i fd=$1 
		builtin zle -F $fd
		exec {fd}<&-
		if [[ -n $_autocomplete__zle_flags ]]
		then
			builtin zle -f $_autocomplete__zle_flags
			[[ $_autocomplete__zle_flags == yank* ]] && return 0
		fi
		(( KEYS_QUEUED_COUNT || PENDING )) && return
		{
			.autocomplete:async:same-state && .autocomplete:async:start
		}
	}
	return 0
}
.autocomplete__async:precmd () {
	[[ -v ZSH_AUTOSUGGEST_IGNORE_WIDGETS ]] && ZSH_AUTOSUGGEST_IGNORE_WIDGETS+=(history-incremental-search-backward recent-paths .autocomplete:async:complete:fd-widget) 
	builtin zle -N .autocomplete:async:pty:zle-widget
	builtin zle -C .autocomplete:async:pty:completion-widget list-choices .autocomplete:async:pty:completion-widget
	builtin zle -N .autocomplete:async:complete:fd-widget
	builtin zle -N .autocomplete:async:wait:fd-widget
	builtin zle -C ._list_choices list-choices .autocomplete:async:list-choices:completion-widget
	builtin zle -N history-incremental-search-backward .autocomplete:async:toggle-context
	builtin zle -N recent-paths .autocomplete:async:toggle-context
	add-zle-hook-widget line-init .autocomplete:async:reset-context
	add-zle-hook-widget line-pre-redraw .autocomplete:async:complete
	add-zle-hook-widget line-finish .autocomplete:async:clear
	add-zle-hook-widget isearch-update .autocomplete:async:isearch-update
	add-zle-hook-widget isearch-exit .autocomplete:async:isearch-exit
}
.autocomplete__compinit:precmd () {
	emulate -L zsh
	setopt $_autocomplete__func_opts[@]
	[[ -v CDPATH && -z $CDPATH ]] && unset CDPATH cdpath
	local -Pa omzdump=() 
	[[ -v ZSH_COMPDUMP && -r $ZSH_COMPDUMP ]] && omzdump=(${(f)"$( < $ZSH_COMPDUMP )"}) 
	typeset -g _comp_dumpfile=${_comp_dumpfile:-${ZSH_COMPDUMP:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compdump}} 
	if [[ -v _comps[-command-] && $_comps[-command-] != _autocomplete__command ]]
	then
		zf_rm -f $_comp_dumpfile
	else
		local -Pa newest=(~autocomplete/Completions/_*~*.zwc(N-.omY1)) 
		if [[ $newest[1] -nt $_comp_dumpfile ]]
		then
			zf_rm -f $_comp_dumpfile
		fi
	fi
	if [[ ! -v _comp_setup ]] || [[ ! -r $_comp_dumpfile ]]
	then
		unfunction compdef compinit 2> /dev/null
		bindkey () {
			:
		}
		{
			builtin autoload +X -Uz compinit
			local -a compargs=() 
			zstyle -a ':autocomplete::compinit' arguments compargs
			compinit -d "$_comp_dumpfile" "$compargs[@]"
		} always {
			unfunction bindkey
		}
		bindkey '^Xh' _complete_help
		(( ${#omzdump[@]} > 0 )) && tee -a "$ZSH_COMPDUMP" &> /dev/null <<EOF
$omzdump[-2]
$omzdump[-1]
EOF
	fi
	compinit () {
		:
	}
	local -P args= 
	for args in "$_autocomplete__compdef[@]"
	do
		eval "compdef $args"
	done
	unset _autocomplete__compdef
	(
		local -a reply=() 
		local cache_dir= 
		if builtin zstyle -s ':completion:*' cache-path cache_dir
		then
			local -P src= bin= 
			for src in $cache_dir/*~**.zwc~**/.*(N-.)
			do
				bin=$src.zwc 
				if [[ ! -e $bin || $bin -ot $src ]]
				then
					zcompile -Uz $src
				fi
			done
		fi
	) &|
	.autocomplete__patch _main_complete
	autocomplete:_main_complete:new () {
		local -i _autocomplete__reserved_lines=0 
		local -Pi ret=1 
		unset _autocomplete__partial_list _autocomplete__unambiguous
		compstate[insert]=automenu-unambiguous 
		compstate[last_prompt]=yes 
		compstate[list]='list force packed rows' 
		unset 'compstate[vared]'
		local +h -a compprefuncs=(autocomplete:_main_complete:new:pre "$compprefuncs[@]") 
		local +h -a comppostfuncs=(autocomplete:_main_complete:new:post "$comppostfuncs[@]") 
		autocomplete:_main_complete:old "$@"
	}
	autocomplete:_main_complete:new:pre () {
		unsetopt localtraps
		trap -
		TRAPINT () {
			zle -M "${(F)funcfiletrace}"
			zle -R
			return 130
		}
		TRAPQUIT () {
			zle -M "${(F)funcfiletrace}"
			zle -R
			return 131
		}
	}
	autocomplete:_main_complete:new:post () {
		[[ $WIDGET != _complete_help ]] && unfunction compadd 2> /dev/null
		_autocomplete__unambiguous
		compstate[list_max]=0 
		MENUSCROLL=0 
	}
	.autocomplete__patch _complete
	_complete () {
		local -i nmatches=$compstate[nmatches] 
		PREFIX=$PREFIX$SUFFIX 
		SUFFIX= 
		autocomplete:_complete:old "$@"
		(( compstate[nmatches] > nmatches ))
	}
	.autocomplete__patch _approximate
	_approximate () {
		{
			[[ -v functions[compadd] ]] && functions[autocomplete:compadd:old]="$functions[compadd]" 
			functions[compadd]="$functions[autocomplete:approximate:compadd]" 
			autocomplete:_approximate:old
		} always {
			unfunction compadd 2> /dev/null
			if [[ -v functions[autocomplete:compadd:old] ]]
			then
				functions[compadd]="$functions[autocomplete:compadd:old]" 
				unfunction autocomplete:compadd:old
			fi
		}
	}
	autocomplete:approximate:compadd () {
		local ppre="$argv[(I)-p]" 
		[[ ${argv[(I)-[a-zA-Z]#U[a-zA-Z]#]} -eq 0 && "${#:-$PREFIX$SUFFIX}" -le _comp_correct ]] && return
		if [[ "$PREFIX" = \~* && ( ppre -eq 0 || "$argv[ppre+1]" != \~* ) ]]
		then
			PREFIX="~(#a${_comp_correct})${PREFIX[2,-1]}" 
		else
			PREFIX="(#a${_comp_correct})$PREFIX" 
		fi
		if [[ -v functions[autocomplete:compadd:old] ]]
		then
			autocomplete:compadd:old "$@"
		else
			builtin compadd "$@"
		fi
	}
}
.autocomplete__complete-word__completion-widget () {
	setopt localoptions banghist
	zmodload -F zsh/terminfo p:terminfo
	local context=${curcontext:-${WIDGET}:::} 
	unset curcontext
	local +h curcontext=$context 
	local +h -a comppostfuncs=(.autocomplete__complete-word__post "$comppostfuncs[@]") 
	if [[ -z $compstate[old_list] && $curcontext == history-incremental-search* ]]
	then
		autocomplete:_main_complete:new - history-lines _autocomplete__history_lines
	elif [[ -z $compstate[old_list] && $curcontext == recent-paths:* ]]
	then
		autocomplete:_main_complete:new - recent-paths _autocomplete__recent_paths
	elif [[ -z $compstate[old_list] ]] || [[ -v _autocomplete__partial_list && $WIDGETSTYLE == (|*-)(list|menu)(|-*) ]] || _autocomplete__should_insert_unambiguous
	then
		compstate[old_list]= 
		autocomplete:_main_complete:new
	else
		compstate[old_list]=keep 
		autocomplete:_main_complete:new -
	fi
	[[ $_lastcomp[nmatches] -gt 0 && -n $compstate[insert] ]]
}
.autocomplete__complete-word__post () {
	local -a match=() mbegin=() mend=() 
	unset MENUMODE MENUSELECT
	if [[ $WIDGETSTYLE != (|*-)menu(|-*) ]]
	then
		compstate[list]= 
		zle -Rc
	fi
	if [[ $_completer == _prefix ]]
	then
		compstate[to_end]= 
	else
		compstate[to_end]='always' 
	fi
	{
		compstate[insert]= 
		if _autocomplete__should_insert_unambiguous
		then
			if [[ $WIDGETSTYLE == (|*-)menu(|-*) ]]
			then
				compstate[insert]='automenu-' 
			fi
			compstate[insert]+='unambiguous' 
			unset _autocomplete__unambiguous
			return
		fi
		if [[ $WIDGETSTYLE == (|*-)menu(|-*) ]]
		then
			if [[ $WIDGETSTYLE == (|*-)select(|-*) ]]
			then
				typeset -gi MENUSELECT=0 
				if [[ $WIDGET == (|*-)search(|-*) ]]
				then
					typeset -g MENUMODE=search-forward 
				fi
			fi
			compstate[insert]='menu:' 
		fi
		if [[ $WIDGET == (|.)reverse-* || $WIDGETSTYLE == (|.)reverse-menu-complete ]]
		then
			compstate[insert]+='0' 
		else
			compstate[insert]+='1' 
		fi
		local -Pa comptags=() 
		if [[ $compstate[old_list] == keep ]]
		then
			comptags=($=_lastcomp[tags]) 
		else
			comptags=($=_comp_tags) 
		fi
		local -a spacetags=() 
		builtin zstyle -a ":autocomplete:$WIDGET:" add-space spacetags || spacetags=(executables aliases functions builtins reserved-words commands) 
		[[ -n ${comptags:*spacetags} ]] && compstate[insert]+=' ' 
	} always {
		unset _autocomplete__inserted
		[[ -n $compstate[insert] ]] && typeset -g _autocomplete__inserted
	}
}
.autocomplete__config:precmd () {
	typeset -g _comp_setup="$_comp_setup"';
      [[ $_comp_caller_options[globdots] == yes ]] && setopt globdots' 
	local -P key= setting= 
	for key in menu list-prompt
	do
		for setting in ${(f)"$( zstyle -L '*' $key )"}
		do
			eval "${setting/zstyle(| -e)/zstyle -d}"
		done
	done
	builtin zstyle ':completion:*:*:*:*:default' menu no no-select
	unset LISTPROMPT
}
.autocomplete__down-line-or-select__zle-widget () {
	if [[ $RBUFFER == *$'\n'* ]]
	then
		builtin zle down-line
	else
		builtin zle menu-select -w
	fi
}
.autocomplete__history-search__completion-widget () {
	local 0=${(%):-%N} 
	${0} () {
		typeset -g curcontext=${WIDGET}::: 
		local +h -a comppostfuncs=(${(%):-%N}:post "$comppostfuncs[@]") 
		compstate[old_list]= 
		autocomplete:_main_complete:new - history-lines _autocomplete__history_lines
		unset curcontext
		(( _lastcomp[nmatches] ))
	}
	${0}:post () {
		typeset -gi MENUSELECT=0 
		compstate[insert]='menu:0' 
		if (( compstate[nmatches] < 2 ))
		then
			compstate[list]= 
		fi
	}
	${0} "$@"
}
.autocomplete__main () {
	zmodload -Fa zsh/files b:zf_mkdir b:zf_rm
	zmodload -F zsh/parameter p:functions
	zmodload -F zsh/system p:sysparams
	zmodload -F zsh/zleparameter p:widgets
	zmodload -Fa zsh/zutil b:zstyle
	builtin autoload +X -Uz add-zsh-hook zmathfunc
	zmathfunc
	typeset -ga _autocomplete__ctxt_opts=(completealiases completeinword) 
	typeset -ga _autocomplete__mods=(compinit config widgets key-bindings recent-dirs async) 
	typeset -gU FPATH fpath=(~autocomplete/Completions $fpath[@]) 
	local -P xdg_data_home=${XDG_DATA_HOME:-$HOME/.local/share} 
	local -P zsh_data_dir=$xdg_data_home/zsh 
	[[ -d $zsh_data_dir ]] || zf_mkdir -pm 0700 $zsh_data_dir
	local -P old_logdir=$xdg_data_home/zsh-autocomplete/log 
	[[ -d $old_logdir ]] && zf_rm -fr -- $old_logdir
	local -P logdir=${XDG_STATE_HOME:-$HOME/.local/state}/zsh-autocomplete/log 
	local -P bug= 
	for bug in ${logdir} ${logdir:h}
	do
		[[ -d $bug ]] || zf_rm -f $bug
	done
	zf_mkdir -p -- $logdir
	hash -d autocomplete-log=$logdir
	local -Pa older_than_a_week=($logdir/*(Nmd+7)) 
	(( $#older_than_a_week[@] )) && zf_rm -f -- $older_than_a_week[@]
	typeset -g _autocomplete__log=${logdir}/${(%):-%D{%F}}.log 
	typeset -g _autocomplete__ps4=$'%D{%T.%.} %e:%N:%I\t%? %(1_,%_ ,)' 
	local -P zsh_cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/zsh 
	[[ -d $zsh_cache_dir ]] || zf_mkdir -pm 0700 $zsh_cache_dir
	local -P mod= 
	for mod in $_autocomplete__mods
	do
		builtin zstyle -T ":autocomplete:$mod" enabled && .autocomplete__$mod "$@"
		unfunction .autocomplete__$mod
	done
	add-zsh-hook precmd ${0}:precmd
	typeset -gaU precmd_functions=(${0}:precmd $precmd_functions) 
	${0}:precmd () {
		0=${(%):-%N} 
		add-zsh-hook -d precmd $0
		unfunction $0
		() {
			emulate -L zsh
			setopt $_autocomplete__func_opts[@]
			if builtin zstyle -L zle-hook types > /dev/null
			then
				local -P hook= 
				for hook in zle-{isearch-{exit,update},line-{pre-redraw,init,finish},history-line-set,keymap-select}
				do
					[[ -v widgets[$hook] && $widgets[$hook] == user:_zsh_highlight_widget_orig-s*-r<->-$hook ]] && builtin zle -N $hook azhw:$hook
				done
			fi
		}
		local -P mod= 
		for mod in $_autocomplete__mods
		do
			mod=.autocomplete__${mod}:precmd 
			if [[ -v functions[$mod] ]]
			then
				$mod
				unfunction $mod
			fi
		done
		true
	}
}
.autocomplete__main:precmd () {
	0=${(%):-%N} 
	add-zsh-hook -d precmd $0
	unfunction $0
	() {
		emulate -L zsh
		setopt $_autocomplete__func_opts[@]
		if builtin zstyle -L zle-hook types > /dev/null
		then
			local -P hook= 
			for hook in zle-{isearch-{exit,update},line-{pre-redraw,init,finish},history-line-set,keymap-select}
			do
				[[ -v widgets[$hook] && $widgets[$hook] == user:_zsh_highlight_widget_orig-s*-r<->-$hook ]] && builtin zle -N $hook azhw:$hook
			done
		fi
	}
	local -P mod= 
	for mod in $_autocomplete__mods
	do
		mod=.autocomplete__${mod}:precmd 
		if [[ -v functions[$mod] ]]
		then
			$mod
			unfunction $mod
		fi
	done
	true
}
.autocomplete__patch () {
	zmodload -F zsh/parameter p:functions
	functions[autocomplete:${1}:old]="$(
    unfunction $1 2> /dev/null
    builtin autoload +X -Uz $1
    print -r -- "$functions[$1]"
)" 
}
.autocomplete__recent-dirs:precmd () {
	[[ -v functions[+autocomplete:recent-directories] ]] && return
	setopt autopushd pushdignoredups
	builtin autoload -RUz chpwd_recent_filehandler
	local __='' 
	builtin zstyle -s :chpwd: recent-dirs-file __ || builtin zstyle ':chpwd:*' recent-dirs-file ${XDG_DATA_HOME:-$HOME/.local/share}/zsh/chpwd-recent-dirs
	builtin zstyle -s :chpwd: recent-dirs-max __ || builtin zstyle ':chpwd:*' recent-dirs-max 0
	if ! (( $#dirstack[@] ))
	then
		local -aU reply=() 
		chpwd_recent_filehandler
		dirstack=(${^reply[@]:#$PWD}(N-/)) 
	fi
	+autocomplete:recent-directories:save () {
		chpwd_recent_filehandler $PWD $dirstack[@]
	}
	add-zsh-hook chpwd +autocomplete:recent-directories:save
	+autocomplete:recent-directories () {
		typeset -ga reply
		reply=(${^dirstack[@]:#([/~]|$PWD(|/[^/]#))}(N)) 
		[[ -n $1 ]] && reply=(${(M)reply:#(#l)*${(~j:*:)${(s::)1}}*}) 
		(( $#reply[@] ))
	}
}
.autocomplete__up-line-or-search__zle-widget () {
	if [[ $LBUFFER == *$'\n'* ]]
	then
		builtin zle up-line
	else
		builtin zle history-search-backward -w
	fi
}
.autocomplete__widgets:c () {
	_autocomplete__suggest_ignore_widgets+=($1) 
	builtin zle -C "$1" "$2" .autocomplete__${3}__completion-widget
}
.autocomplete__widgets:precmd () {
	emulate -L zsh
	setopt $_autocomplete__func_opts[@]
	0=${0%:*} 
	local -P tab_style= 
	for tab_style in complete-word menu-complete menu-select
	do
		${0}:c "$tab_style" "$tab_style" complete-word
	done
	${0}:c {,}reverse-menu-complete complete-word
	${0}:c insert-unambiguous-or-complete {,}complete-word
	${0}:c menu-search menu-select complete-word
	${0}:c history-search-backward menu-select history-search
	[[ -v ZSH_AUTOSUGGEST_IGNORE_WIDGETS ]] && ZSH_AUTOSUGGEST_IGNORE_WIDGETS+=($_autocomplete__suggest_ignore_widgets) 
	unset _autocomplete__suggest_ignore_widgets
	unfunction ${0}:{c,z}
}
.autocomplete__widgets:z () {
	builtin zle -N "$1" .autocomplete__${2}__zle-widget
}
.autocomplete__zle-flags () {
	emulate -L zsh
	setopt $_autocomplete__func_opts[@]
	typeset -g _autocomplete__last_cutbuffer
	typeset -g _autocomplete__zle_flags= 
	{
		if (( YANK_ACTIVE ))
		then
			_autocomplete__zle_flags=yank 
			(( YANK_END <= CURSOR )) && _autocomplete__zle_flags+=before 
			return 1
		fi
		[[ $_autocomplete__last_cutbuffer != $CUTBUFFER ]] && _autocomplete__zle_flags=kill 
		return 0
	} always {
		[[ -n $_autocomplete__zle_flags ]] && builtin zle -f $_autocomplete__zle_flags
		typeset -g _autocomplete__last_cutbuffer=$CUTBUFFER 
	}
	return 0
}
add-zle-hook-widget () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
add-zsh-hook () {
	emulate -L zsh
	local -a hooktypes
	hooktypes=(chpwd precmd preexec periodic zshaddhistory zshexit zsh_directory_name) 
	local usage="Usage: add-zsh-hook hook function\nValid hooks are:\n  $hooktypes" 
	local opt
	local -a autoopts
	integer del list help
	while getopts "dDhLUzk" opt
	do
		case $opt in
			(d) del=1  ;;
			(D) del=2  ;;
			(h) help=1  ;;
			(L) list=1  ;;
			([Uzk]) autoopts+=(-$opt)  ;;
			(*) return 1 ;;
		esac
	done
	shift $(( OPTIND - 1 ))
	if (( list ))
	then
		typeset -mp "(${1:-${(@j:|:)hooktypes}})_functions"
		return $?
	elif (( help || $# != 2 || ${hooktypes[(I)$1]} == 0 ))
	then
		print -u$(( 2 - help )) $usage
		return $(( 1 - help ))
	fi
	local hook="${1}_functions" 
	local fn="$2" 
	if (( del ))
	then
		if (( ${(P)+hook} ))
		then
			if (( del == 2 ))
			then
				set -A $hook ${(P)hook:#${~fn}}
			else
				set -A $hook ${(P)hook:#$fn}
			fi
			if (( ! ${(P)#hook} ))
			then
				unset $hook
			fi
		fi
	else
		if (( ${(P)+hook} ))
		then
			if (( ${${(P)hook}[(I)$fn]} == 0 ))
			then
				typeset -ga $hook
				set -A $hook ${(P)hook} $fn
			fi
		else
			typeset -ga $hook
			set -A $hook $fn
		fi
		autoload $autoopts -- $fn
	fi
}
autocomplete:config:cache-path () {
	typeset -ga reply=("${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compcache") 
}
autocomplete:config:file-patterns:command () {
	[[ $PREFIX$SUFFIX != */* ]] && typeset -ga reply=('*(-/):directories:directory ./*(-*^/):executables:"executable file"') 
}
autocomplete:config:format () {
	reply=($'%{\e[0;1;2m%}'$1$'%{\e[0m%}') 
}
autocomplete:config:format:warnings () {
	[[ $CURRENT == 1 && -z $PREFIX$SUFFIX ]] || autocomplete:config:format 'no matching %d completions'
}
autocomplete:config:max-errors () {
	typeset -ga reply=($(( min( 2, ( $#PREFIX + $#SUFFIX ) / 3 ) ))) 
}
autocomplete:config:tag-order:command () {
	if [[ $PREFIX == (|.|*/*) ]]
	then
		typeset -ga reply=('suffix-aliases (|*-)directories executables (|*-)files' -) 
	else
		typeset -ga reply=('aliases suffix-aliases functions reserved-words builtins') 
		if (( path[(I).] ))
		then
			reply[1]+=' (|*-)directories executables (|*-)files commands' 
		else
			reply[1]+=' commands (|*-)directories executables (|*-)files' 
		fi
	fi
}
autocomplete:config:tag-order:git () {
	reply=() 
	(( compstate[nmatches] )) && reply=('! heads(|-*) *-remote remote-* blob-*' -) 
}
command_not_found_handle () {
	local runcnf=1 
	local retval=127 
	[[ $- == *"i"* ]] || runcnf=0 
	[[ ! -S /run/dbus/system_bus_socket ]] && runcnf=0 
	[[ ! -x '/usr/libexec/packagekitd' ]] && runcnf=0 
	[[ -n ${COMP_CWORD-} ]] && runcnf=0 
	[[ ! -x '/usr/libexec/pk-command-not-found' ]] && runcnf=0 
	if [ $runcnf -eq 1 ]
	then
		'/usr/libexec/pk-command-not-found' "$@"
		retval=$? 
	elif [[ -n "${BASH_VERSION-}" ]]
	then
		printf 'bash: %s%s\n' "${1:+$1: }" "$(gettext PackageKit 'command not found')" >&2
	fi
	return $retval
}
command_not_found_handler () {
	command_not_found_handle "$@"
}
compaudit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
compdef () {
	local opt autol type func delete eval new i ret=0 cmd svc 
	local -a match mbegin mend
	emulate -L zsh
	setopt extendedglob
	if (( ! $# ))
	then
		print -u2 "$0: I need arguments"
		return 1
	fi
	while getopts "anpPkKde" opt
	do
		case "$opt" in
			(a) autol=yes  ;;
			(n) new=yes  ;;
			([pPkK]) if [[ -n "$type" ]]
				then
					print -u2 "$0: type already set to $type"
					return 1
				fi
				if [[ "$opt" = p ]]
				then
					type=pattern 
				elif [[ "$opt" = P ]]
				then
					type=postpattern 
				elif [[ "$opt" = K ]]
				then
					type=widgetkey 
				else
					type=key 
				fi ;;
			(d) delete=yes  ;;
			(e) eval=yes  ;;
		esac
	done
	shift OPTIND-1
	if (( ! $# ))
	then
		print -u2 "$0: I need arguments"
		return 1
	fi
	if [[ -z "$delete" ]]
	then
		if [[ -z "$eval" ]] && [[ "$1" = *\=* ]]
		then
			while (( $# ))
			do
				if [[ "$1" = *\=* ]]
				then
					cmd="${1%%\=*}" 
					svc="${1#*\=}" 
					func="$_comps[${_services[(r)$svc]:-$svc}]" 
					[[ -n ${_services[$svc]} ]] && svc=${_services[$svc]} 
					[[ -z "$func" ]] && func="${${_patcomps[(K)$svc][1]}:-${_postpatcomps[(K)$svc][1]}}" 
					if [[ -n "$func" ]]
					then
						_comps[$cmd]="$func" 
						_services[$cmd]="$svc" 
					else
						print -u2 "$0: unknown command or service: $svc"
						ret=1 
					fi
				else
					print -u2 "$0: invalid argument: $1"
					ret=1 
				fi
				shift
			done
			return ret
		fi
		func="$1" 
		[[ -n "$autol" ]] && autoload -rUz "$func"
		shift
		case "$type" in
			(widgetkey) while [[ -n $1 ]]
				do
					if [[ $# -lt 3 ]]
					then
						print -u2 "$0: compdef -K requires <widget> <comp-widget> <key>"
						return 1
					fi
					[[ $1 = _* ]] || 1="_$1" 
					[[ $2 = .* ]] || 2=".$2" 
					[[ $2 = .menu-select ]] && zmodload -i zsh/complist
					zle -C "$1" "$2" "$func"
					if [[ -n $new ]]
					then
						bindkey "$3" | IFS=$' \t' read -A opt
						[[ $opt[-1] = undefined-key ]] && bindkey "$3" "$1"
					else
						bindkey "$3" "$1"
					fi
					shift 3
				done ;;
			(key) if [[ $# -lt 2 ]]
				then
					print -u2 "$0: missing keys"
					return 1
				fi
				if [[ $1 = .* ]]
				then
					[[ $1 = .menu-select ]] && zmodload -i zsh/complist
					zle -C "$func" "$1" "$func"
				else
					[[ $1 = menu-select ]] && zmodload -i zsh/complist
					zle -C "$func" ".$1" "$func"
				fi
				shift
				for i
				do
					if [[ -n $new ]]
					then
						bindkey "$i" | IFS=$' \t' read -A opt
						[[ $opt[-1] = undefined-key ]] || continue
					fi
					bindkey "$i" "$func"
				done ;;
			(*) while (( $# ))
				do
					if [[ "$1" = -N ]]
					then
						type=normal 
					elif [[ "$1" = -p ]]
					then
						type=pattern 
					elif [[ "$1" = -P ]]
					then
						type=postpattern 
					else
						case "$type" in
							(pattern) if [[ $1 = (#b)(*)=(*) ]]
								then
									_patcomps[$match[1]]="=$match[2]=$func" 
								else
									_patcomps[$1]="$func" 
								fi ;;
							(postpattern) if [[ $1 = (#b)(*)=(*) ]]
								then
									_postpatcomps[$match[1]]="=$match[2]=$func" 
								else
									_postpatcomps[$1]="$func" 
								fi ;;
							(*) if [[ "$1" = *\=* ]]
								then
									cmd="${1%%\=*}" 
									svc=yes 
								else
									cmd="$1" 
									svc= 
								fi
								if [[ -z "$new" || -z "${_comps[$1]}" ]]
								then
									_comps[$cmd]="$func" 
									[[ -n "$svc" ]] && _services[$cmd]="${1#*\=}" 
								fi ;;
						esac
					fi
					shift
				done ;;
		esac
	else
		case "$type" in
			(pattern) unset "_patcomps[$^@]" ;;
			(postpattern) unset "_postpatcomps[$^@]" ;;
			(key) print -u2 "$0: cannot restore key bindings"
				return 1 ;;
			(*) unset "_comps[$^@]" ;;
		esac
	fi
}
compdump () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
compgen () {
	unfunction _bash_complete compgen complete
	builtin autoload +X -Uz bashcompinit
	bashcompinit
	bashcompinit () {
		:
	}
	${(%):-%N} "$@"
}
compinit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
compinstall () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/5.9/functions
}
complete () {
	unfunction _bash_complete compgen complete
	builtin autoload +X -Uz bashcompinit
	bashcompinit
	bashcompinit () {
		:
	}
	${(%):-%N} "$@"
}
extract () {
	if [[ -f "$1" ]]
	then
		case "$1" in
			(*.tar.bz2) tar xjf "$1" ;;
			(*.tar.gz) tar xzf "$1" ;;
			(*.tar.xz) tar xJf "$1" ;;
			(*.bz2) bunzip2 "$1" ;;
			(*.rar) unrar x "$1" ;;
			(*.gz) gunzip "$1" ;;
			(*.tar) tar xf "$1" ;;
			(*.tbz2) tar xjf "$1" ;;
			(*.tgz) tar xzf "$1" ;;
			(*.zip) unzip "$1" ;;
			(*.Z) uncompress "$1" ;;
			(*.7z) 7z x "$1" ;;
			(*) echo "'$1' cannot be extracted via extract()" ;;
		esac
	else
		echo "'$1' is not a valid file"
	fi
}
gawklibpath_append () {
	[ -z "$AWKLIBPATH" ] && AWKLIBPATH=`gawk 'BEGIN {print ENVIRON["AWKLIBPATH"]}'` 
	export AWKLIBPATH="$AWKLIBPATH:$*" 
}
gawklibpath_default () {
	unset AWKLIBPATH
	export AWKLIBPATH=`gawk 'BEGIN {print ENVIRON["AWKLIBPATH"]}'` 
}
gawklibpath_prepend () {
	[ -z "$AWKLIBPATH" ] && AWKLIBPATH=`gawk 'BEGIN {print ENVIRON["AWKLIBPATH"]}'` 
	export AWKLIBPATH="$*:$AWKLIBPATH" 
}
gawkpath_append () {
	[ -z "$AWKPATH" ] && AWKPATH=`gawk 'BEGIN {print ENVIRON["AWKPATH"]}'` 
	export AWKPATH="$AWKPATH:$*" 
}
gawkpath_default () {
	unset AWKPATH
	export AWKPATH=`gawk 'BEGIN {print ENVIRON["AWKPATH"]}'` 
}
gawkpath_prepend () {
	[ -z "$AWKPATH" ] && AWKPATH=`gawk 'BEGIN {print ENVIRON["AWKPATH"]}'` 
	export AWKPATH="$*:$AWKPATH" 
}
is-at-least () {
	emulate -L zsh
	local IFS=".-" min_cnt=0 ver_cnt=0 part min_ver version order 
	min_ver=(${=1}) 
	version=(${=2:-$ZSH_VERSION} 0) 
	while (( $min_cnt <= ${#min_ver} ))
	do
		while [[ "$part" != <-> ]]
		do
			(( ++ver_cnt > ${#version} )) && return 0
			if [[ ${version[ver_cnt]} = *[0-9][^0-9]* ]]
			then
				order=(${version[ver_cnt]} ${min_ver[ver_cnt]}) 
				if [[ ${version[ver_cnt]} = <->* ]]
				then
					[[ $order != ${${(On)order}} ]] && return 1
				else
					[[ $order != ${${(O)order}} ]] && return 1
				fi
				[[ $order[1] != $order[2] ]] && return 0
			fi
			part=${version[ver_cnt]##*[^0-9]} 
		done
		while true
		do
			(( ++min_cnt > ${#min_ver} )) && return 0
			[[ ${min_ver[min_cnt]} = <-> ]] && break
		done
		(( part > min_ver[min_cnt] )) && return 0
		(( part < min_ver[min_cnt] )) && return 1
		part='' 
	done
}
mkcd () {
	mkdir -p "$1" && cd "$1"
}
prompt_starship_precmd () {
	STARSHIP_CMD_STATUS=$? STARSHIP_PIPE_STATUS=(${pipestatus[@]}) 
	if (( ${+STARSHIP_START_TIME} ))
	then
		__starship_get_time && STARSHIP_DURATION=$(( STARSHIP_CAPTURED_TIME - STARSHIP_START_TIME )) 
		unset STARSHIP_START_TIME
	else
		unset STARSHIP_DURATION STARSHIP_CMD_STATUS STARSHIP_PIPE_STATUS
	fi
	STARSHIP_JOBS_COUNT=${#jobstates} 
}
prompt_starship_preexec () {
	__starship_get_time && STARSHIP_START_TIME=$STARSHIP_CAPTURED_TIME 
}
qf () {
	find . -name "*$1*" 2> /dev/null
}
starship_zle-keymap-select () {
	zle reset-prompt
}
y () {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd 
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")"  && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]
	then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}
z () {
	__zoxide_z "$@"
}
zi () {
	__zoxide_zi "$@"
}
zmathfunc () {
	zsh_math_func_min () {
		emulate -L zsh
		local result=$1 
		shift
		local arg
		for arg
		do
			(( arg < result ))
			case $? in
				(0) (( result = arg )) ;;
				(1)  ;;
				(*) return $? ;;
			esac
		done
		(( result ))
		true
	}
	functions -M min 1 -1 zsh_math_func_min
	zsh_math_func_max () {
		emulate -L zsh
		local result=$1 
		shift
		local arg
		for arg
		do
			(( arg > result ))
			case $? in
				(0) (( result = arg )) ;;
				(1)  ;;
				(*) return $? ;;
			esac
		done
		(( result ))
		true
	}
	functions -M max 1 -1 zsh_math_func_max
	zsh_math_func_sum () {
		emulate -L zsh
		local sum
		local arg
		for arg
		do
			(( sum += arg ))
		done
		(( sum ))
		true
	}
	functions -M sum 0 -1 zsh_math_func_sum
}
zsh_math_func_max () {
	emulate -L zsh
	local result=$1 
	shift
	local arg
	for arg
	do
		(( arg > result ))
		case $? in
			(0) (( result = arg )) ;;
			(1)  ;;
			(*) return $? ;;
		esac
	done
	(( result ))
	true
}
zsh_math_func_min () {
	emulate -L zsh
	local result=$1 
	shift
	local arg
	for arg
	do
		(( arg < result ))
		case $? in
			(0) (( result = arg )) ;;
			(1)  ;;
			(*) return $? ;;
		esac
	done
	(( result ))
	true
}
zsh_math_func_sum () {
	emulate -L zsh
	local sum
	local arg
	for arg
	do
		(( sum += arg ))
	done
	(( sum ))
	true
}
# Shell Options
setopt autocd
setopt autopushd
setopt nobeep
setopt correct
setopt extendedglob
setopt nohashdirs
setopt histignoredups
setopt histignorespace
setopt histreduceblanks
setopt nolistbeep
setopt login
setopt promptsubst
setopt pushdignoredups
setopt sharehistory
# Aliases
alias -- ..='cd ..'
alias -- ...='cd ../..'
alias -- ....='cd ../../..'
alias -- cat='bat --paging=never'
alias -- catp=bat
alias -- cls=clear
alias -- cp='cp -i'
alias -- df='df -h'
alias -- du='du -h'
alias -- egrep='grep -E --color=auto'
alias -- fgrep='grep -F --color=auto'
alias -- free='free -h'
alias -- g=git
alias -- ga='git add'
alias -- gb='git branch'
alias -- gc='git commit'
alias -- gco='git checkout'
alias -- gd='git diff'
alias -- gl='git pull'
alias -- glog='git log --oneline --graph --decorate'
alias -- gp='git push'
alias -- grep='grep --color=auto'
alias -- gs='git status'
alias -- h=history
alias -- l='ls -l'
alias -- la='ls -a'
alias -- lg=lazygit
alias -- ll='ls -la'
alias -- mv='mv -i'
alias -- rm='rm -i'
alias -- run-help=man
alias -- which='alias | /usr/bin/which --tty-only --read-alias --show-tilde --show-dot'
alias -- which-command=whence
alias -- xzegrep='xzegrep --color=auto'
alias -- xzfgrep='xzfgrep --color=auto'
alias -- xzgrep='xzgrep --color=auto'
alias -- zegrep='zegrep --color=auto'
alias -- zfgrep='zfgrep --color=auto'
alias -- zgrep='zgrep --color=auto'
# Check for rg availability
if ! (unalias rg 2>/dev/null; command -v rg) >/dev/null 2>&1; then
  alias rg='/home/haint/.local/share/claude/versions/2.1.39 --ripgrep'
fi
export PATH=/home/haint/.local/bin\:/home/haint/bin\:/usr/local/bin\:/usr/bin\:/usr/local/sbin\:/usr/sbin\:/home/haint/.dotnet\:/home/haint/.dotnet/tools
