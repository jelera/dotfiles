#! /bin/bash
##-----------------------------------------------------------------------------
##
##         Name : install_atom_packages.sh
##       Author : Jose Elera <jelera@gmail.com>
## Last Updated : Thu 21 Jan 2016 02:45:09 PM CST
##
## Copyright © 2016 Jose Elera
## Distributed under terms of the MIT license.
##
##-----------------------------------------------------------------------------
#############################################################################//
#
# => HELPER FUNCTIONS
#
#############################################################################//

function color_echo(){
# Usage  : color_echo "string" color
# Credit : http://stackoverflow.com/a/23006365/428786
	local exp=$1;
	local color=$2;
	if ! [[ $color =~ ^[0-9]$ ]] ; then
		case $(echo "$color" | tr '[:upper:]' '[:lower:]') in
			black) color=0 ;;
			red) color=1 ;;
			green) color=2 ;;
			yellow) color=3 ;;
			blue) color=4 ;;
			magenta) color=5 ;;
			cyan) color=6 ;;
			white|*) color=7 ;; # white or invalid color
		esac
	fi

	tput setaf $color;
	printf "\n%s\n" "$exp"
	tput sgr0;
}

#-----------------------------------//
# => Check if apm/atom is installed
#-----------------------------------//
if ! [[ -x apm ]]; then
	color_echo "------------------------------------------------------" red
	color_echo "|  You must install atom before running this script  |" red
	color_echo "------------------------------------------------------" red
	exit 1
fi


#-----------------------------//
# => Install Plugins
#-----------------------------//
color_echo "project-manager, for easy access and switching between projects in Atom" cyan
  apm install project-manager

color_echo "Editor Stats, Display a graph a keyboard and mouse usage for the last 6 hours" cyan
  apm install editor-stats

color_echo "wordpress-api, Completion, snippets, and etc" cyan
  apm install wordpress-api

color_echo "aligner, Easily align multiple lines and blocks" cyan
  apm install aligner

color_echo "vim-mode-plus, Vim-mode improved" cyan
  apm install vim-mode-plus

color_echo "emmet, The essential tool for web developers" cyan
  apm install vim-mode-plus

color_echo "javascript-snippets, JS and NodeJS snippets for Atom" cyan
  apm install javascript-snippets

color_echo "csscomb, Plugin for CSSComb" cyan
  apm install csscomb

color_echo "color-picker, A Color picker for Atom" cyan
  apm install color-picker

color_echo "autoprefixer, Prefix CSS for vendors" cyan
  apm install autoprefixer

color_echo "editorconfig, Setup a global setting for editors" cyan
  apm install editorconfig

color_echo "auto-detect-indentation, of opened files" cyan
  apm install auto-detect-indentation

color_echo "git-plus, DO git things without the terminal" cyan
  apm install git-plus

color_echo "merge-conflicts, Resolve git conflicts within Atom" cyan
  apm install merge-conflicts

color_echo "file-icons, Assign file extension icons and colours for improved visual grepping" cyan
  apm install file-icons

color_echo "remote-edit, Browse and edit remote files using SFTP and FTP" cyan
  apm install remote-edit

color_echo "atom-beautify, Beautify HTML, CSS, JS, etc in Atom" cyan
  apm install atom-beautify

color_echo "todo-show, Finds all the TODOs, FIXMEs, CHANGEDs, etc in your project" cyan
  apm install todo-show

color_echo "autoclose-html, Automates closing of HTML tags" cyan
  apm install autoclose-html

color_echo "Pigments, A package to display color in project and files" cyan
  apm install pigments

color_echo "Linter, a base linter provider for Atom, and Linters" cyan
  apm install linter
  # BASH
  apm install linter-shellcheck
  # HTML
  apm install linter-bootlint
  apm install linter-htmlhint
  # CSS
  apm install linter-csslint
  # CoffeeScript
  apm install linter-coffeelint
  # JSON
  apm install linter-jsonlint
  # JavaScript
  apm install linter-jshint
  # Markdown
  apm install linter-markdownlint
  # PHP
  apm install linter-php
  # Puppet
  # apm install linter-puppet-lint
  # Python
  apm install linter-flake8
  # Ruby
  apm install linter-ruby
  # SASS
  apm install linter-scss-lint
  # YAML
  apm install linter-js-yaml
  # XML
  apm install linter-xmllint

  # Writing Assistant
  apm install linter-write-good

