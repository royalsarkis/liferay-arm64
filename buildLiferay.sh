#!/bin/bash

DIR="/tmp/building_env"

function print_menu()  # selected_item, ...menu_items
{
	local function_arguments=($@)

	local selected_item="$1"
	local menu_items=(${function_arguments[@]:1})
	local menu_size="${#menu_items[@]}"

	for (( i = 0; i < $menu_size; ++i ))
	do
		if [ "$i" = "$selected_item" ]
		then
			echo "-> ${menu_items[i]}"
		else
			echo "   ${menu_items[i]}"
		fi
	done
}

function run_menu()  # selected_item, ...menu_items
{
	local function_arguments=($@)

	local selected_item="$1"
	local menu_items=(${function_arguments[@]:1})
	local menu_size="${#menu_items[@]}"
	local menu_limit=$((menu_size - 1))

	print_menu "$selected_item" "${menu_items[@]}"
	
	while read -rsn1 input
	do
		case "$input"
		in
			$'\x1B')  # ESC ASCII code (https://dirask.com/posts/ASCII-Table-pJ3Y0j)
				read -rsn1 -t 0.1 input
				if [ "$input" = "[" ]  # occurs before arrow code
				then
					read -rsn1 -t 0.1 input
					case "$input"
					in
						A)  # Up Arrow
							if [ "$selected_item" -ge 1 ]
							then
								selected_item=$((selected_item - 1))
								clear
								echo "[ Info ] Choissisez votre version de liferay"
								echo "[ Info ] Utilisez les touches haut/bas et confirmez avec entrer:"
								print_menu "$selected_item" "${menu_items[@]}"
							fi
							;;
						B)  # Down Arrow
							if [ "$selected_item" -lt "$menu_limit" ]
							then
								selected_item=$((selected_item + 1))
								clear
								echo "[ Info ] Choissisez votre version de liferay"
								echo "[ Info ] Utilisez les touches haut/bas et confirmez avec entrer:"
								print_menu "$selected_item" "${menu_items[@]}"
							fi
							;;
					esac
				fi
				read -rsn5 -t 0.1  # flushing stdin
				;;
			"")  # Enter key
				return "$selected_item"
				;;
		esac
	done
}

function liferay_version {
	echo "[ Info ] Choissisez votre version de liferay"
	echo "[ Info ] Utilisez les touches haut/bas et confirmez avec entrer:"

	IFS=$'\n' read -r -d '' -a my_array < <( curl -s -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/liferay/liferay-portal/releases  \
	| jq -r '.[].tag_name'  && printf '\0' ) 
	declare -p my_array &>/dev/null
	
	selected_item=0
	menu_items=${my_array[@]}

	run_menu "$selected_item" "${menu_items[@]}"
	menu_result="$?"

	LIFERAY_VERSION=${my_array[$menu_result]}
	WORKSPACE_VERSION="${LIFERAY_VERSION:0:3}"

	if [[ $LIFERAY_VERSION == *"7.1.0"* && $LIFERAY_VERSION != *"7.1.0-ga1"* ]];
	then LIFERAY_VERSION_2=$(echo ${LIFERAY_VERSION} | sed -e "s/7.1.0/7.1/g")
	echo "liferay version 2 "$LIFERAY_VERSION_2
		LIFERAY_TIMESTAMP=$(curl -s -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/liferay/liferay-portal/releases \
		| jq -r '.[].assets[].name' | grep portal-${LIFERAY_VERSION_2} | sed -e 's/\(^.*-\)\(.*\)\(.*$\)/\2/' \
		| awk -F. '{print $1}')
	else
		LIFERAY_TIMESTAMP=$(curl -s -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/liferay/liferay-portal/releases \
		| jq -r '.[].assets[].name' | grep portal-${LIFERAY_VERSION} | sed -e 's/\(^.*-\)\(.*\)\(.*$\)/\2/' \
		| awk -F. '{print $1}')
	fi

		URL=$(curl -s -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/liferay/liferay-portal/releases \
		| jq -r '.[].assets[].browser_download_url' | grep liferay-ce-portal-tomcat-${LIFERAY_VERSION} | grep ".tar.gz")

	clear
	echo "[ INFO ] Vous avez choisi Liferay $LIFERAY_VERSION"
	build_liferay
}

function check_image()
{
	IMAGE=$(docker images | awk '{print $1}'| grep liferay-arm64-$LIFERAY_VERSION)
	if [ $? -eq 0 ];
		then
		docker tag liferay-arm64-$LIFERAY_VERSION:latest liferay-arm64:$LIFERAY_VERSION
		docker rmi liferay-arm64-$LIFERAY_VERSION:latest
		echo "Liferay image liferay-arm64:$LIFERAY_VERSION successfully build for arm64 processor"
		else 
		echo "Error build the image"
	fi
}

function build_liferay {
	
	if [[ -d $DIR ]]
	then rm -rf $DIR
		mkdir -p $DIR
	else
		mkdir -p $DIR
	fi
	
	echo "[ INFO ] Downloading liferay bundle $LIFERAY_VERSION"
	curl -# -L $URL -o $DIR/liferay.tar.gz
	tar -xf $DIR/liferay.tar.gz -C $DIR/liferay
	curl -s -o $DIR/liferay/Dockerfile https://raw.githubusercontent.com/royalsarkis/liferay-arm64/master/bundle/Dockerfile
	mv $DIR/liferay/liferay* $DIR/liferay/liferay
	cp -rf $DIR/liferay/liferay/tomcat* $DIR/liferay/liferay/tomcat
	docker build -t liferay-arm64-$LIFERAY_VERSION $DIR/liferay

	check_image

	rm -rf $DIR/liferay
	rm $DIR/liferay.tar.gz
}

liferay_version