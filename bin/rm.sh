TRASH="$HOME/.Trash"
COMMAND=${0##*/}
CURRENTDIR=$(pwd)

invalid_option(){
	echo "rm: illegal option -- ${1:1:1}"
	usage
}

usage(){
	echo "usage: rm [-f | -i | -I] [-dPRrvW] file ..."
	echo "       unlink file"

	exit 64
}

split_push_arg(){
	split=`echo ${1:1} | fold -w1`

	local arg
	for arg in ${split[@]}; do
		ARG[arg_i]="-$arg"
		((arg_i += 1))
	done
}

push_arg(){
	ARG[arg_i]=$1
	((arg_i += 1))
}

push_file(){
	FILE_NAME[file_i]=$1
	((file_i += 1))
}

remove(){
	local file=$1

	# if is a directory
	if [[ -d $file ]]; then
		if [[ ! -n $OPT_RECURSIVE ]]; then
			echo "$COMMAND: $file: is a directory"
			return 1
		fi

		if [[ $file = './' ]]; then
			echo "$COMMAND: $file: Invalid argument"
			return 1
		fi

	fi
	trash "$file"
}

trash(){
	local file=$1
	local move=$file
	local base=$(basename "$file")
	local travel=

	if [[ -d "$file" && ${base:0:1} = '.' ]]; then
		cd $file
		move=$(pwd)
		move=$(basename "$move")
		cd ..
		travel=1
	fi

	local trash_name=$TRASH/$base
	local guid=0
	local new_trash_name=$trash_name

	while [[ -e "$new_trash_name" ]]; do
		new_trash_name="$trash_name"\_"$guid"
		(( guid += 1 ))
		
	done

	mv "$move" "$new_trash_name"

	[[ "$travel" = 1 ]] && cd $CURENTDIR &> /dev/null

	return 0
}

if [[ "$#" = 0 ]]; then
	echo "safe-rm"
	usage
fi

ARG_END=
FILE_NAME=
ARG=

file_i=0
arg_i=0

#process arguments

while [[ -n $1 ]]; do
	if [[ -n $ARG_END ]]; then
		push_file "$1"
	else
		case $1 in

		-[a-zA-Z]*)
			split_push_arg $1
			;;

		--[a-zA-Z]*)
			push_arg $1
			;;
		--)
			ARG_END=1
			;;

		*)
			push_file "$1"
			ARG_END=1
			;;
		esac
	fi
	shift
done

OPT_FORCE=
OPT_RECURSIVE=
EXIT_CODE=0

# extract flags

for arg in ${ARG[@]}; do
	case $arg in

	-f|--force)
		OPT_FORCE=1
		;;
	-[rR]|--[rR]ecursive)
		OPT_RECURSIVE=1
		;;
	*)
		invalid_option $arg
		;;
	esac
done

# if not force, check again

if [[ ! -n $OPT_FORCE ]]; then
	echo -n "$COMMAND: remove all arguments?"
	read answer

	if [[ ! ${answer:0:1} =~ [yY] ]]; then
		exit $EXIT_CODE
	fi
fi

# remove files

for file in "${FILE_NAME[@]}"; do
	if [[ $file = "/" ]]; then
		echo "fuck you..."
		EXIT_CODE=1
		exit $EXIT_CODE
	fi

	if [[ $file = "." || $file = ".." ]]; then
		echo "$COMMAND: \".\" and \"..\" may not be removed"
		EXIT_CODE=1
		continue
	fi

	if [[ $(basename $file) = "." || $(basename $file) = ".." ]]; then
		echo "$COMMAND: \".\" and \"..\" may not be removed"
		EXIT_CODE=1
		continue
	fi

	ls_result=$(ls -d "$file" 2> /dev/null)

	if [[ -n "$ls_result" ]]; then
		for file in "$ls_result"; do
			remove "$file"
			status=$?

			if [[ ! $status == 0 ]]; then
				EXIT_CODE=1
			fi
		done
	else
		echo "$COMMAND: $file: No such file or directory"
		EXIT_CODE=1
	fi
done

exit $EXIT_CODE
